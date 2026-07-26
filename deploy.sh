#!/usr/bin/env bash
#
# Deploy (or update) the toolbox on a Docker VPS. Idempotent — run it for the
# first install and re-run it any time to pull the latest repo + tool images.
#
# Usage, on the VPS (Debian/Ubuntu or any distro supported by get.docker.com):
#
#   curl -fsSL https://raw.githubusercontent.com/benorfaz/toolbox/main/deploy.sh | DOMAIN=tools.example.com bash
#     — or —
#   git clone <repo> /opt/toolbox && DOMAIN=tools.example.com /opt/toolbox/deploy.sh
#
# DOMAIN is only needed on the first run — after that it lives in .env.
# Other overrides: REPO_URL, APP_DIR (default /opt/toolbox), SCHEME.

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/benorfaz/toolbox.git}"
APP_DIR="${APP_DIR:-/opt/toolbox}"
DOMAIN="${DOMAIN:-}"
SCHEME="${SCHEME:-https}"

if [ -z "$DOMAIN" ] && [ ! -f "$APP_DIR/.env" ]; then
  echo "First run needs a domain: DOMAIN=tools.example.com $0" >&2
  exit 1
fi

log() { printf '\n\033[1;33m▮ %s\033[0m\n' "$*"; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null || { echo "Run as root or install sudo." >&2; exit 1; }
  SUDO="sudo"
fi

# ── Docker (engine + compose plugin) ─────────────────────────────────────────
if ! command -v docker >/dev/null; then
  log "Installing Docker via get.docker.com"
  curl -fsSL https://get.docker.com | $SUDO sh
else
  log "Docker already installed: $(docker --version)"
fi

docker compose version >/dev/null 2>&1 || {
  echo "Docker is installed but the 'docker compose' plugin is missing." >&2
  echo "Install the docker-compose-plugin package for your distro." >&2
  exit 1
}

# ── Repo ─────────────────────────────────────────────────────────────────────
if [ -d "$APP_DIR/.git" ]; then
  log "Updating repo in $APP_DIR"
  $SUDO git -C "$APP_DIR" pull --ff-only
else
  log "Cloning $REPO_URL to $APP_DIR"
  $SUDO git clone "$REPO_URL" "$APP_DIR"
fi

# ── Production config (kept if it already exists) ────────────────────────────
if [ ! -f "$APP_DIR/.env" ]; then
  log "Writing $APP_DIR/.env (DOMAIN=$DOMAIN, SCHEME=$SCHEME)"
  $SUDO tee "$APP_DIR/.env" >/dev/null <<EOF
DOMAIN=$DOMAIN
SCHEME=$SCHEME
EOF
else
  log "Keeping existing $APP_DIR/.env"
fi

# ── Build + run ──────────────────────────────────────────────────────────────
log "Building and starting the stack (pulls latest tool images)"
$SUDO docker compose -f "$APP_DIR/docker-compose.yml" --project-directory "$APP_DIR" build --pull
$SUDO docker compose -f "$APP_DIR/docker-compose.yml" --project-directory "$APP_DIR" up -d

log "Waiting for Caddy"
sleep 2
if curl -fsS -o /dev/null --max-time 5 http://localhost/; then
  echo "  local HTTP check: OK"
else
  echo "  local HTTP check failed — inspect with: docker logs toolbox" >&2
fi

log "Done"
cat <<EOF
  Landing:   $SCHEME://$DOMAIN
  Tools:     $SCHEME://pdf.$DOMAIN  $SCHEME://chef.$DOMAIN  $SCHEME://draw.$DOMAIN

  Checklist if this is a fresh server:
   - DNS: A records for $DOMAIN and *.$DOMAIN -> this server's IP
   - Firewall: ports 80 and 443 (tcp+udp) open
  TLS certificates are provisioned automatically by Caddy on first request.
EOF
