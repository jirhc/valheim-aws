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

# ── Step 1: Install / update server & mods ──────────────────────────────────
log "Running install / update …"
bash "${HOME}/install_valheim.sh"

# ── Step 2: Start the server ────────────────────────────────────────────────
log "Launching server …"
exec bash "${HOME}/start_valheim.sh"
