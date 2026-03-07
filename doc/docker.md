# Docker image specification

## Image construction

Image dependencies:

- go
- terraform
- tflint
- shellcheck
- tfsec
- terraform-docs
- checkov

## Volumes

- AWS file credentials
- logs
- "config" folder (including terraform.tfvars, backend-config.tf)
- "world" folder with initial world (optional)

## Environment variables

- STAGE
