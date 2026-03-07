module "vhserver" {
  source = "../vhserver"

  aws_region         = var.aws_region
  domain             = var.domain
  instance_type      = var.instance_type
  stage              = var.stage
  server_name        = var.server_name
  server_password    = var.server_password
  sns_email          = var.sns_email
  unique_id          = local.unique_id
  world_name         = var.world_name
  ec2_keypair_name   = var.ec2_keypair_name
  initial_world_name = var.initial_world_name
  initial_world_path = var.initial_world_path
  admins             = var.admins
  enable_bepinex     = var.enable_bepinex
  enable_crossplay   = var.enable_crossplay
  tags               = local.tags
  ec2_tags           = local.ec2_tags
}

module "discordbot" {
  source = "../discordbot"

  account_id              = var.account_id
  aws_region              = var.aws_region
  discord_public_key      = var.discord_public_key
  discord_auth_token      = var.discord_auth_token
  discord_application_id  = var.discord_application_id
  vhserver_instance_id    = module.vhserver.instance_id
  stage                   = var.stage
  tags                    = local.tags
}
