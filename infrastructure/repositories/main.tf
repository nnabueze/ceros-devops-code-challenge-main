/******************************************************************************
* ECR
*
* Create the repo and initialize it with our docker image first.  Just push the
* image to "latest" to start with.
*
********************************************************************************/

/**
* The ECR repository we'll push our images to.
*/
resource "aws_ecr_repository" "ceros_ski" {
  name = var.ecr_name
  image_tag_mutability = "MUTABLE"
}

/**
* Build docker image and push to ECR
*/
resource "docker_registry_image" "ceros_ski_img" {
  name = "${aws_ecr_repository.ceros_ski.repository_url}:latest"
  build {
    context = "../../app"
    dockerfile = "Dockerfile"
  }
}

/**
Create aws s3 bucket for terraform state
*/

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.s3_bucket_name

  lifecycle {
    prevent_destroy = true
  }
  
}