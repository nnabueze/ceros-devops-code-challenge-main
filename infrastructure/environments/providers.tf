provider "aws" {
  region              = var.aws_region
  shared_config_files = [var.aws_secret_file]
  profile             = var.aws_profile
}