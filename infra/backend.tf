terraform {
  required_version = ">= 1.9.0"

  backend "s3" {
    bucket       = "chu-statefile"
    key          = "ecs-microservices/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true # S3-native state locking (no DynamoDB table needed)
  }
}
