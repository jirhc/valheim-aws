#!/bin/bash
set -e

echo "Syncing startup script"

aws s3 cp s3://${bucket}/start_valheim.sh /home/${username}/valheim/start_valheim.sh
chmod +x /home/${username}/valheim/start_valheim.sh

%{ if enable_bepinex ~}
echo "Installing BepInEx mod loader"
aws s3 cp s3://${bucket}/install_bepinex.sh /home/${username}/valheim/install_bepinex.sh
chmod +x /home/${username}/valheim/install_bepinex.sh
bash /home/${username}/valheim/install_bepinex.sh
%{ endif ~}

bash /home/${username}/valheim/start_valheim.sh
