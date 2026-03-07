#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# install_valheim.sh
# Installs / updates SteamCMD, Valheim Dedicated Server, and (optionally)
# the BepInEx mod manager.
#
# Environment variables:
#   HOME              — home directory of the user running the script
#   BEPINEX_ENABLED   — "true" to install BepInEx (default: "false")
#   BEPINEX_VERSION   — BepInEx release version (default: "5.4.23.2")
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

HOME_DIR="$HOME"
STEAM_DIR="${HOME_DIR}/steam"
VALHEIM_DIR="${HOME_DIR}/valheim"

# ── Colours for log output ──────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

log()  { echo -e "${GREEN}[INSTALL]${NC} $*"; }
warn() { echo -e "${YELLOW}[INSTALL]${NC} $*"; }

# ─────────────────────────────────────────────────────────────────────────────
# 1. SteamCMD
# ─────────────────────────────────────────────────────────────────────────────
install_steamcmd() {
    log "Installing / updating SteamCMD …"
    mkdir -p "${STEAM_DIR}" && cd "${STEAM_DIR}"

    if [[ ! -f "${STEAM_DIR}/steamcmd.sh" ]]; then
        curl -sSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
            | tar zxf -
        log "SteamCMD downloaded."
    else
        log "SteamCMD already present — skipping download."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Valheim Dedicated Server  (Steam App ID 896660)
# ─────────────────────────────────────────────────────────────────────────────
install_valheim() {
    log "Installing / updating Valheim Dedicated Server …"
    mkdir -p "${VALHEIM_DIR}"

    "${STEAM_DIR}/steamcmd.sh" \
        +force_install_dir "${VALHEIM_DIR}" \
        +login anonymous \
        +app_update 896660 validate \
        +quit

    log "Valheim Dedicated Server is up to date."
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. BepInEx mod manager  (https://github.com/BepInEx/BepInEx)
#    Downloads the unix (x64) build from GitHub releases.
# ─────────────────────────────────────────────────────────────────────────────
install_bepinex() {
    local version="${BEPINEX_VERSION:-5.4.23.2}"

    if [[ "${BEPINEX_ENABLED:-false}" != "true" ]]; then
        warn "BepInEx is disabled (BEPINEX_ENABLED != true). Skipping."
        return 0
    fi

    # Skip if already installed at the requested version
    local marker="${VALHEIM_DIR}/.bepinex_version"
    if [[ -f "${marker}" ]] && [[ "$(cat "${marker}")" == "${version}" ]]; then
        log "BepInEx v${version} already installed — skipping."
        return 0
    fi

    log "Installing BepInEx v${version} …"

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local archive="${tmp_dir}/bepinex.zip"

    # Download the unix (x64) build from GitHub releases
    local url="https://github.com/BepInEx/BepInEx/releases/download/v${version}/BepInEx_linux_x64_${version}.zip"
    log "Downloading from ${url}"
    curl -fsSL -o "${archive}" "${url}"

    # Extract into the Valheim server directory
    unzip -o "${archive}" -d "${VALHEIM_DIR}"
    rm -rf "${tmp_dir}"

    # Make the doorstop preloader executable
    chmod +x "${VALHEIM_DIR}/run_bepinex.sh" 2>/dev/null || true

    # Create the BepInEx folder structure for plugins & config
    mkdir -p "${VALHEIM_DIR}/BepInEx/plugins"
    mkdir -p "${VALHEIM_DIR}/BepInEx/config"

    # Stamp the installed version
    echo "${version}" > "${marker}"

    log "BepInEx v${version} installed successfully."
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Default mods from Thunderstore
# ─────────────────────────────────────────────────────────────────────────────
install_thunderstore_mod() {
    local author="$1"
    local name="$2"
    local version="$3"
    local dll="$4"
    local dest="${VALHEIM_DIR}/BepInEx/plugins/${dll}"

    if [[ -f "${dest}" ]]; then
        log "  ${name} already installed — skipping."
        return 0
    fi

    log "  Downloading ${name} v${version} …"
    local url="https://thunderstore.io/package/download/${author}/${name}/${version}/"
    curl -sSL "${url}" -o "/tmp/${name}.zip"
    unzip -o -j "/tmp/${name}.zip" "${dll}" -d "${VALHEIM_DIR}/BepInEx/plugins/" 2>/dev/null \
        || unzip -o "/tmp/${name}.zip" "${dll}" -d "${VALHEIM_DIR}/BepInEx/plugins/" 2>/dev/null \
        || warn "  Could not extract ${dll} from ${name}.zip"
    rm -f "/tmp/${name}.zip"
}

install_default_mods() {
    if [[ "${BEPINEX_ENABLED:-false}" != "true" ]]; then
        return 0
    fi

    log "Installing default mods …"
    install_thunderstore_mod "Marf"    "FuelEternal"   "1.2.1"  "FuelEternal.dll"
    install_thunderstore_mod "Mydayyy" "ServerSideMap" "1.3.13" "ServerSideMap.dll"
    log "Default mods installed."
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. ServerSideMap configuration — enable map and marker sharing
# ─────────────────────────────────────────────────────────────────────────────
configure_serversidemap() {
    if [[ "${BEPINEX_ENABLED:-false}" != "true" ]]; then
        return 0
    fi

    local ssm_cfg="${VALHEIM_DIR}/BepInEx/config/eu.mydayyy.plugins.serversidemap.cfg"
    if [[ -f "${ssm_cfg}" ]]; then
        log "ServerSideMap config already exists — skipping."
        return 0
    fi

    log "Creating ServerSideMap config (map + marker sharing enabled) …"
    cat > "${ssm_cfg}" << 'SSMEOF'
[General]

## Client: Whether or not to participate in sharing the map.
## Server: Whether or not to allow map sharing.
# Setting type: Boolean
# Default value: true
EnableMapShare = true

## Client: Whether or not to participate in sharing markers.
## Server: Whether or not to allow marker sharing.
# Setting type: Boolean
# Default value: false
EnableMarkerShare = true

[PinShare]

## A local pin will not be uploaded if a pin exists in the given radius
## on the server (when using /convertpins ignorelocaldupes).
# Setting type: Single
# Default value: 15
DuplicatePinRadius = 15

[Hotkeys]

## Hotkey to run /convertpins
# Setting type: String
# Default value:
KeyConvertAll =

## Hotkey to run /convertpins ignorelocaldupes
# Setting type: String
# Default value:
KeyConvertIgnoreDupes =
SSMEOF
    log "ServerSideMap config created."
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
main() {
    log "═══════════════════════════════════════════════════════════════"
    log " Valheim Server — Install / Update"
    log "═══════════════════════════════════════════════════════════════"

    install_steamcmd
    install_valheim
    install_bepinex
    install_default_mods
    configure_serversidemap

    log "═══════════════════════════════════════════════════════════════"
    log " Installation complete."
    log "═══════════════════════════════════════════════════════════════"
}

main "$@"
