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

variable "environment" {
  type = string
  description = "The name of the environment we'd like to launch."
  default = "production"
}

variable "repository_url" {
  type = string
  default = "480891119046.dkr.ecr.eu-central-1.amazonaws.com/ceros-ski"
  description = "The url of the ECR repository we'll draw our images from."
}

variable "public_key_path" {
  type = string
  default = "/root/.ssh/id_rsa.pub"
  description = "The public key that will be used to allow ssh access to the bastions."
  sensitive = true
}

variable "ecs-iam-role" {
  type = string
  default = "ceros-ski-ecs-agent"
  description = "The IAM role that will be used by the instances "
}

variable "app_name" {
  type = string
  default = "ceros-ski"
  description = "Application name"
}
