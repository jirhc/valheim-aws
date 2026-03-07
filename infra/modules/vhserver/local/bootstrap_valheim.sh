#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# bootstrap_valheim.sh  (AWS EC2 wrapper — Terraform template)
# Prepares the AWS environment (S3 sync, crontab, DNS, world restore)
# then delegates to the shared start_valheim.sh.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

HOME_DIR="/home/${username}"
VALHEIM_DIR="$${HOME_DIR}/valheim"
CONFIG_DIR="$${HOME_DIR}/.config/unity3d/IronGate/Valheim"
BUCKET="${bucket}"

echo "══════════════════════════════════════════════════════════════"
echo " Valheim bootstrap (AWS)"
echo "══════════════════════════════════════════════════════════════"

# ── Sync backup script from S3 ──────────────────────────────────────────────
echo "Syncing backup script"
aws s3 cp "s3://$${BUCKET}/backup_valheim.sh" "$${VALHEIM_DIR}/backup_valheim.sh"
chmod +x "$${VALHEIM_DIR}/backup_valheim.sh"

# ── Set up crontab ──────────────────────────────────────────────────────────
echo "Setting crontab"
aws s3 cp "s3://$${BUCKET}/crontab" "$${HOME_DIR}/crontab"
crontab < "$${HOME_DIR}/crontab"

# ── Update DNS (Route53 CNAME) ──────────────────────────────────────────────
%{ if use_domain ~}
echo "Updating CNAME"
aws s3 cp "s3://$${BUCKET}/update_cname.json" "$${HOME_DIR}/update_cname.json"
aws s3 cp "s3://$${BUCKET}/update_cname.sh" "$${HOME_DIR}/update_cname.sh"
chmod +x "$${HOME_DIR}/update_cname.sh"
bash "$${HOME_DIR}/update_cname.sh"
%{ endif ~}

# ── Restore world from S3 backup (if no local world exists) ─────────────────
echo "Checking if world files exist locally"
if [ ! -f "$${CONFIG_DIR}/worlds_local/${world_name}.fwl" ]; then
    echo "No world files found locally, checking if backups exist"
    BACKUPS=$(aws s3api head-object --bucket "$${BUCKET}" --key "${world_name}.fwl" 2>/dev/null || true)
    if [ -z "$${BACKUPS}" ]; then
        echo "No backups found using world name \"${world_name}\". A new world will be created."
    else
        echo "Backups found, restoring..."
        mkdir -p "$${CONFIG_DIR}/worlds_local"
        aws s3 cp "s3://$${BUCKET}/${world_name}.fwl" "$${CONFIG_DIR}/worlds_local/${world_name}.fwl"
        aws s3 cp "s3://$${BUCKET}/${world_name}.db"  "$${CONFIG_DIR}/worlds_local/${world_name}.db"
    fi
fi

# ── Sync admin list from S3 ─────────────────────────────────────────────────
echo "Syncing admin list"
mkdir -p "$${CONFIG_DIR}"
aws s3 cp "s3://$${BUCKET}/adminlist.txt" "$${CONFIG_DIR}/adminlist.txt"

# ── Sync custom BepInEx mods from S3 ────────────────────────────────────────
%{ if enable_bepinex ~}
echo "Syncing BepInEx mods from S3..."
aws s3 sync "s3://$${BUCKET}/bepinex/plugins/" "$${VALHEIM_DIR}/BepInEx/plugins/" 2>/dev/null || echo "No plugins found in S3, skipping."
aws s3 sync "s3://$${BUCKET}/bepinex/config/"  "$${VALHEIM_DIR}/BepInEx/config/"  2>/dev/null || echo "No config found in S3, skipping."
%{ endif ~}

# ── Export environment variables for start_valheim.sh ────────────────────────
export SERVER_NAME="${server_name}"
export WORLD_NAME="${world_name}"
export SERVER_PASSWORD="${server_password}"
export SERVER_PORT="${server_port}"
export BEPINEX_ENABLED="${enable_bepinex}"
export BEPINEX_VERSION="${bepinex_version}"
export ENABLE_CROSSPLAY="${enable_crossplay}"

# ── Launch the server ────────────────────────────────────────────────────────
exec bash "$${VALHEIM_DIR}/start_valheim.sh"
