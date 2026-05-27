# LOG.md

## 2026-05-27

- Riattivazione del servizio dopo stop estate 2025.
- Fix `ondate-calore.sh`: aggiunto `User-Agent` a tutti i `curl` (il sito del ministero restituiva 403 senza).
- Fix `ondate-calore.sh`: aggiornato XPath header tabella da `.td[]` a `.th[]` (il sito ha cambiato i tag).
- Step RSS disabilitato temporaneamente nel workflow GitHub Actions.

## 2025-07-12

- Creato il file di log.
- La mappa Datawrapper viene aggiornata automaticamente tramite chiamata API via GitHub Action dopo il push dei dati aggiornati.
