#!/bin/sh

set -e

DISCORD_LAYER_WORKING_DIR=${DISCORD_LAYER_WORKING_DIR:-build-discordbot}
PYTHON_PACKAGES_PATH=python/lib/python3.12/site-packages

# Create a DISCORD_LAYER_WORKING_DIR folder in the root and then create a standard Python packages path `python/lib/python3.x/site-packages`
echo "Generating Lambda layer in" "$DISCORD_LAYER_WORKING_DIR"/"$PYTHON_PACKAGES_PATH"
mkdir -p "$DISCORD_LAYER_WORKING_DIR"/"$PYTHON_PACKAGES_PATH"
cd "$DISCORD_LAYER_WORKING_DIR"

# Do a targeted pip install of the required libs
python3 -m pip install PyNaCl requests aws-lambda-powertools -t "$PYTHON_PACKAGES_PATH"

# return OK result
exit 0
