# All three tools are pure client-side static apps, so instead of running
# their containers we copy the built assets out of the official images into
# a single Caddy server. Update tools with: docker compose build --pull

ARG BENTOPDF_IMAGE=bentopdf/bentopdf:latest
ARG CYBERCHEF_IMAGE=ghcr.io/gchq/cyberchef:latest
ARG EXCALIDRAW_IMAGE=excalidraw/excalidraw:latest
ARG DRAWIO_IMAGE=jgraph/drawio:latest
ARG ITTOOLS_IMAGE=corentinth/it-tools:latest
ARG DRAWDB_IMAGE=ghcr.io/drawdb-io/drawdb:latest
ARG MERMAID_IMAGE=ghcr.io/mermaid-js/mermaid-live-editor:latest
ARG VERT_IMAGE=ghcr.io/vert-sh/vert:latest

FROM ${BENTOPDF_IMAGE} AS bentopdf
FROM ${CYBERCHEF_IMAGE} AS cyberchef
FROM ${EXCALIDRAW_IMAGE} AS excalidraw
FROM ${DRAWIO_IMAGE} AS drawio
FROM ${ITTOOLS_IMAGE} AS ittools
FROM ${DRAWDB_IMAGE} AS drawdb
FROM ${MERMAID_IMAGE} AS mermaid
FROM ${VERT_IMAGE} AS vert

# JSON Crack publishes no image — build its static export from source
# (its package.json requires Node >= 24)
FROM node:24-alpine AS jsoncrack
RUN apk add --no-cache git && git clone --depth 1 https://github.com/AykutSarac/jsoncrack.com /src
WORKDIR /src
RUN corepack enable && pnpm install && pnpm build

FROM caddy:2-alpine

COPY --from=bentopdf   /usr/share/nginx/html /srv/bentopdf
COPY --from=cyberchef  /usr/share/nginx/html /srv/cyberchef
COPY --from=excalidraw /usr/share/nginx/html /srv/excalidraw
# draw.io's official image is Tomcat, but the webapp itself is fully static
COPY --from=drawio     /usr/local/tomcat/webapps/draw /srv/drawio
COPY --from=ittools    /usr/share/nginx/html /srv/ittools
COPY --from=drawdb     /usr/share/nginx/html /srv/drawdb
COPY --from=mermaid    /usr/share/nginx/html /srv/mermaid
COPY --from=vert       /usr/share/nginx/html /srv/vert
COPY --from=jsoncrack  /src/apps/www/out     /srv/jsoncrack
COPY landing /srv/landing

COPY Caddyfile /etc/caddy/Caddyfile
