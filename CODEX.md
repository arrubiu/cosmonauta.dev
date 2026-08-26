# Cosmonauta Ghost

Questo repository contiene l'infrastruttura Docker Compose del sito
**cosmonauta.dev**, basato su Ghost e MySQL. Non contiene il codice sorgente di
un tema Ghost né un'applicazione frontend.

## Architettura

- `compose.yml` definisce i servizi condivisi:
  - `cosmonauta_dev_ghost`: Ghost, con immagine configurabile tramite
    `GHOST_VERSION`;
  - `cosmonauta_dev_db`: MySQL 8, utilizzato esclusivamente da Ghost.
- Usare sempre `compose.yml` insieme a **una sola** variante:
  - `compose.local.yml` per lo sviluppo locale;
  - `compose.production.yml` per il server di produzione.
- I dati persistenti (contenuti Ghost e dati MySQL) sono bind mount definiti
  dalle variabili d'ambiente. La directory `data/` e i file `.env*` contenenti
  credenziali non vanno mai versionati.

## Ambienti e comandi

### Sviluppo locale

- Copiare `.env.local.example` in `.env.local` e impostare valori sicuri.
- Eseguire le operazioni tramite `./local.sh`, ad esempio `./local.sh up`.
- Ghost è disponibile soltanto su `http://localhost:2368` tramite binding a
  `127.0.0.1`; non aggiungere una route pubblica Caddy all'ambiente locale.
- `./local.sh sync` scarica un export e gli upload dalla produzione e
  **sostituisce tutti i dati locali**. Non modificare questo flusso in modo che
  possa inviare dati locali alla produzione.

### Produzione

- Sul server usare `.env` (derivato da `.env.production.example`) e
  `./ghost.sh`.
- La produzione usa l'istanza Caddy esistente attraverso la rete Docker esterna
  `caddy` e le etichette in `compose.production.yml`.
- L'URL canonico è `https://www.cosmonauta.dev`; `cosmonauta.dev` viene
  reindirizzato al dominio `www`.
- `./ghost.sh backup` crea backup consistenti di database e upload, conserva
  30 giorni di archivi ed esclude soltanto la cache rigenerabile
  `images/size`.

## ActivityPub e servizi esclusi

- ActivityPub non è ospitato in questo stack. In produzione Caddy inoltra solo
  `/.ghost/activitypub/*`, `/.well-known/webfinger` e
  `/.well-known/nodeinfo` a `https://ap.ghost.org`.
- Non aggiungere nuovamente Tinybird, un proxy analytics, un servizio
  ActivityPub self-hosted o un container Caddy incluso nel repository.

## Regole per le modifiche

- Mantenere i nomi dei servizi e delle reti, perché script e proxy esterni ne
  dipendono.
- Non cambiare dopo l'inizializzazione di MySQL: `DATABASE_ROOT_PASSWORD`,
  `DATABASE_USER`, `DATABASE_PASSWORD`, `UPLOAD_LOCATION` e
  `MYSQL_DATA_LOCATION`.
- Prima di modificare Compose o gli script, preservare la separazione netta fra
  locale e produzione e verificare i comandi con `docker compose config` usando
  il relativo file di ambiente, senza mostrare segreti.
- Trattare backup, sincronizzazione e dati di produzione come operazioni
  distruttive: richiedono controlli espliciti prima dell'esecuzione.
