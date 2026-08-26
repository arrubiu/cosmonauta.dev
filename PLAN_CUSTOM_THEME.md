# Piano — tema Ghost `cosmonauta`

## Obiettivo

Il tema Ghost personalizzato vive in `./cosmonauta_theme/`, come repository Git indipendente dal repository infrastrutturale. Il repository remoto previsto è il fork pubblico `arrubiu/cosmonauta_theme` di `TryGhost/Source`; il tema esposto a Ghost si chiama `cosmonauta`.

## Stato e configurazione prevista

- Base iniziale: release ufficiale Source `v1.7.2`.
- `origin`: fork Cosmonauta; `upstream`: `TryGhost/Source`.
- Il repository padre ignora `cosmonauta_theme/`.
- `main` è distribuito automaticamente in Ghost; le pull request sono validate ma non ricevono i secret di produzione.
- Il tema viene validato con Node `22.13.0`, pnpm e `pnpm test:ci`.

## Automazione

Il workflow `Validate theme` verifica pull request e push a `main`. Il workflow `Deploy Ghost theme` viene eseguito solo dopo un push a `main`, ripete la validazione e usa `TryGhost/action-deploy-theme@v2` con i secret GitHub `GHOST_ADMIN_API_URL` e `GHOST_ADMIN_API_KEY`.

Il primo deploy richiede l’attivazione manuale di `cosmonauta` in Ghost Admin → Design; gli aggiornamenti successivi modificano il tema già attivo.

## Manutenzione

Seguire le release di `TryGhost/Source` tramite GitHub **Watch → Custom → Releases**. Per ogni aggiornamento, importare il tag su un branch `update/source-<tag>`, risolvere i conflitti preservando il nome `cosmonauta`, eseguire `pnpm test:ci` e aprire una pull request verso `main`.

La procedura completa, inclusi i comandi Git, è disponibile nel [README del tema](cosmonauta_theme/README.md).

## Stato di implementazione

- Fork pubblico creato: `arrubiu/cosmonauta_theme`, collegato a `TryGhost/Source`.
- `main` inizializzato da Source `v1.7.2`, con tema rinominato `cosmonauta`.
- CI GitHub verde su `main`; il ramo richiede pull request e il check `Required checks pass`.
- Il deploy automatico è configurato e ha completato con successo l’upload verso Ghost.

## Azione residua in Ghost

Aprire Ghost Admin → Design e attivare `cosmonauta` una sola volta. I deploy successivi da `main` aggiorneranno il tema già attivo.
