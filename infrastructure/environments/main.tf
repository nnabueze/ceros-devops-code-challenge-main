##############################
# Bastion Host
#############################
# create a key pair to ssh to the bastion host
resource "aws_key_pair" "bh-key-pair" {
  key_name   = "${var.app_name}-bh-key-pair"
  public_key = file(var.public-key-pair)
}

# Lunching a bastion host with the public subnet
resource "aws_instance" "bastion-host" {
  ami           = data.aws_ssm_parameter.ami.value
  key_name      = aws_key_pair.bh-key-pair.key_name
  instance_type = var.bh-instance-type

  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion-sg.id]
  subnet_id                   = aws_subnet.public-subnet[0].id

  tags = local.tags
}




############################################
# ECS
############################################
# Create ECS cluster has no dependence
resource "aws_ecs_cluster" "cluster" {
  name = "${var.app_name}-${var.app_environment}"

  tags = {
    Application = var.app_name
    Environment = var.app_environment
    Resource    = "modules.ecs.cluster.aws_ecs_cluster.cluster"
  }
}

# Create the task definition for the ceros-ski backend, in this case a thin
# wrapper around the container definition.
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.app_name}-${var.app_environment}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  # task_role_arn            = aws_iam_role.ecs_agent.arn

  container_definitions = <<EOF
[
  {
    "name": "${var.app_name}-container",
    "image": "${var.repository_url}:latest",
    "environment": [],
    "cpu": 216,
    "memoryReservation": 512,
    "essential": true,
    "logConfiguration": { 
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.log-group.id}",
        "awslogs-region": "${var.aws_region}",
        "awslogs-stream-prefix": "${var.app_name}-${var.app_environment}"
      }
    },
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080,
        "protocol": "tcp"
      }
    ]
  }
]
EOF

  tags = {
    Application = var.app_name
    Environment = var.app_environment
    Name        = "${var.app_name}-${var.app_environment}-backend"
    Resource    = "modules.environment.aws_ecs_task_definition.backend"
  }

  depends_on = [
    aws_autoscaling_group.asg-cluster
  ]
}

# Create the ECS Service that will wrap the task definition.  Used primarily to
# define the connections to the load balancer and the placement strategies and
# constraints on the tasks.
resource "aws_ecs_service" "backend" {
  name            = "${var.app_name}-${var.app_environment}-backend"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.backend.arn

  desired_count                      = 1
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 100

  network_configuration {
    security_groups  = [aws_security_group.sg-scaling-ecs-cluster.id]
    subnets          = aws_subnet.private-subnet.*.id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "${var.app_name}-container"
    container_port   = var.container_port
  }

  tags = {
    Application = var.app_name
    Environment = var.app_environment
    Resource    = "modules.environment.aws_ecs_service.backend"
  }

  depends_on = [
    aws_lb_listener.listener
  ]
}


#############################################
# Application Loadbalancer
############################################
# Application Loadbalancer that serves traffic to the containers
resource "aws_lb" "web_elb" {
  name               = "${var.app_name}-lb"
  load_balancer_type = "application"
  internal           = false
  security_groups = [
    aws_security_group.sg-alb.id
  ]
  subnets = [for subnet in aws_subnet.public-subnet : subnet.id]

  enable_cross_zone_load_balancing = true
}

# Load Balancer Target Group, it will relate the Load Balancer with the Containers
resource "aws_lb_target_group" "target_group" {
  name        = "${var.app_name}-${var.app_environment}-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main-vpc.id

  health_check {
    healthy_threshold   = "3"
    interval            = "300"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }

  tags = {
    Name        = "${var.app_name}-lb-tg"
    Environment = var.app_environment
  }
}

# Https Application loadbalancer listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.web_elb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.id
  }
}


#####################################
# Cloud watch to watch container logs
####################################
resource "aws_cloudwatch_log_group" "log-group" {
  name = "${var.app_name}-${var.app_environment}-logs"

  tags = {
    Application = var.app_name
    Environment = var.app_environment
  }
}
