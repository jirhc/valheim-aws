###############################################################################
# HTTP API Gateway (v2) - replaces the legacy REST API Gateway
#
# HTTP APIs are simpler, faster, and ~70% cheaper than REST APIs.
# Discord only needs a single POST /event endpoint with payload passthrough.

resource "aws_apigatewayv2_api" "this" {
  name          = "discord-bot-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token"]
    allow_methods = ["POST", "OPTIONS"]
    allow_origins = ["*"]
  }
}

###############################################################################
# Lambda integration

resource "aws_apigatewayv2_integration" "event" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.lambda_interaction.lambda_function_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "event_post" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /event"
  target    = "integrations/${aws_apigatewayv2_integration.event.id}"
}

###############################################################################
# Stage (auto-deploy)

resource "aws_apigatewayv2_stage" "event" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/discord-bot-api"
  retention_in_days = 14
}

###############################################################################
# Lambda permission — allow API Gateway to invoke the interaction Lambda

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_interaction.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
