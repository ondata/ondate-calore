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

mkdir -p "$folder"/processing
mkdir -p "$folder"/data
mkdir -p "$folder"/elaborazioni

data=$(date +%Y-%m-%d)

# url pagina
url="https://www.salute.gov.it/portale/caldo/bollettiniCaldo.jsp?lingua=italiano&id=4542&area=emergenzaCaldo&menu=vuoto&btnBollettino=BOLLETTINI"

# scarica la pagina, se non hai risposta 200 esci dallo script
response=$(curl --write-out %{http_code} --silent --output /dev/null $url)

if [ $response != 200 ]; then
    echo "La pagina non ha risposto con un codice HTTP 200. Lo script verrà interrotto."
    exit 1
else
    curl $url -o $folder/processing/output.html
fi

# estrai data aggiornamento dichiarata sul sito
<$folder/processing/output.html  scrape -e '//p[contains(text(), "Ultima versione aggiornata: ")]/b/text()' | sed -e 's/[[:space:]]//g' >$folder/processing/check

# if file $folder/processing/check is equal to $folder/data/check, then exit
if cmp -s $folder/processing/check $folder/data/check; then
    echo "La data di aggiornamento non è cambiata. Lo script verrà interrotto."
else
    mv $folder/processing/check $folder/data/check
    # estrai header, e converti data in formato ISO
    <$folder/processing/output.html scrape -be '//table/thead' | xq -r '.html.body.thead.tr.th[]."#text"' | paste -sd, | sed -E 's#([0-9]{2})/([0-9]{2})/([0-9]{4})#\3-\2-\1#g' >$folder/processing/ondate-calore.csv

    # estrai dati
    <$folder/processing/output.html scrape -be '//tr[@class="grigio-05-bg"]' | xq -c '.html.body.tr[]|{name:.td[0].span.a."@name",prima:.td[1].img."@alt",seconda:.td[2].img."@alt",terza:.td[3].img."@alt"}'  | mlr --j2c cat | tail -n +2 >>$folder/processing/ondate-calore.csv

    <$folder/processing/output.html scrape -be '//tr[@class="grigio-05-bg"]' | xq -c '.html.body.tr[]|{name:.td[0].span.a."@name",URL:.td[0].a."@href"}'  | mlr --j2c label citta,URL then put '$URL=sub($URL,"http:","https:")' >$folder/data/ondate-calore_PDF.csv

    # trasforma struttura dati da wide a long
    mlr --csv label citta then reshape -r "[0-9]" -o data,livello then sort -r data  -f citta then put '$data_estrazione="'"$data"'"' $folder/processing/ondate-calore.csv >$folder/data/ondate-calore_latest.csv

    # aggiungi URL PDF
    mlr --csv join --ul -j citta -f $folder/data/ondate-calore_latest.csv then unsparsify $folder/data/ondate-calore_PDF.csv >$folder/processing/tmp.csv

    mv $folder/processing/tmp.csv $folder/data/ondate-calore_latest.csv

    # se il file di archivio non esiste, crea un file vuoto
    if [ ! -f $folder/data/ondate-calore_archivio.csv ]; then
        touch $folder/data/ondate-calore_archivio.csv
    fi

    # unisci gli ultimi dati con il file di archivio
    mlr --csv cut -x -f URL then uniq -a then sort -r data -f citta $folder/data/ondate-calore_latest.csv $folder/data/ondate-calore_archivio.csv >$folder/processing/tmp.csv
    mv $folder/processing/tmp.csv $folder/data/ondate-calore_archivio.csv

fi

# estrai un CSV, con i dati di oggi, se presenti
mlr --c2n cut -f data then uniq -a "$folder"/data/ondate-calore_latest.csv | while read -r line; do
    if [[ $line == *"$data"* ]]; then
        mlr --csv join --ul -j citta -f "$folder"/data/ondate-calore_latest.csv then unsparsify then filter '$data=="'"$data"'"' "$folder"/data/citta-anagrafica.csv >"$folder"/data/ondate-calore_oggi.csv
        mlr --csv join --ul -j livello -f "$folder"/data/ondate-calore_oggi.csv then unsparsify then sort -f citta "$folder"/risorse/livelli.csv >"$folder"/processing/tmp.csv
        mv "$folder"/processing/tmp.csv "$folder"/data/ondate-calore_oggi.csv
    else
        echo "non contiene la data $data"
    fi
done

# Se risultano associati più valori in un giorno, per la stessa città, prendi il più recente
# Estrai un CSV, che per ogni riga stampa il delta rispetto a ieri e a domani
mlrgo --csv sort -f citta -r data then top -n 1 -a -g citta,data -f data_estrazione then sort -f citta,data then put '$livello_n=int(regextract($livello,"[0-9]+"))' then step -a delta -f livello_n -g citta then rename livello_n_delta,delta_giorno_prima then step -a shift_lead -f delta_giorno_prima -g citta then rename -r '.+_lead',delta_giorno_dopo then sort -f citta,data "$folder"/data/ondate-calore_archivio.csv >"$folder"/elaborazioni/ondate-calore_archivio_clean.csv

# aggiungi ai dati di oggi i delta rispetto a ieri e a domani

mlr --csv cut -f citta,data,delta_giorno_prima,delta_giorno_dopo "$folder"/elaborazioni/ondate-calore_archivio_clean.csv >"$folder"/processing/tmp.csv

mlr --csv join --ul -j citta,data -f "$folder"/data/ondate-calore_oggi.csv then unsparsify then sort -f citta,data then put '
if($delta_giorno_dopo>0) {
    $tooltip_domani="👀 <b>Domani</b> si starà peggio ⬆️"
} elif ($delta_giorno_dopo<0) {
    $tooltip_domani="👀 <b>Domani</b> si starà meglio ⬇️"
} else {
    $tooltip_domani="👀 <b>Domani</b> sarà come oggi"
};if(is_null($delta_giorno_dopo)){$tooltip_domani=""}else{$tooltip_domani=$tooltip_domani}' "$folder"/processing/tmp.csv >"$folder"/elaborazioni/ondate-calore_oggi.csv

rm "$folder"/processing/tmp.csv

