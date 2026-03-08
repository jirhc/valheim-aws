#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# entrypoint.sh
# Docker entrypoint — runs install/update, then starts the server.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[ENTRYPOINT]${NC} $*"; }

log "═══════════════════════════════════════════════════════════════"
log " Valheim Dedicated Server Container"
log "═══════════════════════════════════════════════════════════════"

# ── Step 1: Generate valheim.conf from environment variables ────────────────
#   This mirrors the Terraform-managed valheim.conf used on EC2.
log "Generating server configuration …"
cat > "${HOME}/valheim/valheim.conf" <<EOF
SERVER_NAME="${SERVER_NAME:-MyValheimServer}"
WORLD_NAME="${WORLD_NAME:-MyWorld}"
SERVER_PASSWORD="${SERVER_PASSWORD:-changeme}"
SERVER_PORT="${SERVER_PORT:-2456}"
SERVER_PUBLIC="${SERVER_PUBLIC:-1}"
BEPINEX_ENABLED="${BEPINEX_ENABLED:-true}"
BEPINEX_VERSION="${BEPINEX_VERSION:-5.4.23.2}"
ENABLE_CROSSPLAY="${ENABLE_CROSSPLAY:-false}"
EOF

# ── Step 2: Install / update server & mods ──────────────────────────────────
log "Running install / update …"
bash "${HOME}/install_valheim.sh"

# ── Step 3: Start the server ────────────────────────────────────────────────
log "Launching server …"
exec bash "${HOME}/start_valheim.sh"
