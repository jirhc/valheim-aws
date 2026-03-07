output "api_gateway_name" {
  description = "API Gateway name"
  value       = aws_apigatewayv2_api.this.name
}

output "discord_interactions_endpoint_url" {
  description = "INTERACTIONS ENDPOINT URL in the Discord Bot configuration"
  value       = "${aws_apigatewayv2_stage.event.invoke_url}/event"
}
