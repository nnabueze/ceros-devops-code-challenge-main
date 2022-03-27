variable "aws_credentials_file" {
  type = string
  default = "/root/.aws/credentials"
  description = "The file that contains the AWS credentials we will use."
}

variable "aws_profile" {
  type = string
  default = "default"
  description = "The name of the AWS credentials profile we will use."
}

variable "aws_region" {
  type = string
  default = "eu-central-1"
  description = "The name of the AWS Region we'll launch into."
}

variable "ecr_name" {
  type = string
  default = "ceros-ski"
}


