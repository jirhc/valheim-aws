variable "account_id" { type = string }
variable "aws_region" { type = string }
variable "discord_public_key" { type = string }
variable "discord_auth_token" { type = string }
variable "discord_application_id" { type = string }
variable "stage" { type = string }
variable "vhserver_instance_id" { type = string }

variable "tags" {
  description = "A map of tags to apply to contained resources."
  type        = map(string)
  default     = {}
}

locals {
  iam_path = "/vh/discordbot/"
}
