#!/bin/bash

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p $folder/processing
mkdir -p $folder/data

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

    # trasforma struttura dati da wide a long
    mlr --csv label citta then reshape -r "[0-9]" -o data,livello then sort -r data  -f citta then put '$data_estrazione="'"$data"'"' $folder/processing/ondate-calore.csv >$folder/data/ondate-calore_latest.csv

    # se il file di archivio non esiste, crea un file vuoto
    if [ ! -f $folder/data/ondate-calore_archivio.csv ]; then
        touch $folder/data/ondate-calore_archivio.csv
    fi

    # unisci gli ultimi dati con il file di archivio
    mlr --csv uniq -a then sort -r data  -f citta $folder/data/ondate-calore_latest.csv $folder/data/ondate-calore_archivio.csv >$folder/processing/tmp.csv
    mv $folder/processing/tmp.csv $folder/data/ondate-calore_archivio.csv
fi

mlr --c2n cut -f data then uniq -a "$folder"/data/ondate-calore_latest.csv | while read -r line; do
    if [[ $line == *"$data"* ]]; then
        mlr --csv join --ul -j citta -f "$folder"/data/ondate-calore_latest.csv then unsparsify then filter '$data=="'"$data"'"' "$folder"/data/citta-anagrafica.csv >"$folder"/data/ondate-calore_oggi.csv
        mlr --csv join --ul -j livello -f "$folder"/data/ondate-calore_oggi.csv then unsparsify "$folder"/risorse/livelli.csv >"$folder"/processing/tmp.csv
        mv "$folder"/processing/tmp.csv "$folder"/data/ondate-calore_oggi.csv
    else
        echo "non contiene la stringa $data"
    fi
done

