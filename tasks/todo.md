# Fix: mappa e calendario disallineati

## Problema

La mappa (Datawrapper `elo50`, da `data/ondate-calore_oggi.csv`) e il calendario
(Observable, da archivio/latest) mostrano cose diverse per lo stesso giorno.

## Causa (root cause)

`ondate-calore.sh` genera `oggi.csv` solo dopo il controllo "dati invariati":
se il bollettino non cambia (weekend, festivi, più run nello stesso giorno) lo
script fa `exit 0` **prima** di rigenerare `oggi.csv`. Ma "oggi" cambia ogni
giorno: la previsione per oggi è già in `latest.csv`/archivio (e il calendario
la mostra), mentre `oggi.csv` resta congelato al giorno di emissione del
bollettino → la mappa resta indietro fino a 2-3 giorni nel weekend.

## Intervento

Non uscire su "dati invariati": saltare solo la **pubblicazione** di
latest/archivio (che davvero non cambiano) e proseguire comunque a rigenerare i
file giornalieri (`oggi.csv` + elaborazioni), che dipendono dalla data odierna.

- [x] Avvolgere il blocco di pubblicazione (correzioni + mv latest + aggiorna
      archivio) in un `else` del check `dati_invariati`, rimuovendo `exit 0`.
- [x] Lasciare la generazione di `oggi.csv` ed elaborazioni a valle, fuori dall'if,
      così gira sempre.
- [x] Verificare idempotenza: mlr deterministico → a parità di giorno+dati output
      identico → nessun commit spurio.

## Review

- `bash -n ondate-calore.sh` → OK, if/else bilanciato.
- Test scenario weekend: forzando `data=2026-06-12` (giorno di previsione, non il
  06-10 di emissione) su `latest` esistente, `oggi.csv` si rigenera con
  `data=2026-06-12`, `data_estrazione=2026-06-10`, 27 città. ✅
- Modifica solo di control-flow (un `exit 0` → ramo `else`); la logica di
  generazione di `oggi.csv` è invariata.
- LOG.md aggiornato (2026-06-21).

## Note / questioni aperte

- Edge case preesistente non affrontato: lunedì prima delle 11 il `latest` è
  ancora di venerdì e non copre lunedì → `oggi.csv` non si aggiorna fino al nuovo
  bollettino. Comportamento invariato rispetto a prima.
- Il refresh Datawrapper nel workflow è già sempre eseguito: con `oggi.csv`
  aggiornato e committato, la mappa si allinea.
