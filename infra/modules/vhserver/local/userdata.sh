#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# userdata.sh  (EC2 instance initialization — Terraform template)
# Installs OS dependencies, downloads scripts from S3, and bootstraps the
# Valheim server via systemd.
# ─────────────────────────────────────────────────────────────────────────────
set -e

dpkg --add-architecture i386
apt update
apt install -y \
    ca-certificates \
    curl \
    jq \
    lib32gcc-s1 \
    lib32stdc++6 \
    libjson-c-dev \
    libsdl2-2.0-0:i386 \
    libtool \
    unzip \

# Install AWS CLI v2 (apt awscli is outdated v1)
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# Install Netdata monitoring
cd /tmp
curl -s https://get.netdata.cloud/kickstart.sh > kickstart.sh
bash kickstart.sh --dont-wait --no-updates

useradd -m ${username}
su - ${username} -c "mkdir -p /home/${username}/valheim"

# Download scripts from S3
aws s3 cp s3://${bucket}/install_valheim.sh /home/${username}/valheim/install_valheim.sh
aws s3 cp s3://${bucket}/bootstrap_valheim.sh /home/${username}/valheim/bootstrap_valheim.sh
aws s3 cp s3://${bucket}/start_valheim.sh /home/${username}/valheim/start_valheim.sh
aws s3 cp s3://${bucket}/valheim.service /home/${username}/valheim/valheim.service

chmod +x /home/${username}/valheim/install_valheim.sh
chmod +x /home/${username}/valheim/bootstrap_valheim.sh
chmod +x /home/${username}/valheim/start_valheim.sh

chown ${username}:${username} /home/${username}/valheim/install_valheim.sh
chown ${username}:${username} /home/${username}/valheim/bootstrap_valheim.sh
chown ${username}:${username} /home/${username}/valheim/start_valheim.sh
chown ${username}:${username} /home/${username}/valheim/valheim.service

cp /home/${username}/valheim/valheim.service /etc/systemd/system

# Run install as the server user with BepInEx env vars
su - ${username} -c "BEPINEX_ENABLED=${enable_bepinex} BEPINEX_VERSION=${bepinex_version} bash /home/${username}/valheim/install_valheim.sh"

systemctl daemon-reload
systemctl enable valheim.service
systemctl restart valheim
