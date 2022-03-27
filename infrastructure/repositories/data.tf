//retrive aws calleridentity from aws
data "aws_caller_identity" "current" {}

//retrieve ecr authorization token
data "aws_ecr_authorization_token" "token" {}