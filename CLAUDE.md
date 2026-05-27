# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Cos'è questo progetto

Estrae e archivia i dati dai bollettini sulle ondate di calore pubblicati dal Ministero della Salute (27 città italiane, livelli 0–3). I dati vengono estratti dalla pagina HTML del ministero e pubblicati come CSV, feed RSS e sito Quarto (GitHub Pages).

## Strumenti richiesti

- **Miller (`mlr`)**: trasformazione dati CSV (disponibile in `bin/mlr`)
- **scrape-cli (`scrape`)**: estrazione HTML/XPath (disponibile in `bin/scrape`)
- **yq** (`yq==3.4.3`, fork Python, non il binario Go): parsing XML/JSON da shell
- **xmltodict**: dipendenza Python usata con yq
- **ogr2ogr** (GDAL): generazione feed RSS in GeoRSS
- **Quarto**: build del sito statico

## Comandi principali

```bash
# Estrazione dati (da root del progetto)
./ondate-calore.sh

# Generazione feed RSS (dopo estrazione dati)
cd script && ./rss.sh

# Build sito Quarto
quarto render

# Preview sito locale
quarto preview
```

## Architettura

### Flusso dati (`ondate-calore.sh`)

1. Scarica la pagina HTML del ministero con `curl` (retry 5x)
2. Controlla se la data di aggiornamento è cambiata confrontando `data/check`; esce se invariata
3. Estrae la tabella HTML con `scrape` + `xq` (alias di `yq` per XML/HTML)
4. Trasforma da wide a long con `mlr` → `data/ondate-calore_latest.csv`
5. Aggiunge URL PDF per ogni città → `data/ondate-calore_PDF.csv`
6. Aggiorna l'archivio storico → `data/ondate-calore_archivio.csv`
7. Crea file giornaliero con join anagrafiche → `data/ondate-calore_oggi.csv`
8. Calcola delta livelli giorno-per-giorno → `elaborazioni/ondate-calore_archivio_clean.csv`
9. Arricchisce dati odierni con tooltip e delta → `elaborazioni/ondate-calore_oggi.csv`

### Generazione RSS (`script/rss.sh`)

- Filtra solo bollettini con livello ≠ 0
- Usa `ogr2ogr` con formato GeoRSS per generare un file XML per città (codice ISTAT `admin3code`)
- Output: `rss/*.xml` copiati in `docs/rss/`

### File di dati chiave

| File | Contenuto |
|---|---|
| `data/ondate-calore_latest.csv` | Ultimi dati estratti (long format) |
| `data/ondate-calore_archivio.csv` | Archivio storico dal 2023-07-08 |
| `data/ondate-calore_oggi.csv` | Solo dati del giorno corrente, con anagrafica |
| `data/citta-anagrafica.csv` | Coordinate + codice ISTAT per 27 città |
| `data/livelli.csv` | Descrizioni dei 4 livelli di rischio |
| `elaborazioni/ondate-calore_archivio_clean.csv` | Archivio con delta livelli calcolati |
| `elaborazioni/ondate-calore_oggi.csv` | Dati odierni con tooltip per variazioni |
| `data/check` | Timestamp ultimo aggiornamento ministero (usato per evitare estrazioni duplicate) |

### Schema CSV dati estratti

Campi: `citta`, `data` (YYYY-MM-DD), `livello` (es. `Livello2`), `data_estrazione`, `URL` (PDF bollettino)

### Automazione GitHub Actions

Il workflow `.github/workflows/ondate-calore.yml` gira più volte al giorno (ogni ora tra le 8 e le 15 UTC, più run notturne). Esegue in sequenza: estrazione → RSS → commit/push → aggiornamento mappa Datawrapper (`elo50`) via API.

Il secret `ANDY_DATAWRAPPER_TOKEN_CHART_UPDATE` deve essere configurato a livello di organization GitHub.

### Sito Quarto

`_quarto.yml` configura un sito website con output in `docs/` (servito come GitHub Pages). Le pagine sorgente sono `index.qmd` e `note.qmd`.

## Convenzioni

- `processing/` è la cartella temporanea degli script (file intermedi, non versionati)
- `tmp/` è usata come area di test locale
- `bin/` contiene i binari statici (`mlr`, `mlrgo`, `scrape`) copiati in `~/bin` dalla GitHub Action
- `risorse/` contiene dati di supporto (`livelli.csv`, anagrafica comuni)
