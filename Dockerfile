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
# JSON Crack loads the Monaco editor from cdn.jsdelivr.net at runtime, which
# breaks both the air-gap principle and the CSP. Vendor the same version
# locally and point the bundles at it.
RUN MVER=$(grep -rhoE "monaco-editor@[0-9]+\.[0-9]+\.[0-9]+" apps/www/out/_next/static/chunks | head -1 | cut -d@ -f2) && \
    npm install --prefix /tmp/monaco monaco-editor@${MVER} && \
    mkdir -p apps/www/out/monaco && \
    cp -r /tmp/monaco/node_modules/monaco-editor/min/vs apps/www/out/monaco/vs && \
    find apps/www/out/_next -name "*.js" -exec \
      sed -i -e "s|https://cdn.jsdelivr.net/npm/monaco-editor@${MVER}/min/vs|/monaco/vs|g" \
             -e "s|https://unpkg.com/monaco-editor@${MVER}/min/vs|/monaco/vs|g" {} +

# drawDB links two icon-font CDNs from its index.html; vendor them so the
# CSP can stay locked to self (versions must match what its HTML references)
FROM alpine:3 AS drawdb-fonts
RUN apk add --no-cache curl && \
    mkdir -p /vendor/bootstrap-icons/fonts /vendor/fontawesome/css /vendor/fontawesome/webfonts && \
    curl -fsSL https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css -o /vendor/bootstrap-icons/bootstrap-icons.css && \
    curl -fsSL https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/fonts/bootstrap-icons.woff2 -o /vendor/bootstrap-icons/fonts/bootstrap-icons.woff2 && \
    curl -fsSL https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/fonts/bootstrap-icons.woff -o /vendor/bootstrap-icons/fonts/bootstrap-icons.woff && \
    for f in fa-brands-400.woff2 fa-brands-400.ttf fa-regular-400.woff2 fa-regular-400.ttf fa-solid-900.woff2 fa-solid-900.ttf fa-v4compatibility.woff2 fa-v4compatibility.ttf; do \
      curl -fsSL "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/webfonts/$f" -o "/vendor/fontawesome/webfonts/$f"; done && \
    curl -fsSL https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css -o /vendor/fontawesome/css/all.min.css

FROM caddy:2-alpine

COPY --from=bentopdf   /usr/share/nginx/html /srv/bentopdf
COPY --from=cyberchef  /usr/share/nginx/html /srv/cyberchef
COPY --from=excalidraw /usr/share/nginx/html /srv/excalidraw
# draw.io's official image is Tomcat, but the webapp itself is fully static
COPY --from=drawio     /usr/local/tomcat/webapps/draw /srv/drawio
COPY --from=ittools    /usr/share/nginx/html /srv/ittools
COPY --from=drawdb     /usr/share/nginx/html /srv/drawdb
COPY --from=drawdb-fonts /vendor /srv/drawdb/vendor
RUN sed -i \
    -e "s|https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css|/vendor/bootstrap-icons/bootstrap-icons.css|" \
    -e "s|https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css|/vendor/fontawesome/css/all.min.css|" \
    /srv/drawdb/index.html
COPY --from=mermaid    /usr/share/nginx/html /srv/mermaid
COPY --from=vert       /usr/share/nginx/html /srv/vert
COPY --from=jsoncrack  /src/apps/www/out     /srv/jsoncrack
COPY landing /srv/landing

COPY Caddyfile /etc/caddy/Caddyfile
