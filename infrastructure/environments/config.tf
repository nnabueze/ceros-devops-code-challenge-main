terraform {
  required_version = ">= 0.14.4"

  backend "s3" {
    bucket = "terraform-state-ceros-ski"
    key = "global/repository/terraform.tfstate"
    region = "eu-central-1"
    profile = "default"
  }
}