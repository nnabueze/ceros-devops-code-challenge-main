################################
# Security Group
###############################
# Security group for bastion host alowing port 22
# For test purpose port 22 is open for all IP

resource "aws_security_group" "bastion-sg" {
  name   = "${var.app_name}-bastion-sg"
  vpc_id = aws_vpc.main-vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# A security group for the instances in the autoscaling group allowing HTTP 
# ingress.  With out this the Target Group won't be able to reach the instances
# (and thus the containers) and the health checks will fail, causing the
# instances to be deregistered.
resource "aws_security_group" "sg-scaling-ecs-cluster" {
  name        = "${var.app_name}-sg-scaling-ecs-cluster"
  description = "Security Group for the Autoscaling group which provides the instances for the ECS Cluster."
  vpc_id      = aws_vpc.main-vpc.id

  # Inbound rule HTTP access from anywhere
  ingress {
    description = "HTTP Ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound rule HTTP access from anywhere
  ingress {
    description = "HTTP Ingress"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # port for ecs agent to download docker
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Application = var.app_name
    Environment = var.app_environment
    Resource    = "modules.ecs.cluster.aws_security_group.autoscaling_group"
  }
}

# security group for application load balance port 22 is open for testing
# purpose
resource "aws_security_group" "sg-alb" {
  name        = "${var.app_name}-sg-alb"
  description = "security group for application load balance"
  vpc_id      = aws_vpc.main-vpc.id

  # Inbound Rules
  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Rules
  # Internet access to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

