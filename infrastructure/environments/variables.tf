variable "app_name" {
  type        = string
  description = "Application name"
}

variable "aws_region" {
  type        = string
  description = "Aws region for application deployment"
}

variable "aws_secret_file" {
  type        = string
  description = "aws access keys"
}

variable "aws_profile" {
  type        = string
  description = "profile in aws credential file"
}

variable "app_environment" {
  type        = string
  description = "Environment the app is running"
}

variable "public-key-pair" {
  type        = string
  description = "public key pair to ssh into aws instances"
  sensitive   = true
}

variable "bh-instance-type" {
  type    = string
  default = "instance type for bastion host"
}

variable "ecs-policy-arn" {
  default = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

variable "repository_url" {
  type        = string
  description = "ECR respository url"
}

variable "container_port" {
  type        = string
  description = "port the container is exposed"
}