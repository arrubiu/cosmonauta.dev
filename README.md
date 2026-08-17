# Cosmonauta Ghost

Ghost runs with MySQL. The base [compose.yml](compose.yml) is always combined with one override:

- `compose.local.yml`: local Ghost at `http://localhost:2368`, accessible only from the local machine.
- `compose.production.yml`: production Ghost behind the server's existing `caddy-docker-proxy`, using the external `caddy` network.

## Local development

Copy `.env.local.example` to `.env.local`, choose local passwords, then use:

```sh
./local.sh up
```

`./local.sh sync` replaces local uploads and database with a consistent export from production. It requires SSH access configured by `PRODUCTION_SSH` and `PRODUCTION_PROJECT_DIR`, asks for confirmation, and never uploads local data to production.

## Production

On the server, copy `.env.production.example` to `.env`, provide real secrets and SMTP credentials, then use:

```sh
./ghost.sh up
```

Point both `cosmonauta.dev` and `www.cosmonauta.dev` DNS records to the server. Caddy obtains TLS certificates, redirects the apex domain to `www`, proxies Ghost, and sends only the required ActivityPub routes to Ghost's hosted `ap.ghost.org` service.

No Tinybird service, analytics proxy, or self-hosted ActivityPub service is included. Local Compose has no public Caddy route and no ActivityPub proxy, so local posts cannot be delivered to the Fediverse.
