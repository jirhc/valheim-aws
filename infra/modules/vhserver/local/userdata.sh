#!/bin/bash
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

aws s3 cp s3://${bucket}/install_valheim.sh /home/${username}/valheim/install_valheim.sh
aws s3 cp s3://${bucket}/bootstrap_valheim.sh /home/${username}/valheim/bootstrap_valheim.sh
aws s3 cp s3://${bucket}/valheim.service /home/${username}/valheim/valheim.service
%{ if enable_bepinex ~}
aws s3 cp s3://${bucket}/install_bepinex.sh /home/${username}/valheim/install_bepinex.sh
chmod +x /home/${username}/valheim/install_bepinex.sh
chown ${username}:${username} /home/${username}/valheim/install_bepinex.sh
%{ endif ~}

chmod +x /home/${username}/valheim/install_valheim.sh
chmod +x /home/${username}/valheim/bootstrap_valheim.sh

chown ${username}:${username} /home/${username}/valheim/install_valheim.sh
chown ${username}:${username} /home/${username}/valheim/bootstrap_valheim.sh
chown ${username}:${username} /home/${username}/valheim/valheim.service

cp /home/${username}/valheim/valheim.service /etc/systemd/system

su - ${username} -c "bash /home/${username}/valheim/install_valheim.sh"

systemctl daemon-reload
systemctl enable valheim.service
systemctl restart valheim
