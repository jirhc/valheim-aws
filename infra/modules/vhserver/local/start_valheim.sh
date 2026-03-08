#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# start_valheim.sh
# Starts the Valheim Dedicated Server, optionally with BepInEx mod support.
# Configuration is loaded from valheim.conf (Terraform-managed on EC2,
# generated from env vars on Docker). Falls back to env var defaults.
#
# Environment variables:
#   SERVER_NAME       — server name shown in the browser (default: MyValheimServer)
#   WORLD_NAME        — world / save-file name (default: MyWorld)
#   SERVER_PASSWORD   — password, ≥ 5 chars (default: changeme)
#   SERVER_PORT       — base UDP port (default: 2456)
#   SERVER_PUBLIC     — 1 = listed in browser, 0 = private (default: 1)
#   BEPINEX_ENABLED   — "true" to enable BepInEx (default: "false")
#   ENABLE_CROSSPLAY  — "true" to enable crossplay (default: "false")
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Source configuration (Terraform-managed on EC2, generated on Docker) ────
VALHEIM_CONF="${HOME}/valheim/valheim.conf"
[[ -f "${VALHEIM_CONF}" ]] && source "${VALHEIM_CONF}"

HOME_DIR="$HOME"
VALHEIM_DIR="${HOME_DIR}/valheim"

# ── Defaults ────────────────────────────────────────────────────────────────
SERVER_NAME="${SERVER_NAME:-MyValheimServer}"
WORLD_NAME="${WORLD_NAME:-MyWorld}"
SERVER_PASSWORD="${SERVER_PASSWORD:-changeme}"
SERVER_PORT="${SERVER_PORT:-2456}"
SERVER_PUBLIC="${SERVER_PUBLIC:-1}"
BEPINEX_ENABLED="${BEPINEX_ENABLED:-false}"
ENABLE_CROSSPLAY="${ENABLE_CROSSPLAY:-false}"

# ── Colours ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[SERVER]${NC} $*"; }
warn() { echo -e "${YELLOW}[SERVER]${NC} $*"; }

# ─────────────────────────────────────────────────────────────────────────────
# Trap SIGTERM / SIGINT for graceful shutdown
# ─────────────────────────────────────────────────────────────────────────────
shutdown() {
    log "Caught shutdown signal — stopping Valheim server (PID ${SERVER_PID:-?}) …"
    if [[ -n "${SERVER_PID:-}" ]]; then
        kill -SIGINT "${SERVER_PID}" 2>/dev/null || true
        wait "${SERVER_PID}" 2>/dev/null || true
    fi
    log "Server stopped."
    exit 0
}
trap shutdown SIGTERM SIGINT

# ─────────────────────────────────────────────────────────────────────────────
# Validate configuration
# ─────────────────────────────────────────────────────────────────────────────
validate_config() {
    if [[ ${#SERVER_PASSWORD} -lt 5 ]]; then
        warn "SERVER_PASSWORD must be at least 5 characters long."
        exit 1
    fi
    # Valheim rejects passwords that contain the server name
    if [[ "${SERVER_PASSWORD}" == *"${SERVER_NAME}"* ]]; then
        warn "SERVER_PASSWORD must NOT contain the SERVER_NAME."
        exit 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Configure BepInEx environment (doorstop / LD_PRELOAD)
# ─────────────────────────────────────────────────────────────────────────────
setup_bepinex() {
    if [[ "${BEPINEX_ENABLED}" != "true" ]]; then
        return 0
    fi

    log "Enabling BepInEx mod loader …"

    export DOORSTOP_ENABLE=TRUE
    export DOORSTOP_INVOKE_DLL_PATH="${VALHEIM_DIR}/BepInEx/core/BepInEx.Preloader.dll"
    export DOORSTOP_CORLIB_OVERRIDE_PATH="${VALHEIM_DIR}/unstripped_corlib"

    # doorstop native library must be preloaded
    export LD_PRELOAD="libdoorstop_x64.so:${LD_PRELOAD:-}"
    export LD_LIBRARY_PATH="${VALHEIM_DIR}/doorstop_libs:${VALHEIM_DIR}/linux64:${LD_LIBRARY_PATH:-}"

    log "BepInEx environment configured."
}

# ─────────────────────────────────────────────────────────────────────────────
# Start the server
# ─────────────────────────────────────────────────────────────────────────────
start_server() {
    cd "${VALHEIM_DIR}"

    # Base library path (always needed)
    export LD_LIBRARY_PATH="${VALHEIM_DIR}/linux64:${LD_LIBRARY_PATH:-}"
    export SteamAppId=892970

    validate_config
    setup_bepinex

    log "═══════════════════════════════════════════════════════════════"
    log " Starting Valheim Dedicated Server"
    log "   Name     : ${SERVER_NAME}"
    log "   World    : ${WORLD_NAME}"
    log "   Port     : ${SERVER_PORT}"
    log "   Public   : ${SERVER_PUBLIC}"
    log "   Crossplay: ${ENABLE_CROSSPLAY}"
    log "   BepInEx  : ${BEPINEX_ENABLED}"
    log "═══════════════════════════════════════════════════════════════"

    local -a server_args=(
        -name "${SERVER_NAME}"
        -port "${SERVER_PORT}"
        -world "${WORLD_NAME}"
        -password "${SERVER_PASSWORD}"
        -batchmode
        -nographics
    )

    if [[ "${ENABLE_CROSSPLAY}" == "true" ]]; then
        server_args+=(-crossplay)
    else
        server_args+=(-public "${SERVER_PUBLIC}")
    fi

    ./valheim_server.x86_64 "${server_args[@]}" &

    SERVER_PID=$!
    log "Server started with PID ${SERVER_PID}."

    # Wait for the server process — this keeps the script alive so Docker
    # can forward signals and the container stays running.
    wait "${SERVER_PID}"
}

start_server
