###############################################################################
# SNS interaction

data "aws_iam_policy_document" "lambda_sns_subscribe" {
  statement {
    effect = "Allow"
    actions   = ["sns:Subscribe", "sns:GetTopicAttributes", "sns:ListTopics"]
    resources = [ aws_sns_topic.vhserver.arn ]
  }
}

resource "aws_iam_policy" "lambda_sns_subscribe" {
  name        = "lambda-sns-subscribe"
  path        = local.iam_path
  description = "Allows Lambda to subscribe to SNS"
  policy      = data.aws_iam_policy_document.lambda_sns_subscribe.json
}

###############################################################################
# EC2 interaction

data "aws_iam_policy_document" "lambda_ec2_control" {
  statement {
    effect = "Allow"
    actions   = [
      "ec2:DescribeInstances", 
      "ec2:DescribeInstanceStatus", 
      "ec2:StartInstances",
      "ec2:StopInstances"
    ]
    resources = [ "*" ]
  }
}

resource "aws_iam_policy" "lambda_ec2_control" {
  name        = "lambda_ec2_control"
  path        = local.iam_path
  description = "lambda_ec2_control"
  policy      = data.aws_iam_policy_document.lambda_ec2_control.json
}

###############################################################################
# lambda bot - command

variable "lambda_vhserver_name" { 
  type = string 
  default = "lambda-vhserver"
}

locals {
  lambda_vhserver_name_stage = "${var.lambda_vhserver_name}-${var.stage}"
}

module "lambda_vhserver" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = local.lambda_vhserver_name_stage
  description   = "lambda-vhserver"
  handler       = "${var.lambda_vhserver_name}.lambda_handler"
  runtime       = "python3.12"
  publish       = true

  attach_policies = true
  policies = [
    aws_iam_policy.lambda_sns_subscribe.arn,
    aws_iam_policy.lambda_ec2_control.arn,
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
  number_of_policies = 3

  source_path = "${path.module}/${var.lambda_vhserver_name}"

  # store_on_s3 = true
  # s3_bucket   = "my-bucket-id-with-lambda-builds"

  layers = [
    module.lambda_common_layer.lambda_layer_arn,
  ]

  environment_variables = {
    DISCORD_PUBLIC_KEY      = var.discord_public_key
    DISCORD_AUTH_TOKEN      = var.discord_auth_token
    DISCORD_APP_ID          = var.discord_application_id
    SERVER_INSTANCE_ID      = var.vhserver_instance_id
    POWERTOOLS_SERVICE_NAME = "discord-vhserver"
    POWERTOOLS_LOG_LEVEL    = "INFO"
  }

  allowed_triggers = {
    SNSTopic = {
        service = "sns"
        source_arn = aws_sns_topic.vhserver.arn
    }
  }

  # Timeout in seconds. 
  timeout = 300

  tags = var.tags
}

