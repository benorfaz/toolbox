# Toolbox

Self-hosted browser utilities behind one domain, in one container.

| Tool | Local | Production |
|---|---|---|
| Landing page | http://localhost | https://tools.example.com |
| [BentoPDF](https://github.com/bentopdf/bentopdf) — PDF workbench | http://pdf.localhost | https://pdf.tools.example.com |
| [CyberChef](https://github.com/gchq/CyberChef) — data Swiss-army knife | http://chef.localhost | https://chef.tools.example.com |
| [Excalidraw](https://github.com/excalidraw/excalidraw) — whiteboard | http://draw.localhost | https://draw.tools.example.com |
| [draw.io](https://github.com/jgraph/drawio) — structured diagrams | http://drawio.localhost | https://drawio.tools.example.com |
| [IT Tools](https://github.com/corentinth/it-tools) — dev utilities | http://it.localhost | https://it.tools.example.com |

All three tools run entirely in the browser (WASM/JS) — no backend, no
database, nothing leaves your machine. The whole stack is **one Caddy
container** (~40 MB RAM): a multi-stage [Dockerfile](Dockerfile) copies the
static builds out of each project's official image and Caddy serves them as
four virtual hosts. See [docs/specs](docs/specs/2026-07-26-toolbox-design.md)
for the design rationale.

## Run locally (OrbStack or any Docker)

```sh
docker compose up -d --build
```

Open http://localhost. The `pdf.` / `chef.` / `draw.` subdomains of
`localhost` resolve natively in modern browsers — no `/etc/hosts` edits.

## Deploy on a VPS

1. DNS: point `tools.example.com` **and** `*.tools.example.com`
   (or the three explicit subdomains) at the server.
2. On the server, run [deploy.sh](deploy.sh) — it installs Docker if needed,
   clones (or updates) the repo into `/opt/toolbox`, writes the production
   `.env` and starts the stack. Re-run the same script any time to update:

```sh
curl -fsSL https://raw.githubusercontent.com/benorfaz/toolbox/main/deploy.sh | DOMAIN=tools.example.com bash
```

`DOMAIN` is only required on the first run (it's persisted to `.env`).
Other overrides: `REPO_URL`, `APP_DIR` (default `/opt/toolbox`), `SCHEME`.

### Behind an existing reverse proxy (Traefik)

If Traefik (with its Docker provider) already owns ports 80/443 on the host,
deploy with [docker-compose.traefik.yml](docker-compose.traefik.yml) instead —
no ports are published, Traefik terminates TLS and routes the four hostnames
to the container:

```sh
curl -fsSL https://raw.githubusercontent.com/benorfaz/toolbox/main/deploy.sh | DOMAIN=tools.example.com TRAEFIK=1 TRAEFIK_NETWORK=proxy bash
```

Defaults: `TRAEFIK_NETWORK=traefik`, `TRAEFIK_ENTRYPOINT=websecure`,
`TRAEFIK_CERTRESOLVER=letsencrypt` — set them to match your Traefik setup
(all persisted to `.env` on first run).

Caddy obtains and renews Let's Encrypt certificates automatically
(ports 80/443 must be reachable).

## Update the tools

```sh
docker compose build --pull && docker compose up -d
```

To pin exact versions, set the `*_IMAGE` build args in the Dockerfile.

## Add a new tool

1. Add its image as a build stage in the [Dockerfile](Dockerfile) and copy its
   static files to `/srv/<name>`.
2. Add a `<sub>.{$DOMAIN}` vhost in the [Caddyfile](Caddyfile).
3. Add a card in [landing/index.html](landing/index.html) (`data-sub="<sub>"`).
