# valheim-aws

This project allows the configuration of an AWS infrastructure to support a Valheim dedicated server controlled by a Discord bot.

**Features:**

- Automatic Valheim server configuration, update and backups.
- Use an already existing Valheim world.
- Automatically stop the server if nobody is connected after ~15 minutes (can save loads of money).
- Send a notification by mail when the server goes down.
- Discord bot `/vh` to control the Valheim server (`status`, `start`, `stop`).
- Elastic IP gives the server a **static address** that never changes — the Discord bot always shows the same IP.
- Optional **crossplay** support (Steam + Xbox Game Pass).
- Optional **BepInEx** mod loader with S3-based mod management.
- Optional **DynamoDB state locking** for safe team/CI usage ([details](doc/state-locking.md)).

## Requirements

- AWS account including CLI configured on the machine environment.
- Terraform v1.6.0+
- Python 3.12+ (**only version 3.12+ is supported due to AWS Lambda function limitation**)

> **_Note:_** The project comes with a pre-configured vscode dev container including all the needed dependencies.

## Usage

1. Configure the AWS cli with the required credentials.
2. Create a Terraform backend S3 bucket to store your state files.
3. In the `infra/deploy/config` folder, create the following configuration files:

```text
valheim-aws               // (base project)
└── infra/deploy/config   // (custom config)
    ├── backend.tf        // (create me, example below)
    └── variables.tfvars  // (create me, example below)
```

Define the backend settings in `backend.tf` like the following example:

```hcl
# bucket to store the server data
bucket = "<your bucket name (see usage 1)>"
# store the terraform state in S3
key    = "valheim-server/prod/terraform.tfstate"
# define a region to store the infrastructure (the closest to the players the better)
region = "eu-west-3"
# enable state locking (optional but recommended) — see doc/state-locking.md
# dynamodb_table = "terraform-state-lock"
```

Define the infrastructure settings in `variables.tfvars` like the following example:

```hcl
# Deployment
stage = "dev"

# AWS settings
account_id       = "<AWS account id>"
aws_region       = "eu-west-3"          # Choose a region closest to your physical location
sns_email        = "your_mail@mail.com" # Alerts go here e.g. server started, server stopped

# Valheim server
world_name          = "<name of your Valheim world>"
server_name         = "<name of your Valheim server>"
server_password     = "password"
ec2_keypair_name    = "<EC2 keypair name>"  # For debug purpose
initial_world_name  = "<name of your Valheim world to use as startup>"  # Optional, if set must be equal to 'world_name'
admins = {
  "bob"   = 76561197993928955 # Create an AWS user for remote management and make Valheim admin using SteamID
  "jane"  = 76561197994340319
  "sally" = ""                # Create an AWS user for remote management but don't make Valheim admin
}
instance_type       = "t3a.medium"   # "t3a.medium" seems to be the minimum config

# Optional features
enable_bepinex   = false  # Set to true to install BepInEx mod loader
enable_crossplay = false  # Set to true for Steam + Xbox crossplay

# Discord secrets
discord_public_key     = "<Discord public key of the bot>"
discord_auth_token     = "<Discord auth token>"
discord_application_id = "<Discord bot application id>"
```

4. Execute the script `scripts/register-all-commands.sh` to register the Discord bot commands in the Discord environment. You must create an `.env` file in the `scripts` folder to define some environment variables **before** executing the script:

```env
DISCORD_APPLICATION_ID=
DISCORD_GUILD_ID=
DISCORD_BOT_TOKEN=
```

### How to use a pre existing world

1. In the `infra/deploy/config` folder, add the existing Valheim world files:

```txt
valheim-aws                 // (base project)
└── infra/deploy/config     // (custom config)
    └── world               // (custom world)
        ├── <myworld>.fwl   // (create me, example below)
        └── <myworld>.db    // (create me, example below)
```

2. In the `.tfvars` file, assign the world name to the var `initial_world_name`.

> **_WARNING:_** Due to the world being modified while playing the game, the configuration becomes non-idempotent. That means that each time you re-apply the terraform configuration, the Valheim world will be overwritten with the one in the `world` folder. **Thus, it is highly recommended to remove the `initial_world_name` variable definition from the `variables.tfvars` file after having successfully applied the configuration for the first time.**

### How to enable crossplay

To allow players on Xbox Game Pass / Microsoft Store to join alongside Steam players, set the following in your `variables.tfvars`:

```hcl
enable_crossplay = true
```

When crossplay is enabled the server starts with the `-crossplay` flag and removes the `-public 1` option. Steam-only server listing is disabled in crossplay mode; players connect by IP instead.

> **_WARNING:_** The **ServerSideMap** mod is incompatible with crossplay/PlayFab. Do not enable both `enable_crossplay` and `enable_bepinex` if you rely on ServerSideMap.

### How to enable BepInEx (mod support)

To install the [BepInEx](https://github.com/BepInEx/BepInEx) mod loader on the dedicated server, set the following variable in your `variables.tfvars`:

```hcl
enable_bepinex = true
```

This will automatically download and configure BepInEx 5.4.x on the server at startup. BepInEx is reinstalled on every server restart to survive Valheim updates.

#### Included mods

The following mods are downloaded automatically from [Thunderstore](https://thunderstore.io/c/valheim/) when BepInEx is enabled:

| Mod | Version | Description |
|---|---|---|
| [FuelEternal](https://thunderstore.io/c/valheim/p/Marf/FuelEternal/) | 1.2.1 | Sets fuel sources to their maximum automatically (torches, campfires, ovens, etc.) |
| [ServerSideMap](https://thunderstore.io/c/valheim/p/Mydayyy/ServerSideMap/) | 1.3.13 | Shares explored map and markers between all players on the server |

ServerSideMap is pre-configured with both **map sharing** and **marker sharing** enabled. The config file is created at `BepInEx/config/eu.mydayyy.plugins.serversidemap.cfg` on first install and can be customised via S3 (see below).

> **_Note:_** ServerSideMap requires the mod on **both server and client**. Players must install it locally as well.

#### Managing mods via S3

Mods are synced from S3 during each server boot. Upload your mods to these prefixes in the Valheim S3 bucket:

```text
s3://<your-bucket>/bepinex/plugins/   ← plugin DLLs
s3://<your-bucket>/bepinex/config/    ← config files
```

The sync is additive — existing files on the server are preserved unless overwritten by a newer S3 version.

### Monitoring

To view server monitoring metrics visit the `monitoring_url` output from Terraform after deploying. Because the server uses an Elastic IP, this URL stays the same across restarts.

### Timings

- It usually takes around 1 minute for Terraform to deploy all the components.
- Upon the first deployment the server will take 5-10 minutes to become ready.
- Subsequent starts will take 2-3 minutes before appearing on the server browser.

### Backups

The server logic around backups is as follows:

1. Check if world files exist locally and if so start the server using those.
2. If no files exist, try to fetch from backup store and use those.
3. If no backup files exist, create a new world and start the server.
4. Five minutes after the server has started perform a backup.
5. Perform backups every hour after boot.

## How it works

The AWS architecture and the terraform modules:

![AWS Architecture](./doc/architecture.png "AWS Architecture")

### Networking

The server runs on an EC2 instance with **spot pricing** (via `instance_market_options`) to keep costs low. An **Elastic IP** is attached so the address stays constant across stop/start cycles — no need for players to look up a new IP each time.

If a custom `domain` is provided, Terraform creates a Route 53 **A record** pointing to the Elastic IP.

### Discord bot

An **HTTP API Gateway** (v2) receives Discord interaction webhooks and forwards them to two Lambda functions:

- **interaction** provides the ACK through the API Gateway in less than 3 seconds as requested by the Discord specification. It then forwards the initial Discord request to the second Lambda (`vhserver`) through an SNS topic for asynchronous execution.
- **vhserver** is called by SNS and processes the initial request received from the related topic. The Lambda then answers directly to the Discord client referring to the initial command token.

Both Lambdas use [AWS Lambda Powertools](https://docs.powertools.aws.dev/lambda/python/latest/) for structured JSON logging.

This architecture follows the good practice of decoupling the 2 Lambdas to limit their dependency, and so their respective execution time (cost optimization). This is possible since we do not need synchronous execution between the two.

## Infrastructure cost

The server is hosted on an EC2 spot instance. The main advantage is the significant cost saving (typically 60-70% compared to on-demand).

Key cost components:

| Resource | Cost |
|---|---|
| EC2 spot (t3a.medium, running) | ~$0.012/hr (~$8.50/month if 24/7) |
| Elastic IP (while instance is running) | Free |
| Elastic IP (while instance is stopped) | ~$0.005/hr (~$3.65/month) |
| HTTP API Gateway | $1.00 per million requests |
| Lambda | Included in free tier for typical usage |
| S3 | < $1/month for world files |
| SNS | Free tier |

> **_Tip:_** The auto-stop feature (stops the server after ~15 min of inactivity) keeps the running costs very low. The Elastic IP idle cost is the main charge when the server is off.

## Credits

The `vhserver` module is based on the solution from [wahlfeld/valheim-on-aws](https://github.com/wahlfeld/valheim-on-aws/).
