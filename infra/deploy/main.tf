module "service" {
  source                  = "../modules/service"

  # global
  stage                   = var.stage

  # AWS
  account_id              = var.account_id
  aws_region              = var.aws_region

  # vhserver
  domain                  = var.domain
  instance_type           = var.instance_type
  server_name             = var.server_name
  server_password         = var.server_password
  sns_email               = var.sns_email
  world_name              = var.world_name
  ec2_keypair_name        = var.ec2_keypair_name
  initial_world_name      = var.initial_world_name
  initial_world_path      = "${path.root}/config/world"
  admins                  = var.admins

  # mods
  enable_bepinex          = var.enable_bepinex
  enable_crossplay        = var.enable_crossplay

  # discord bot
  discord_public_key      = var.discord_public_key
  discord_auth_token      = var.discord_auth_token
  discord_application_id  = var.discord_application_id
}
