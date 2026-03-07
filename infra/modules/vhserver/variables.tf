variable "aws_region" { type = string }
variable "domain" { type = string }
variable "instance_type" { type = string }
variable "sns_email" { type = string }
variable "world_name" { type = string }
variable "server_name" { type = string }
variable "server_password" { type = string }
variable "stage" { type = string }
variable "unique_id" { type = string }
variable "ec2_keypair_name" { type = string }
variable "initial_world_name" { type = string }
variable "initial_world_path" { type = string }
variable "admins" { type = map(any) }

variable "tags" {
  description = "A map of tags to apply to contained resources."
  type        = map(string)
  default     = {}
}

variable "ec2_tags" {
  description = "A map of tags to apply to EC2 resources."
  type        = map(string)
  default     = {}
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

locals {
  iam_path = "/vh/server/"
  username = "vhserver"
  name = "valheim-${var.stage}-${var.unique_id}"
}
