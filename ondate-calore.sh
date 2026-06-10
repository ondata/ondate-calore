#!/bin/bash

### requisiti ###
# Miller, https://miller.readthedocs.io/
# scrape cli, https://github.com/aborruso/scrape-cli
# yq, https://github.com/kislyuk/yq
### requisiti ###

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "${folder}"/processing
mkdir -p "${folder}"/data
mkdir -p "${folder}"/elaborazioni

data=$(date +%Y-%m-%d)

# url pagina
url="https://www.salute.gov.it/new/it/tema/ondate-di-calore/bollettini-sulle-ondate-di-calore-0/"

# scarica la pagina con browser headless (bypassa protezione JS del ministero)
# wait 'table' gestisce il redirect Gcore CDN: la tabella esiste solo sulla pagina reale
# retry: il sito risponde a volte con 504 Gateway Time-out (CDN Gcore); riprova con backoff
max_tentativi=5
tentativo=1
while true; do
  if agent-browser open "$url" \
    && agent-browser wait --load networkidle \
    && agent-browser wait 'table'; then
    break
  fi
  agent-browser close || true
  if [ "$tentativo" -ge "$max_tentativi" ]; then
    echo "ERRORE: pagina non disponibile (es. 504) dopo ${max_tentativi} tentativi" >&2
    exit 1
  fi
  attesa=$((tentativo * 15))
  echo "tentativo ${tentativo}/${max_tentativi} fallito, ritento tra ${attesa}s" >&2
  sleep "$attesa"
  tentativo=$((tentativo + 1))
done
echo 'document.documentElement.outerHTML' | agent-browser eval --stdin | jq -r . > "${folder}/processing/output.html"
agent-browser close

# estrai data aggiornamento dichiarata sul sito (informativa, usata nel log correzioni)
<"${folder}"/processing/output.html scrape -be "//*[contains(text(), 'Ultima Versione Aggiornata')]" | grep -oP '\d{2}/\d{2}/\d{4}' >"${folder}"/processing/check
data_versione=$(<"${folder}"/processing/check)

# estrai header
<"${folder}"/processing/output.html scrape -be '//table/thead' | xq -r '.html.body.thead.tr.th[]."#text"' | paste -sd, >"${folder}"/processing/ondate-calore.csv

# estrai dati
<"${folder}"/processing/output.html scrape -be '//table/tbody/tr' | \
xq -c '.html.body.tr[] |
{
    name: (
    if (.td[0].a."#text" != null) then .td[0].a."#text"
    elif (.td[0].span."#text" != null) then .td[0].span."#text"
    else null
    end
    ),
    prima: .td[1].span."@class",
    seconda: .td[2].span."@class",
    terza: .td[3].span."@class"
}' | \
mlr --j2c cat | tail -n +2 >>"${folder}"/processing/ondate-calore.csv

# estrai URL PDF
<"${folder}"/processing/output.html scrape -be '//table/tbody/tr' | \
xq -c '.html.body.tr[] |
{
    name: (
    if (.td[0].a."#text" != null) then .td[0].a."#text"
    elif (.td[0].span."#text" != null) then .td[0].span."#text"
    else null
    end
    ),
    URL: (
    if (.td[0].a."@href" != null) then .td[0].a."@href"
    else ""
    end
    )
}' | \
mlr --j2c label citta,URL then put '$URL=sub($URL,"http:","https:")' >"${folder}"/data/ondate-calore_PDF.csv

# URL completo per i PDF
mlr -I --csv put '$URL="https://www.salute.gov.it".$URL' "${folder}"/data/ondate-calore_PDF.csv

# trasforma struttura dati da wide a long → file temporaneo per il confronto
mlr --csv --from "${folder}"/processing/ondate-calore.csv label citta then reshape -r "[0-9]" -o data,livello then sort -r data -f citta then put '$data_estrazione="'"$data"'"' >"${folder}"/processing/latest_new.csv

# aggiungi URL PDF
mlr --csv join --ul -j citta -f "${folder}"/processing/latest_new.csv then unsparsify "${folder}"/data/ondate-calore_PDF.csv >"${folder}"/processing/tmp.csv
mv "${folder}"/processing/tmp.csv "${folder}"/processing/latest_new.csv

# formattare in formato ISO la data
mlr -I --csv --from "${folder}"/processing/latest_new.csv put '$data=strftime(strptime($data, "%d-%m-%Y"),"%Y-%m-%d")'

# estrai i livelli come da schema
mlr -I --csv put '$livello=sub($livello, "livello-NA", "livello-0");$livello=regextract_or_else($livello, "livello-\d", "");$livello=sub($livello, "livello-", "Livello")' "${folder}"/processing/latest_new.csv

# verifica che il file contenga dati per almeno 27 città distinte
n_citta=$(mlr --c2n cut -f citta then uniq -a "${folder}"/processing/latest_new.csv | wc -l)
if [ "$n_citta" -lt 27 ]; then
    echo "ERRORE: trovate solo $n_citta città (attese 27). Estrazione probabilmente incompleta. Lo script verrà interrotto."
    exit 1
fi

# confronta i nuovi dati (citta+data+livello) con latest.csv esistente: esci se invariati
dati_invariati=false
if [ -f "${folder}"/data/ondate-calore_latest.csv ]; then
    if diff \
        <(mlr --csv sort -f citta,data then cut -f citta,data,livello "${folder}"/processing/latest_new.csv) \
        <(mlr --csv sort -f citta,data then cut -f citta,data,livello "${folder}"/data/ondate-calore_latest.csv) \
        > /dev/null 2>&1; then
        dati_invariati=true
    fi
fi

if [ "$dati_invariati" = true ]; then
    echo "Dati invariati. Lo script verrà interrotto."
    mv "${folder}"/processing/check "${folder}"/data/check
    exit 0
fi

# logga le correzioni: stessa citta+data con livello cambiato rispetto al latest precedente
if [ -f "${folder}"/data/ondate-calore_latest.csv ]; then
    if [ ! -f "${folder}"/data/correzioni.csv ]; then
        echo "data_rilevazione,versione_sito,citta,data,livello_precedente,livello_nuovo" >"${folder}"/data/correzioni.csv
    fi
    mlr --csv join -j citta,data --lp new_ \
        -f "${folder}"/processing/latest_new.csv \
        then filter '$new_livello != $livello' \
        then put '$data_rilevazione="'"$data"'"; $versione_sito="'"$data_versione"'"' \
        then cut -f data_rilevazione,versione_sito,citta,data,livello,new_livello \
        then rename livello,livello_precedente,new_livello,livello_nuovo \
        "${folder}"/data/ondate-calore_latest.csv >>"${folder}"/data/correzioni.csv
fi

# pubblica il nuovo latest e aggiorna il check
mv "${folder}"/processing/latest_new.csv "${folder}"/data/ondate-calore_latest.csv
mv "${folder}"/processing/check "${folder}"/data/check

# se il file di archivio non esiste, crea un file vuoto
if [ ! -f "${folder}"/data/ondate-calore_archivio.csv ]; then
    touch "${folder}"/data/ondate-calore_archivio.csv
fi

# unisci gli ultimi dati con l'archivio: latest.csv è autoritativo per le date che copre
# sort stabile per data_estrazione desc → uniq per citta+data tiene la riga più recente (latest.csv prima)
mlr --csv cut -x -f URL then sort -r data_estrazione -f citta,data then top -n 1 -a -g citta,data -f data_estrazione then sort -r data -f citta "${folder}"/data/ondate-calore_latest.csv "${folder}"/data/ondate-calore_archivio.csv >"${folder}"/processing/tmp.csv
mv "${folder}"/processing/tmp.csv "${folder}"/data/ondate-calore_archivio.csv

# estrai un CSV, con i dati di oggi, se presenti
mlr --c2n cut -f data then uniq -a "${folder}"/data/ondate-calore_latest.csv | while read -r line; do
    if [[ $line == *"$data"* ]]; then
        # crea il file con i dati di oggi, unendo con l'anagrafica delle città
        mlr --csv join --ul -j citta -f "${folder}"/data/ondate-calore_latest.csv then unsparsify then filter '$data=="'"$data"'"' "${folder}"/data/citta-anagrafica.csv >"${folder}"/data/ondate-calore_oggi.csv
        # aggiungi informazioni sui livelli di allerta
        mlr --csv join --ul -j livello -f "${folder}"/data/ondate-calore_oggi.csv then unsparsify then sort -f citta "${folder}"/risorse/livelli.csv >"${folder}"/processing/tmp.csv
        mv "${folder}"/processing/tmp.csv "${folder}"/data/ondate-calore_oggi.csv
    else
        echo "non contiene la data $data"
    fi
done

# Se risultano associati più valori in un giorno, per la stessa città, prendi il più recente
# Calcola i delta tra i livelli di allerta di giorni consecutivi per ogni città
# Estrae il numero dal livello, calcola le differenze tra giorni consecutivi e crea colonne per variazioni
mlr --csv sort -f citta -r data then top -n 1 -a -g citta,data -f data_estrazione then sort -f citta,data then put '$livello_n=int(regextract($livello,"[0-9]+"))' then step -a delta -f livello_n -g citta then rename livello_n_delta,delta_giorno_prima then step -a shift_lead -f delta_giorno_prima -g citta then rename -r '.+_lead',delta_giorno_dopo then sort -f citta,data "${folder}"/data/ondate-calore_archivio.csv >"${folder}"/elaborazioni/ondate-calore_archivio_clean.csv

# aggiungi ai dati di oggi i delta rispetto a ieri e a domani
# estrai solo le colonne dei delta dall'archivio pulito per il join successivo
mlr --csv cut -f citta,data,delta_giorno_prima,delta_giorno_dopo "${folder}"/elaborazioni/ondate-calore_archivio_clean.csv >"${folder}"/processing/tmp.csv

# unisci i dati di oggi con i delta e crea tooltip informativi basati sui cambiamenti di livello
mlr --csv join --ul -j citta,data -f "${folder}"/data/ondate-calore_oggi.csv then unsparsify then sort -f citta,data then put '
if(is_null($delta_giorno_dopo)) {
    $tooltip_domani=""
} elif ($delta_giorno_dopo>0) {
    $tooltip_domani="👀 <b>Domani</b> si starà peggio ⬆️"
} elif ($delta_giorno_dopo<0) {
    $tooltip_domani="👀 <b>Domani</b> si starà meglio ⬇️"
} else {
    $tooltip_domani="👀 <b>Domani</b> sarà come oggi"
}
' "${folder}"/processing/tmp.csv >"${folder}"/elaborazioni/ondate-calore_oggi.csv

# estrai le coordinate geografiche delle città per il join successivo
mlr --csv cut -f citta,latitude "${folder}"/data/citta-anagrafica.csv >"${folder}"/processing/latitude.csv

# aggiungi le coordinate geografiche all'archivio pulito
mlr --csv join --ul -j citta -f "${folder}"/elaborazioni/ondate-calore_archivio_clean.csv then unsparsify then sort -f citta,data "${folder}"/processing/latitude.csv >"${folder}"/processing/tmp.csv

# pulisci file temporaneo delle coordinate
rm "${folder}"/processing/latitude.csv

# rinomina il file
mv "${folder}"/processing/tmp.csv "${folder}"/elaborazioni/ondate-calore_archivio_clean.csv
