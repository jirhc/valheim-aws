# environment

variable "stage" { type = string }

# aws variables

variable "aws_region" { type = string }
variable "account_id" { type = string }

# vhserver variables

variable "domain" { type = string }
variable "instance_type" { type = string }
variable "sns_email" { type = string }
variable "world_name" { type = string }
variable "server_name" { type = string }
variable "server_password" { type = string }
variable "ec2_keypair_name" { type = string }
variable "initial_world_name" { type = string }
variable "initial_world_path" { type = string }
variable "admins" { type = map(any) }
variable "enable_bepinex" { type = bool }
variable "enable_crossplay" { type = bool }

# discordbot variables

variable "discord_public_key" { type = string }
variable "discord_auth_token" { type = string }
variable "discord_application_id" { type = string }

# global variables

resource "time_static" "activation_date" {}

locals {
  # create a unique id based on the unix datetime
  unique_id = time_static.activation_date.unix
  # set a global name
  name = "valheim-${var.stage}-${local.unique_id}"
  # common tags
  tags = {
    "project"    = local.name
    "stage"      = var.stage
    "created_by" = "Terraform"
  }
  # EC2 specific tags
  ec2_tags = {
    "name"        = "${local.name}-server"
    "description" = "Instance running a Valheim server"
  }
}
