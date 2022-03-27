provider "aws" {
  region = var.aws_region 
  shared_credentials_files = [var.aws_credentials_file]
  profile = var.aws_profile 
}

/**
Retrieve authorization token and Loin to ECR 
*/
provider "docker" {
  registry_auth {
    address  = local.aws_ecr_url
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}