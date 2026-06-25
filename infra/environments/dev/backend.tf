terraform {
  required_version = ">= 1.9.0"

  backend "s3" {
    bucket       = "chu-statefile"
    key          = "ecs-microservices/dev/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
