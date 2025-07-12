# Copilot Instructions for AI Agents

## Architettura e flusso dati

- Il progetto estrae e archivia i bollettini sulle ondate di calore pubblicati dal Ministero della Salute.
- I dati vengono estratti tramite lo script `ondate-calore.sh` e salvati in formato CSV nella cartella `data/`.
- I file principali sono:
  - `data/ondate-calore_latest.csv`: ultimi dati estratti
  - `data/ondate-calore_archivio.csv`: archivio storico
  - `data/citta-anagrafica.csv`: anagrafica città con coordinate e codice ISTAT
- La struttura dei dati è "long" (non "wide"). Ogni riga rappresenta una città, una data, un livello di rischio e la data di estrazione.

## Workflow automatici

- L'aggiornamento dei dati avviene tramite GitHub Actions (`.github/workflows/ondate-calore.yml`).
- La action esegue:
  1. Estrazione dati (`ondate-calore.sh`)
  2. Generazione feed RSS (`script/rss.sh`)
  3. Commit e push automatico dei dati
  4. Aggiornamento della mappa Datawrapper via API (curl POST)
- La mappa Datawrapper (`elo50`) viene aggiornata automaticamente dopo ogni push dei dati.

## Convenzioni e pattern

- Tutti gli script sono in bash e si trovano nella root o in `script/`.
- I dati sono sempre in formato CSV, separatore `,`, encoding UTF-8.
- I workflow sono schedulati con cron per coprire le esigenze di aggiornamento periodico (vedi commenti nel file workflow).
- I secrets per le API (es. Datawrapper) sono gestiti tramite GitHub secrets di organization.

## Esempi e riferimenti

- Per estrarre i dati: eseguire manualmente `./ondate-calore.sh`.
- Per aggiornare la mappa Datawrapper: vedere lo step curl in `.github/workflows/ondate-calore.yml`.
- Per la struttura dei dati: vedere esempio tabella in `README.md`.

## File chiave

- `ondate-calore.sh`: script principale di estrazione
- `script/rss.sh`: generazione feed RSS
- `data/`: output dati
- `.github/workflows/ondate-calore.yml`: workflow automation
- `README.md`: documentazione generale e struttura dati

## Note di output markdown

Si prega di rispettare la formattazione Markdown più standard per garantire la compatibilità e la leggibilità.

In particolare:

- Dopo ogni titolo (es. `# Titolo`, `## Sottotitolo`), inserire sempre una riga vuota.
- Dopo il carattere di un elenco numerato (es. `1.`, `2.`), inserire un solo spazio.
- Dopo il carattere di un elenco puntato (es. `-`, `*`), inserire un solo spazio.
- Dopo i due punti (`:`) che precedono un elenco puntato o numerato, inserire sempre una riga vuota.

---

Se servono dettagli su convenzioni, flussi o automazioni non chiari, chiedi all'utente di specificare!
