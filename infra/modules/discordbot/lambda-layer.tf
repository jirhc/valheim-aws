###############################################################################
# lambda bot - layers

variable "discord_layer_working_dir" {
  type = string
  default = "build-discordbot"
}

## Generate the layer
resource "null_resource" "discord_lambda_layer_generate" {
 provisioner "local-exec" {
    command = "${path.module}/scripts/generate-layer.sh"
    interpreter = [
      "/bin/sh"
    ]
    working_dir = path.root
    environment = {
      DISCORD_LAYER_WORKING_DIR = var.discord_layer_working_dir
     }
  }

  triggers = {
    policy_sha1 = "${sha1(file("${path.module}/scripts/generate-layer.sh"))}"
  }
}

## Package and deploy the layer
module "lambda_common_layer" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  create_layer = true

  layer_name               = "lambda-common-layer"
  description              = "lambda layer (deployed for discord bot)"
  compatible_runtimes      = ["python3.12"]
  # compatible_architectures = ["arm64"]

  source_path = "${path.root}/${var.discord_layer_working_dir}"

  depends_on = [
    null_resource.discord_lambda_layer_generate
  ]
}
