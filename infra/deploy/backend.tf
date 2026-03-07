terraform {
  required_version = ">= 1.6.0"

  # S3 configuration to be setup in the 'config' folder (sensitive)
  # Supports optional DynamoDB state locking — see doc/state-locking.md
  backend "s3" {}
}
