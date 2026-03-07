# Deployment variables ------------------------------------------------------------

variable "stage" {
  type = string
  default = "dev"
  description = "Deployment stage name"
}

# AWS variables ------------------------------------------------------------

variable "account_id" {
  type = string
  default = ""
  description = "The AWS account id"
  sensitive = true
}

variable "aws_region" {
  type        = string
  description = "The AWS region to create the Valheim server"
}

# Valheim server variables ----------------------------------------------------

variable "admins" {
  type        = map(any)
  default     = { "default_valheim_user" = "", }
  description = "List of AWS users/Valheim server admins (use their SteamID)"
}

variable "domain" {
  type        = string
  default     = ""
  description = "Domain name used to create a static monitoring URL"
}

variable "keybase_username" {
  type        = string
  default     = "marypoppins"
  description = "The Keybase username to encrypt AWS user passwords with"
}

variable "instance_type" {
  type        = string
  default     = "t3a.medium"
  description = "AWS EC2 instance type to run the server on (t3a.medium is the minimum size)"
}

variable "sns_email" {
  type        = string
  description = "The email address to send alerts to"
}

variable "world_name" {
  type        = string
  description = "The Valheim world name"
}

variable "server_name" {
  type        = string
  description = "The server name"
}

variable "server_password" {
  type        = string
  description = "The server password"
}

variable "unique_id" {
  type        = string
  default     = ""
  description = "The ID of the deployment (used for tests)"
}

variable "ec2_keypair_name" {
  type        = string
  default     = ""
  description = "The key pair name associated to the EC2 isntance"
}

variable "initial_world_name" {
  type        = string
  default     = ""
  description = "The name of the initial world to be used by the server"
}

variable "initial_world_path" {
  type        = string
  default     = ""
  description = "The path to the initial world to be used by the server"
}

variable "enable_bepinex" {
  type        = bool
  default     = false
  description = "Enable BepInEx mod loader for the Valheim server"
}

variable "enable_crossplay" {
  type        = bool
  default     = false
  description = "Enable crossplay support (Steam + Xbox Game Pass)"
}

# discord bot variables -------------------------------------------------------

variable "discord_public_key" { 
  type = string 
  default     = ""
  description = "The Discord bot public key"
  sensitive   = true
}

variable "discord_auth_token" { 
  type = string 
  default     = ""
  description = "The Discord bot auth token"
  sensitive   = true
}

variable "discord_application_id" { 
  type = string 
  default     = ""
  description = "The Discord bot application ID"
  sensitive   = true
}
