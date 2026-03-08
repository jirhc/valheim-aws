# Deployment Guide

Complete step-by-step guide to deploy the Valheim dedicated server on AWS with Discord bot integration.

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| AWS CLI | v2+ | `aws --version` |
| Terraform | v1.6.0+ | `terraform --version` |
| Python | 3.12+ | `python3 --version` |

> **Tip:** The project includes a VS Code dev container with all dependencies pre-installed. Open the project in VS Code and select **Reopen in Container**.

---

## Part 1 — AWS Setup

### Step 1: Configure AWS credentials

Set up the AWS CLI with an IAM user that has **AdministratorAccess** (or at minimum: EC2, S3, Lambda, API Gateway, SNS, IAM, CloudWatch permissions).

```bash
aws configure
# AWS Access Key ID: <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region name: eu-west-3          # or your preferred region
# Default output format: json
```

Verify access:

```bash
aws sts get-caller-identity
```

### Step 2: Create an S3 bucket for Terraform state

This bucket stores the Terraform state file remotely.

```bash
aws s3api create-bucket \
  --bucket my-valheim-terraform-state \
  --region eu-west-3 \
  --create-bucket-configuration LocationConstraint=eu-west-3
```

Enable versioning (recommended):

```bash
aws s3api put-bucket-versioning \
  --bucket my-valheim-terraform-state \
  --versioning-configuration Status=Enabled
```

> Replace `my-valheim-terraform-state` with a globally unique bucket name.

### Step 3: Create an EC2 key pair

This allows SSH access to the server for debugging.

```bash
aws ec2 create-key-pair \
  --key-name valheim-keypair \
  --query 'KeyMaterial' \
  --output text \
  --region eu-west-3 > valheim-keypair.pem

chmod 400 valheim-keypair.pem
```

Keep `valheim-keypair.pem` safe — you'll need it if you ever need to SSH into the server.

---

## Part 2 — Discord Bot Setup

### Step 4: Create a Discord application

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications).
2. Click **New Application** → name it (e.g. "Valheim Bot") → **Create**.
3. On the **General Information** page, note down:
   - **Application ID** → `discord_application_id`
   - **Public Key** → `discord_public_key`

### Step 5: Create the bot user

1. In the left sidebar, click **Bot**.
2. Click **Reset Token** → copy the token → `discord_auth_token`

   > **WARNING:** This token is shown only once. Save it immediately.

3. Under **Privileged Gateway Intents**, no special intents are needed (the bot uses slash commands only).

### Step 6: Invite the bot to your server

1. In the left sidebar, click **OAuth2**.
2. Under **OAuth2 URL Generator**, select the scope: `applications.commands`.
3. Copy the generated URL and open it in your browser.
4. Select your Discord server and authorize the bot.

### Step 7: Get your Discord Guild (Server) ID

1. In Discord, go to **User Settings → Advanced** → enable **Developer Mode**.
2. Right-click your server name in the sidebar → **Copy Server ID**.
3. This is your `DISCORD_GUILD_ID`.

---

## Part 3 — Configuration

### Step 8: Edit the Terraform configuration

Open `infra/deploy/config/variables.tfvars` and fill in **all** blank values:

```hcl
# -- AWS Settings --
account_id = "123456789012"                       # your 12-digit AWS account ID
aws_region = "eu-west-3"                          # must match backend.tf
sns_email  = "you@example.com"                    # alert notifications

# -- Valheim Server --
world_name       = "MyWorld"
server_name      = "My Valheim Server"
server_password  = "s3cretP@ss"                   # min 5 chars, must NOT contain server_name
ec2_keypair_name = "valheim-keypair"               # from Step 3

# -- Discord Bot --
discord_public_key     = "<from Step 4>"
discord_application_id = "<from Step 4>"
discord_auth_token     = "<from Step 5>"
```

### Step 9: Edit the backend configuration

Open `infra/deploy/config/backend.tf` and update the bucket name to match the one created in Step 2:

```hcl
bucket = "my-valheim-terraform-state"
region = "eu-west-3"
```

### Step 10: (Optional) Import an existing world

If you have an existing Valheim world:

1. Copy your `.fwl` and `.db` world files into `infra/deploy/config/world/`.
2. Uncomment `initial_world_name` in `variables.tfvars` and set it to your world name.

> **IMPORTANT:** After the first successful `terraform apply`, remove the `initial_world_name` line to prevent overwriting your world on future deployments.

---

## Part 4 — Deploy

### Step 11: Initialize Terraform

```bash
./run-tf.sh init
```

This downloads the required providers and configures the S3 backend.

### Step 12: Review the plan

```bash
./run-tf.sh plan
```

Review the resources that will be created. You should see EC2 instances, security groups, S3 buckets, Lambda functions, API Gateway, SNS topics, etc.

### Step 13: Apply the infrastructure

```bash
./run-tf.sh apply
```

Type `yes` when prompted. Deployment takes about 1 minute.

> **First boot:** The EC2 instance will take 5–10 minutes to download and install the Valheim dedicated server. Subsequent starts take 2–3 minutes.

### Step 14: Note the outputs

After `apply` completes, Terraform will print outputs including:
- The **API Gateway endpoint URL** — needed for the Discord bot webhook.
- The **Elastic IP** — the static IP address players connect to.
- The **monitoring URL** — CloudWatch dashboard link.

---

## Part 5 — Connect the Discord Bot

### Step 15: Set the Interactions Endpoint URL

1. Go back to the [Discord Developer Portal](https://discord.com/developers/applications) → your application.
2. Click **General Information**.
3. In the **Interactions Endpoint URL** field, paste the API Gateway URL from the Terraform output (it looks like `https://xxxxxxxxxx.execute-api.<region>.amazonaws.com/<stage>/event`).
4. Click **Save Changes**.

> Discord will send a validation ping to your endpoint. If it fails, double-check the URL and that the Lambda is deployed correctly.

### Step 16: Register the slash commands

```bash
cd scripts

# Edit the .env file with your Discord credentials
# DISCORD_APPLICATION_ID=<from Step 4>
# DISCORD_GUILD_ID=<from Step 7>
# DISCORD_BOT_TOKEN=<from Step 5>

./register-all-commands.sh
```

This registers the `/vh` slash command in your Discord server.

### Step 17: Test the bot

In your Discord server, type:

```
/vh status
```

The bot should respond with the current server status. Use `/vh start` and `/vh stop` to control the server.

---

## Post-Deployment

### Confirm SNS subscription

After the first deploy, AWS sends a confirmation email to the `sns_email` address. **Click the confirmation link** in that email to start receiving server alerts.

### Connecting to the Valheim server

1. Open Valheim → **Join Game** → **Add Server**.
2. Enter the Elastic IP from the Terraform output with port `2456` (e.g. `1.2.3.4:2456`).
3. If crossplay is enabled, connect via **Join by IP** instead of the server browser.

### Managing the infrastructure

```bash
# Check current state
./run-tf.sh plan

# Apply changes (e.g. after editing variables.tfvars)
./run-tf.sh apply

# Tear down everything (stops billing)
./run-tf.sh destroy
```

### SSH into the server (debugging)

```bash
ssh -i valheim-keypair.pem ubuntu@<elastic-ip>

# View server logs
journalctl -u valheim -f

# Check server status
systemctl status valheim
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Discord bot doesn't respond | Check the Interactions Endpoint URL in the Developer Portal. Verify the API Gateway URL is correct. |
| "Interaction failed" in Discord | Check Lambda logs in CloudWatch. The `interaction` Lambda must ACK within 3 seconds. |
| Server takes too long to start | First boot downloads ~1 GB of game files. Wait 5–10 minutes. Check `/var/log/cloud-init-output.log` via SSH. |
| Can't connect to the game server | Ensure the security group allows UDP ports 2456-2458. Check the server is running with `/vh status`. |
| `terraform init` fails | Verify the S3 bucket exists and AWS credentials have permission to access it. |
| SNS emails not arriving | Check your spam folder. Click the confirmation link in the initial subscription email. |
| World data lost after redeploy | Remove `initial_world_name` from `variables.tfvars` after the first deploy. |
