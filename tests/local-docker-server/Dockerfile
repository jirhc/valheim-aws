# ─────────────────────────────────────────────────────────────────────────────
# Valheim Dedicated Server — Ubuntu 24.04 LTS (matches AWS EC2 AMI)
# ─────────────────────────────────────────────────────────────────────────────
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# ── OS-level dependencies required by SteamCMD & Valheim ────────────────────
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        lib32gcc-s1 \
        lib32stdc++6 \
        libpulse0 \
        libsdl2-2.0-0:i386 \
        unzip \
        jq \
    && rm -rf /var/lib/apt/lists/*

# ── Create a non-root user to run the server ────────────────────────────────
ARG STEAM_USER=steam
RUN useradd -m -s /bin/bash ${STEAM_USER}

# ── Copy helper scripts ─────────────────────────────────────────────────────
#   install_valheim.sh and start_valheim.sh are shared with the main project.
#   entrypoint.sh is Docker-specific.
COPY --chown=${STEAM_USER}:${STEAM_USER} infra/modules/vhserver/local/install_valheim.sh  /home/${STEAM_USER}/install_valheim.sh
COPY --chown=${STEAM_USER}:${STEAM_USER} infra/modules/vhserver/local/start_valheim.sh    /home/${STEAM_USER}/start_valheim.sh
COPY --chown=${STEAM_USER}:${STEAM_USER} tests/local-docker-server/scripts/entrypoint.sh  /home/${STEAM_USER}/entrypoint.sh

RUN chmod +x /home/${STEAM_USER}/*.sh

# ── Persistent volumes ──────────────────────────────────────────────────────
#   valheim-server  → game binaries + BepInEx plugins
#   valheim-data    → world saves & config
RUN mkdir -p /home/${STEAM_USER}/valheim \
             /home/${STEAM_USER}/.config/unity3d/IronGate/Valheim \
    && chown -R ${STEAM_USER}:${STEAM_USER} /home/${STEAM_USER}/valheim \
                                            /home/${STEAM_USER}/.config
VOLUME ["/home/${STEAM_USER}/valheim", "/home/${STEAM_USER}/.config/unity3d/IronGate/Valheim"]

# ── Ports ────────────────────────────────────────────────────────────────────
#   Valheim uses 3 consecutive UDP ports starting from SERVER_PORT
EXPOSE 2456/udp 2457/udp 2458/udp

# ── Run as non-root ─────────────────────────────────────────────────────────
USER ${STEAM_USER}
WORKDIR /home/${STEAM_USER}

ENTRYPOINT ["/home/steam/entrypoint.sh"]
