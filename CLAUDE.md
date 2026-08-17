# Project guidance

This repository runs Ghost and MySQL using Docker Compose.

- Always combine `compose.yml` with either `compose.local.yml` or `compose.production.yml`.
- Use `./local.sh` for local operations and `./ghost.sh` on the production server.
- Local data lives below `data/local`; production data lives below `data/production` and must never be committed.
- Production joins the external Docker network named `caddy`. The server's `caddy-docker-proxy` uses the labels in `compose.production.yml`.
- ActivityPub is not self-hosted. In production, the three ActivityPub request paths are proxied to Ghost's hosted service; local has no such routes.
- Do not add Tinybird or the bundled Caddy service back to this setup.
