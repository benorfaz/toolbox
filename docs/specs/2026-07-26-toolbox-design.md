# Toolbox — Design

**Date:** 2026-07-26
**Domain:** tools.example.com

## Goal

Self-host a set of browser-based utilities behind one domain, with a landing
page listing them. Single repo, single `docker compose up`, runs identically in
OrbStack locally and on any Docker VPS. Keep resource usage minimal.

## Key finding

All three tools are **pure client-side static apps** (processing happens in the
browser — BentoPDF via WASM, CyberChef via JS, Excalidraw as a React SPA).
There is no backend and no database to share. Maximum mutualization is
therefore **one single container**: a Caddy web server serving four static
sites.

## Architecture

```
                 ┌────────────────────────────────────────────┐
                 │  toolbox container (caddy:2-alpine)        │
 :80 / :443 ───▶ │  tools.example.com       → /srv/landing   │
                 │  pdf.tools.example.com   → /srv/bentopdf  │
                 │  chef.tools.example.com  → /srv/cyberchef │
                 │  draw.tools.example.com  → /srv/excalidraw│
                 └────────────────────────────────────────────┘
```

- **Build:** multi-stage Dockerfile copies the static assets out of each
  project's official image (`bentopdf/bentopdf`, `ghcr.io/gchq/cyberchef`,
  `excalidraw/excalidraw`) into a Caddy image. Updating tools =
  `docker compose build --pull`.
- **Web server:** Caddy — one binary, automatic Let's Encrypt TLS in
  production, near-zero config.
- **Runtime footprint:** 1 container, 1 process, ~30–50 MB RAM.

## Decisions & trade-offs

1. **Subdomains, not paths.** Excalidraw's build assumes it is served from `/`
   (absolute asset paths), so path-based routing (`/draw`) would need fragile
   rewriting. Subdomains work for all tools unmodified. Requires DNS records
   (or one wildcard) — see Deployment.
2. **Copy static assets vs. run official containers.** Running the 3 official
   images + a proxy would be 4 containers, each with its own nginx. Copying
   assets into one Caddy container was chosen per the "keep it lean"
   requirement. Trade-off: tool updates require an image rebuild instead of a
   pull-and-restart (mitigated: rebuild is one command and fast).
3. **Pinned image tags.** Tool images are pinned to major/latest in the
   Dockerfile `ARG`s so bumping versions is an explicit, reviewable change.
4. **Same config locally and in prod.** The Caddyfile uses `$DOMAIN` and
   `$SCHEME` env vars. Defaults (`localhost`, `http`) make
   `docker compose up` work out of the box: browsers resolve
   `pdf.localhost`, `chef.localhost`, `draw.localhost` to 127.0.0.1 natively.
   In prod, `.env` sets `DOMAIN=tools.example.com` and `SCHEME=https` and
   Caddy provisions certificates automatically.
5. **Excalidraw collaboration is out of scope.** Live-collab needs the
   `excalidraw-room` websocket server (a second container). Solo drawing,
   local storage and file export all work without it. Can be added later.

## Components

| Path | Purpose |
|---|---|
| `Dockerfile` | Multi-stage build: 3 tool images → assets → Caddy |
| `Caddyfile` | 4 virtual hosts, gzip/zstd, SPA fallback for Excalidraw |
| `docker-compose.yml` | Single `toolbox` service, cert volumes |
| `landing/` | Static landing page (no framework, no external requests) |
| `.env.example` | `DOMAIN` / `SCHEME` for production |

## Landing page

Single self-contained HTML file (inline CSS/JS, no external fonts or CDNs —
it must work air-gapped). Lists each tool with name, description and link.
Links are computed at runtime from `location.hostname` so the same page works
on `localhost` and `tools.example.com`.

## Deployment

- **Local:** `docker compose up -d` → http://localhost (tools on
  `*.localhost`).
- **VPS:** DNS `A` records for `tools.example.com` +
  `*.tools.example.com` (wildcard) → server IP. `cp .env.example .env`,
  set `DOMAIN`/`SCHEME`, `docker compose up -d`. Caddy handles TLS.

## Error handling / testing

- Caddy serves a 404 for unknown hosts (default vhost catch is the landing
  page only for the apex domain).
- Verification: `docker compose up` locally, then browser-check all four
  hosts render and tools are functional.
