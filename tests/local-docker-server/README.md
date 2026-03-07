# Valheim Dedicated Server (Docker)

A self-contained Valheim dedicated server with **BepInEx** mod manager support, running in Docker on Ubuntu 22.04 — the same base image used by AWS EC2 instances.

## Project structure

```
.
├── docker-compose.yml          # Container orchestration
├── Dockerfile                  # Ubuntu 22.04 image build
├── .env.example                # Configuration template
└── scripts/
    ├── entrypoint.sh           # Docker entrypoint (install → start)
    ├── install_valheim.sh      # SteamCMD + Valheim + BepInEx installer
    └── start_valheim.sh        # Server launcher with BepInEx support
```

## Quick start

```bash
# 1. Create your configuration
cp .env.example .env

# 2. Edit server name, password, world name, etc.
nano .env

# 3. Build and start the server
docker compose up -d

# 4. Follow the logs
docker compose logs -f valheim
```

## Configuration

All settings live in the `.env` file. See [.env.example](.env.example) for the full list.

| Variable | Default | Description |
|---|---|---|
| `SERVER_NAME` | `MyValheimServer` | Server name shown in the browser |
| `WORLD_NAME` | `MyWorld` | World / save-file name |
| `SERVER_PASSWORD` | `changeme` | Password (≥ 5 chars, must not contain server name) |
| `SERVER_PUBLIC` | `1` | `1` = listed in server browser, `0` = private |
| `BEPINEX_ENABLED` | `true` | Install and enable BepInEx mod loader |
| `BEPINEX_VERSION` | `5.4.2202` | BepInEx release version |
| `SERVER_PORT` | `2456` | Base UDP port (uses PORT, PORT+1, PORT+2) |

## Included mods

When BepInEx is enabled the following mods are downloaded automatically from [Thunderstore](https://thunderstore.io/c/valheim/) on first install:

| Mod | Version | Description |
|---|---|---|
| [FuelEternal](https://thunderstore.io/c/valheim/p/Marf/FuelEternal/) | 1.2.1 | Sets fuel sources to their maximum automatically (torches, campfires, ovens, etc.) |
| [ServerSideMap](https://thunderstore.io/c/valheim/p/Mydayyy/ServerSideMap/) | 1.3.13 | Shares explored map and markers between all players on the server |

ServerSideMap is pre-configured with both **map sharing** and **marker sharing** enabled. The config file is created at `BepInEx/config/eu.mydayyy.plugins.serversidemap.cfg` on first install.

> **Note:** ServerSideMap requires the mod on **both server and client**. Players must install it locally as well.

## Adding extra BepInEx mods

With BepInEx enabled, drop plugin DLLs into the persistent `valheim-server` volume under `BepInEx/plugins/`:

```bash
# Find the volume mount point
docker volume inspect valheim-server-test_valheim-server --format '{{ .Mountpoint }}'

# Copy a plugin
sudo cp MyMod.dll <mountpoint>/BepInEx/plugins/

# Restart the server to load the new mod
docker compose restart valheim
```

## Persistent data

Two Docker named volumes keep your data across container rebuilds:

| Volume | Path in container | Contents |
|---|---|---|
| `valheim-server` | `/home/steam/valheim` | Game binaries, BepInEx, plugins |
| `valheim-data` | `/home/steam/.config/unity3d/IronGate/Valheim` | World saves, config files |

## Useful commands

```bash
# Stop the server gracefully
docker compose down

# Force update the server (rebuild image + re-run install)
docker compose build --no-cache && docker compose up -d

# Shell into the running container
docker compose exec valheim bash

# Back up world saves
docker compose cp valheim:/home/steam/.config/unity3d/IronGate/Valheim/worlds_local ./backup
```

## Firewall / AWS Security Group

Open the following **UDP** ports on your host or AWS Security Group:

- **2456/udp** — Game traffic
- **2457/udp** — Steam server query
- **2458/udp** — Steam master server

## Requirements

- Docker Engine ≥ 20.10
- Docker Compose v2
- ~2 GB RAM minimum (4 GB recommended)
- ~3 GB disk for the server + mods
