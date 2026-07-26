# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Self-hosted utilities hub for `tools.example.com`: a landing page plus
BentoPDF, CyberChef, Excalidraw and draw.io. There is no application code to compile
and no test suite — the repo is a Docker packaging of third-party static apps
plus one hand-written HTML landing page.

## Commands

```sh
docker compose up -d --build      # build + run everything
docker compose build --pull && docker compose up -d   # update the three tools
docker logs toolbox               # Caddy logs
```

Verify locally: http://localhost (landing), http://pdf.localhost,
http://chef.localhost, http://draw.localhost — the subdomains of `localhost`
resolve natively in browsers. There is no dev server; the landing page is
plain HTML, so rebuilding the image (or a bind-mount) is how changes appear.

## Architecture — the one thing to understand

The entire stack is **one container**. All three tools are pure client-side
static apps, so `Dockerfile` uses their official images
(`bentopdf/bentopdf`, `ghcr.io/gchq/cyberchef`, `excalidraw/excalidraw`,
`jgraph/drawio`) as build stages only, copying each one's static files into
`/srv/<name>` of a `caddy:2-alpine` image (draw.io's live in its Tomcat
webapp dir; the servlets it ships are unused). `Caddyfile` maps one virtual host
per tool. Deliberately no per-tool containers, no reverse proxy tier, no
database — keep it that way unless a future tool genuinely needs a backend.

Environment switching is done entirely through two env vars consumed by the
Caddyfile site addresses (`{$SCHEME:http}://pdf.{$DOMAIN:localhost}` etc.):

- No `.env` → `http://localhost` — local mode, works out of the box.
- Production `.env` (from `.env.example`): `DOMAIN=tools.example.com`,
  `SCHEME=https` → Caddy provisions Let's Encrypt automatically. DNS needs
  the apex plus `*.tools.example.com`.

Routing is subdomain-based (`pdf.`, `chef.`, `draw.`, `drawio.`), **not** path-based:
Excalidraw's build only works served from the site root. Don't try to move
tools under paths without checking that constraint.

## Landing page (`landing/index.html`)

Single self-contained file — inline CSS/JS, no external fonts, CDNs or
frameworks. It must keep working air-gapped; don't introduce external
requests. Tool links are `<a data-sub="pdf" ...>` rewritten at runtime to
`<sub>.<current hostname>`, which is how one page works on both localhost and
production — keep the hardcoded production `href` as the no-JS fallback.

## Adding a tool

1. `Dockerfile`: add its image as a build stage, copy its static files to
   `/srv/<name>`.
2. `Caddyfile`: add a `{$SCHEME:http}://<sub>.{$DOMAIN:localhost}` vhost
   (add `try_files {path} /index.html` if it's a SPA).
3. `landing/index.html`: add a card with `data-sub="<sub>"`.
4. Design decisions and rationale live in
   `docs/specs/2026-07-26-toolbox-design.md`; update it if the architecture
   changes.
