# Cosa è questo repo

Questo repo è stato creato per estrarre e archiviare i dati sui "[Bollettini sulle ondate di calore](https://www.salute.gov.it/portale/caldo/bollettiniCaldo.jsp?lingua=italiano&id=4542&area=emergenzaCaldo&menu=vuoto&btnBollettino=BOLLETTINI)", pubblicati dal Ministero della Salute.

> Per comunicare i possibili effetti sulla salute delle ondate di calore il ministero elabora dei bollettini giornalieri per 27 città con previsioni a 24, 48 e 72 ore.

## I dati sui bollettini

Sono pubblicati in una tabella HTML, in cui una colonna contiene i nomi delle città, e le altre il riferimento alla data e al livello di rischio.

![](immagini/bollettini-ondate-calore.png)

Quattro [livelli di rischio](https://www.salute.gov.it/portale/caldo/dettaglioContenutiCaldo.jsp?lingua=italiano&id=2506&area=emergenzaCaldo&menu=vuoto):

- **Livello 0**, Condizioni meteorologiche che non comportano rischi per la salute della popolazione.
- **Livello 1**, Pre-allerta. Condizioni meteorologiche che possono precedere il verificarsi di un'ondata di calore.
- **Livello 2**, Temperature elevate e condizioni meteorologiche che possono avere effetti negativi sulla salute della popolazione, in particolare nei sottogruppi di popolazione suscettibili.
- **Livello 3**, Ondata di calore. Condizioni ad elevato rischio che persistono per 3 o più giorni consecutivi.

## I dati estratti

I dati sono **estratti ogni mattina alle 6:00** e pubblicati nella cartella [`data`](data).

Due file resi disponibili:

- [`ondate-calore_latest.csv`](data/ondate-calore_latest.csv), con gli ultimi dati estratti;
- [`ondate-calore_archivio.csv`](data/ondate-calore_archivio.csv), con l'archivio dei dati estratti, a partire da giorno 8 luglio 2023.

La struttura dei dati è stata cambiata da `wide` a `long`, e le colonne con le date, sono diventata una sola colonna. Inoltre è stata aggiunta la colonna `data_estrazione` che riporta la data di estrazione.<br>
Sono in formato `CSV`, il separatore dei campo è la `,` e la codifica dei caratteri è `UTF-8`.

Sotto qualche riga di esempio:

| citta | data | livello | data_estrazione |
| --- | --- | --- | --- |
| ANCONA | 2023-07-09 | Livello1 | 2023-07-08 |
| BARI | 2023-07-09 | Livello0 | 2023-07-08 |
| BOLOGNA | 2023-07-09 | Livello1 | 2023-07-08 |
| BOLZANO | 2023-07-09 | Livello2 | 2023-07-08 |
| BRESCIA | 2023-07-09 | Livello1 | 2023-07-08 |
| CAGLIARI | 2023-07-09 | Livello1 | 2023-07-08 |
| CAMPOBASSO | 2023-07-09 | Livello1 | 2023-07-08 |
| CATANIA | 2023-07-09 | Livello1 | 2023-07-08 |
| CIVITAVECCHIA | 2023-07-09 | Livello1 | 2023-07-08 |
| FIRENZE | 2023-07-09 | Livello2 | 2023-07-08 |

Questa la descrizione dei campi:

| campo | descrizione | tipo |
|---|---|---|
| `citta` | il nome della città | testo |
| `data` | la data riportata nel bollettino | data in formato anno, mese giorno, AAAA-MM-GG |
| `livello` | il livello di rischio per quella città in quel giorno | testo |
| `data_estrazione` | la data in cui i dati sono stati estratti | data in formato anno, mese giorno, AAAA-MM-GG |

Il file [`citta-anagrafica.csv`](data/citta-anagrafica.csv) contiene le coordinate di ogni città, e il codice Istat comunale nel campo `admin3code` (la fonte dati è [geonames](https://www.geonames.org/export/)).
