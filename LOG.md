# LOG.md

## 2026-06-21

- Fix mappa/calendario disallineati in `ondate-calore.sh`: su "dati invariati" lo script faceva `exit 0` prima di rigenerare `oggi.csv` (fonte mappa Datawrapper). Nel weekend/festivi (Ministero non pubblica) la mappa restava ferma al giorno di emissione, mentre il calendario mostrava già la previsione per oggi presa da `latest`/archivio. Ora il blocco di pubblicazione (correzioni + latest + archivio) è in un `else`; la generazione di `oggi.csv` ed elaborazioni gira sempre, così la mappa usa la previsione per il giorno odierno. Idempotente: a parità di giorno+dati nessun commit spurio.

## 2026-06-10

- Fix `ondate-calore.sh`: retry con backoff su `agent-browser open`/`wait table`. Il sito ministero (CDN Gcore) risponde a volte con 504 Gateway Time-out facendo fallire la GitHub Action; ora fino a 5 tentativi (attesa 15s, 30s, 45s, 60s).

## 2026-05-27

- Riattivazione del servizio dopo stop estate 2025.
- Fix `ondate-calore.sh`: aggiunto `User-Agent` a tutti i `curl` (il sito del ministero restituiva 403 senza).
- Fix `ondate-calore.sh`: aggiornato XPath header tabella da `.td[]` a `.th[]` (il sito ha cambiato i tag).
- Step RSS disabilitato temporaneamente nel workflow GitHub Actions.
- Aggiunta validazione post-estrazione: lo script si interrompe se le città estratte sono meno di 27.
- Step RSS riattivato nel workflow GitHub Actions.

## 2025-07-12

- Creato il file di log.
- La mappa Datawrapper viene aggiornata automaticamente tramite chiamata API via GitHub Action dopo il push dei dati aggiornati.
