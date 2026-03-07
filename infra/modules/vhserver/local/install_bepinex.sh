#!/bin/bash
set -e

echo "Installing BepInEx mod loader for Valheim"

BEPINEX_VERSION="5.4.22.0"
BEPINEX_URL="https://github.com/BepInEx/BepInEx/releases/download/v$${BEPINEX_VERSION}/BepInEx_unix_$${BEPINEX_VERSION}.zip"
INSTALL_DIR="/home/${username}/valheim"

# Download and extract BepInEx if not already present
if [ ! -f "$${INSTALL_DIR}/doorstop_config.ini" ]; then
    echo "Downloading BepInEx v$${BEPINEX_VERSION}..."
    curl -L "$${BEPINEX_URL}" -o /tmp/bepinex.zip
    unzip -o /tmp/bepinex.zip -d "$${INSTALL_DIR}"
    rm -f /tmp/bepinex.zip
    echo "BepInEx installed successfully"
else
    echo "BepInEx already installed, skipping download"
fi

# Ensure BepInEx directories exist for plugins and config
mkdir -p "$${INSTALL_DIR}/BepInEx/plugins"
mkdir -p "$${INSTALL_DIR}/BepInEx/config"

###############################################################################
# Install default mods from Thunderstore

install_thunderstore_mod() {
    local author="$1"
    local name="$2"
    local version="$3"
    local dll="$4"
    local dest="$${INSTALL_DIR}/BepInEx/plugins/$${dll}"

    if [ -f "$${dest}" ]; then
        echo "  $${name} already installed, skipping"
        return
    fi

    echo "  Downloading $${name} v$${version}..."
    local url="https://thunderstore.io/package/download/$${author}/$${name}/$${version}/"
    curl -sL "$${url}" -o "/tmp/$${name}.zip"
    unzip -o -j "/tmp/$${name}.zip" "$${dll}" -d "$${INSTALL_DIR}/BepInEx/plugins/" 2>/dev/null \
        || unzip -o "/tmp/$${name}.zip" "$${dll}" -d "$${INSTALL_DIR}/BepInEx/plugins/" 2>/dev/null \
        || echo "  WARNING: could not extract $${dll} from $${name}.zip"
    rm -f "/tmp/$${name}.zip"
}

echo "Installing default mods..."
install_thunderstore_mod "Marf"    "FuelEternal"   "1.2.1"  "FuelEternal.dll"
install_thunderstore_mod "Mydayyy" "ServerSideMap" "1.3.13" "ServerSideMap.dll"

###############################################################################
# ServerSideMap config — enable both map and marker sharing

SSM_CFG="$${INSTALL_DIR}/BepInEx/config/eu.mydayyy.plugins.serversidemap.cfg"
if [ ! -f "$${SSM_CFG}" ]; then
    echo "  Creating ServerSideMap config (map + marker share enabled)..."
    cat > "$${SSM_CFG}" << 'SSMEOF'
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
else
    echo "  ServerSideMap config already exists, skipping"
fi

###############################################################################
# Sync user-provided mods from S3 (overrides defaults if present)

echo "Syncing BepInEx mods from S3..."
aws s3 sync "s3://${bucket}/bepinex/plugins/" "$${INSTALL_DIR}/BepInEx/plugins/" 2>/dev/null || echo "No plugins found in S3, skipping."
aws s3 sync "s3://${bucket}/bepinex/config/"  "$${INSTALL_DIR}/BepInEx/config/"  2>/dev/null || echo "No config found in S3, skipping."

echo "BepInEx installation complete"
echo "Place your mods in S3: s3://${bucket}/bepinex/plugins/"
