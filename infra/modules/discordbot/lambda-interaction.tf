###############################################################################
# SNS interaction

data "aws_iam_policy_document" "lambda_sns_publish" {
  statement {
    effect = "Allow"
    actions   = ["sns:Publish", "sns:GetTopicAttributes", "sns:ListTopics"]
    resources = [ aws_sns_topic.vhserver.arn ]
  }
}

resource "aws_iam_policy" "lambda_sns_publish" {
  name        = "lambda-sns-publish"
  path        = local.iam_path
  description = "Allows Lambda to publish to SNS"
  policy      = data.aws_iam_policy_document.lambda_sns_publish.json
}

###############################################################################
# lambda bot - interaction

# Define the base name
variable "lambda_interaction_name" { 
  type = string 
  default = "lambda-interaction"
}

# Append the name with the stage name
locals {
  lambda_interaction_name_stage = "${var.lambda_interaction_name}-${var.stage}"
}

# Define the lambda function
module "lambda_interaction" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = local.lambda_interaction_name_stage
  description   = "lambda-bot-interaction"
  handler       = "${var.lambda_interaction_name}.lambda_handler"
  runtime       = "python3.12"
  publish       = true

  attach_policies = true
  policies = [
    aws_iam_policy.lambda_sns_publish.arn,
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
  number_of_policies = 2

  source_path = "${path.module}/${var.lambda_interaction_name}"

  # store_on_s3 = true
  # s3_bucket   = "my-bucket-id-with-lambda-builds"

  layers = [
    module.lambda_common_layer.lambda_layer_arn,
  ]

  environment_variables = {
    DISCORD_PUBLIC_KEY      = var.discord_public_key
    SNS_PUBLISH_VH_ARN     = aws_sns_topic.vhserver.arn
    POWERTOOLS_SERVICE_NAME = "discord-interaction"
    POWERTOOLS_LOG_LEVEL    = "INFO"
  }

  allowed_triggers = {
    APIGatewayPost = {
      service    = "apigateway"
      source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
    },
  }

  # Timeout in seconds. 
  # Discord allows only 3 seconds to receive the initial answer (can be a ACK)
  timeout = 3
}
