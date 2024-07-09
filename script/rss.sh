#!/bin/bash

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "${folder}"/tmp

# estrai soltanto i bollettini con livello diverso da 0
mlrgo -S --csv filter -x '$livello=~"0"' "${folder}"/../data/ondate-calore_latest.csv > "${folder}"/tmp/tmp.csv

# se non ci sono bollettini con livello diverso da 0, esci
if [ ! -s "${folder}"/tmp/tmp.csv ]; then
    echo "No data"
    exit 0
fi

# estrai dati anagrafici delle città, utili per il join
mlrgo -S --csv --from "${folder}"/../data/citta-anagrafica.csv cut -f citta,admin3code,name > "${folder}"/tmp/citta-anagrafica.csv

# aggiungi ai dati dei bollettini i dati anagrafici estratti
mlrgo -S --csv join --ul -j citta -f "${folder}"/tmp/tmp.csv then unsparsify "${folder}"/tmp/citta-anagrafica.csv > "${folder}"/tmp/rss.csv

# aggiungi ai dati dei bollettini le infi sui livelli di rischio
mlrgo --csv -S join --ul -j livello -f "${folder}"/tmp/rss.csv then unsparsify "${folder}"/../data/livelli.csv > "${folder}"/tmp/tmp.csv

# rinomina il file
mv "${folder}"/tmp/tmp.csv "${folder}"/tmp/rss.csv

# crea campi e/o rinominali in modo che ci siano le colonne utili per il feed RSS
mlrgo -I -S --csv --from "${folder}"/tmp/rss.csv put '$data_title=strftime(strptime($data, "%Y-%m-%d"),"%d/%m/%Y");$link=$URL."?data=".$data;$title=$citta." - ".$data_title.": ".$livello_label;$description=$livello_des;$pubDate=$data." 00:00:00";$category=$livello_label' then sort -r data -f citta then cut -f link,title,description,pubDate,category,admin3code,name

# crea una copia in jsonl
# mlrgo --icsv --ojsonl cat "${folder}"/tmp/rss.csv > "${folder}"/tmp/rss.jsonl

mkdir -p "${folder}"/../docs/rss
mkdir -p "${folder}"/../rss

# per ogni codice città con dei dati, crea un feed RSS
mlrgo --c2n cut -f admin3code then uniq -a "${folder}"/tmp/rss.csv | while read -r admin3code; do
  echo "admin3code: $admin3code"
  citta=$(mlrgo -S --c2n filter '$admin3code=="'"$admin3code"'"' then cut -f name "${folder}"/../data/citta-anagrafica.csv)
  ogr2ogr -f GeoRSS "${folder}"/../rss/"$admin3code".xml "${folder}"/tmp/rss.csv -dsco FORMAT="RSS" -dsco TITLE="$citta: bollettini sulle ondate di calore" -dsco DESCRIPTION="Per gli aggiornamenti su condizioni non buone" -oo AUTODETECT_TYPE=YES -dsco USE_EXTENSIONS=YES -where "admin3code='$admin3code'" -dsco LINK="https://ondata.github.io/ondate-calore/rss/$admin3code.xml"
#  sed -i 's|<rss version="2.0" xmlns:georss="http://www.georss.org/georss">|<rss version="2.0" xmlns:georss="http://www.georss.org/georss" xmlns:ogr="http://www.opengis.net/gml">|' "${folder}"/../rss/"$admin3code".xml
  sed -i '/<ogr:/d' "${folder}"/../rss/"$admin3code".xml
  sed -i '/^$/d' "${folder}"/../rss/"$admin3code".xml
done

#  copy all xml files in "${folder}"/../rss/ to "${folder}"/../docs/rss/
cp "${folder}"/../rss/*.xml "${folder}"/../docs/rss/
