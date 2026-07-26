# All three tools are pure client-side static apps, so instead of running
# their containers we copy the built assets out of the official images into
# a single Caddy server. Update tools with: docker compose build --pull

ARG BENTOPDF_IMAGE=bentopdf/bentopdf:latest
ARG CYBERCHEF_IMAGE=ghcr.io/gchq/cyberchef:latest
ARG EXCALIDRAW_IMAGE=excalidraw/excalidraw:latest

FROM ${BENTOPDF_IMAGE} AS bentopdf
FROM ${CYBERCHEF_IMAGE} AS cyberchef
FROM ${EXCALIDRAW_IMAGE} AS excalidraw

FROM caddy:2-alpine

COPY --from=bentopdf   /usr/share/nginx/html /srv/bentopdf
COPY --from=cyberchef  /usr/share/nginx/html /srv/cyberchef
COPY --from=excalidraw /usr/share/nginx/html /srv/excalidraw
COPY landing /srv/landing

COPY Caddyfile /etc/caddy/Caddyfile
