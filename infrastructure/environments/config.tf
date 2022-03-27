provider "aws" {
  region = var.aws_region 
  shared_credentials_files = [var.aws_credentials_file]
  profile = var.aws_profile 
}

terraform {
  required_version = ">= 0.14.4"
}
