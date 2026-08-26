# Cosmonauta Ghost

Ghost runs with MySQL. The base [compose.yml](compose.yml) is always combined with one override:

- `compose.local.yml`: local Ghost at `http://localhost:2368`, accessible only from the local machine.
- `compose.production.yml`: production Ghost behind the server's existing `caddy-docker-proxy`, using the external `caddy` network.

## Local development

Create the local environment file:

```sh
cp .env.local.example .env.local
```

Set these values in `.env.local`:

```dotenv
GHOST_ENV_FILE=.env.local
DOMAIN=localhost
GHOST_VERSION=6.55.0-alpine
DATABASE_ROOT_PASSWORD=<password-locale-MySQL>
DATABASE_USER=ghost
DATABASE_PASSWORD=<password-locale-Ghost>
UPLOAD_LOCATION=./data/local/ghost
MYSQL_DATA_LOCATION=./data/local/mysql
```

For `./local.sh sync`, also configure SSH access to the production server:

```dotenv
PRODUCTION_SSH=<utente-ssh>@<host-produzione>
```

The production paths used by the sync are fixed in `local.sh`:

- repository: `/home/ubuntu/sergej/websites/cosmonauta.dev/ghost`
- backups: `/home/ubuntu/sergej/websites/cosmonauta.dev/backup`

Then start Ghost:

```sh
./local.sh up
```

### Sviluppo del tema locale

`compose.local.yml` monta `./cosmonauta_theme` direttamente come tema
`cosmonauta` nell'istanza locale; il mount non esiste in produzione. Per
sviluppare senza caricare ZIP:

```sh
./local.sh up
cd cosmonauta_theme
pnpm install --frozen-lockfile
pnpm dev
```

Aprire `http://localhost:2368/ghost`, selezionare `cosmonauta` in
**Settings → Design** e visualizzare il sito su `http://localhost:2368`.
`pnpm dev` rigenera gli asset CSS e JavaScript. Dopo una modifica ai template
`.hbs` o a `package.json`, eseguire `./local.sh restart` dalla root del
repository per far ricaricare il tema a Ghost. Nessuna di queste operazioni
carica o modifica il tema in produzione.

`./local.sh sync` replaces local uploads and database with a consistent export from production. It requires SSH access configured by `PRODUCTION_SSH`, asks for confirmation, and never uploads local data to production.

## Production

On the server, create the production environment file:

```sh
cp .env.production.example .env
```

Configure `.env` with real, unique secrets and SMTP credentials:

```dotenv
GHOST_ENV_FILE=.env
DOMAIN=www.cosmonauta.dev
GHOST_VERSION=6.55.0-alpine
DATABASE_ROOT_PASSWORD=<password-lunga-e-casuale-MySQL>
DATABASE_USER=ghost
DATABASE_PASSWORD=<password-lunga-e-casuale-Ghost>
UPLOAD_LOCATION=./data/production/ghost
MYSQL_DATA_LOCATION=./data/production/mysql

mail__transport=SMTP
mail__options__host=<host-SMTP>
mail__options__port=465
mail__options__secure=true
mail__options__auth__user=<utente-SMTP>
mail__options__auth__pass=<password-SMTP>
mail__from="'Cosmonauta' <indirizzo-mittente@example.com>"
```

`DATABASE_ROOT_PASSWORD`, `DATABASE_USER`, `DATABASE_PASSWORD`, `UPLOAD_LOCATION` and `MYSQL_DATA_LOCATION` must not be changed after the first MySQL initialization. Then start Ghost:

```sh
./ghost.sh up
```

Create an on-demand backup with:

```sh
./ghost.sh backup
```

It writes `/home/ubuntu/sergej/websites/cosmonauta.dev/backup/backup_YYYYMMDD_HHMMSS.tar.bz2`. Each archive contains a complete `db.sql.bz2` and `upload.tar.bz2`; Ghost's regenerable responsive-image cache (`images/size`) is excluded. Backups older than 30 days are removed.

Point both `cosmonauta.dev` and `www.cosmonauta.dev` DNS records to the server. Caddy obtains TLS certificates, redirects the apex domain to `www`, proxies Ghost, and sends only the required ActivityPub routes to Ghost's hosted `ap.ghost.org` service.

No Tinybird service, analytics proxy, or self-hosted ActivityPub service is included. Local Compose has no public Caddy route and no ActivityPub proxy, so local posts cannot be delivered to the Fediverse.
