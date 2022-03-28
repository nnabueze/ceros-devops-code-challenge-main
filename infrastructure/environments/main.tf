/******************************************************************************
* VPC
*******************************************************************************/

/**
* The VPC is the private cloud that provides the network infrastructure into
* which we can launch our aws resources.  This is effectively the root of our
* private network.
*/
resource "aws_vpc" "main_vpc" {
    cidr_block = "172.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Application = var.app_name 
        Environment = var.environment
        Name = "ceros-ski-${var.environment}-main_vpc"
        Resource = "modules.environment.aws_vpc.main_vpc"
    }
}

/**
* Provides a connection between the VPC and the public internet, allowing
* traffic to flow in and out of the VPC and translating IP addresses to public
* addresses.
*/
resource "aws_internet_gateway" "main_internet_gateway" {
    vpc_id = aws_vpc.main_vpc.id

    tags = {
        Application = var.app_name
        Environment = var.environment
        Name = "ceros-ski-${var.environment}-main_internet_gateway"
        Resource = "modules.environment.aws_internet_gateway.main_internet_gateway"
    }
}

/**
* An elastic IP address to be used by the NAT Gateway defined below.  The NAT
* gateway acts as a gateway between our private subnets and the public
* internet, providing access out to the internet from with in those subnets,
* while denying access in to them from the public internet.  This IP address
* acts as the IP address from which all the outbound traffic from the private
* subnets will originate.
*/
resource "aws_eip" "eip_for_the_nat_gateway" {
  vpc = true

  tags = {
    Application = var.app_name
    Environment = var.environment 
    Name = "ceros-ski-${var.environment}-eip_for_the_nat_gateway"
    Resource = "modules.availability_zone.aws_eip.eip_for_the_nat_gateway"
  }
}

/******************************************************************************
* Public Subnet 
*******************************************************************************/

/**
* A public subnet with in our VPC that we can launch resources into that we
* want to be auto-assigned public ip addresses.  These resources will be
* exposed to the public internet, with public IPs, by default.  They don't need
* to go through, and aren't shielded by, the NAT Gateway.
Also creating public in number of avilability within the region
*/
resource "aws_subnet" "public_subnet" {
    count = "${length(data.aws_availability_zones.available.names)}"
    vpc_id = aws_vpc.main_vpc.id 
    availability_zone = data.aws_availability_zones.available.names[count.index]
    cidr_block = "172.0.${10+count.index}.0/24"
    map_public_ip_on_launch = true

    tags = {
        Application = var.app_name 
        Environment = var.environment 
        Name = "ceros-ski-${var.environment}-public"
        Resource = "modules.availability_zone.aws_subnet.public_subnet"
    }
}

/**
* A route table for our public subnet.
*/
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id 

  tags = {
    Application = var.app_name
    Environment = var.environment 
    Name = "ceros-ski-${var.environment}-public"
    Resource = "modules.availability_zone.aws_route_table.public_route_table"
  }
}

/**
* A route from the public route table out to the internet through the internet
* gateway.
*/
resource "aws_route" "route_from_public_route_table_to_internet" {
  route_table_id = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main_internet_gateway.id

}

/**
* Associate the public route table with the all the public subnet in all availability zone within the region .
*/
resource "aws_route_table_association" "public_route_table_to_public_subnet_association" {
    count = "${length(data.aws_availability_zones.available.names)}"
    subnet_id = aws_subnet.public_subnet[count.index].id
    route_table_id = aws_route_table.public_route_table.id
}

/**
* A NAT Gateway that lives in our public subnet and provides an interface
* between our private subnets and the public internet.  It allows traffic to
* exit our private subnets, but prevents traffic from entering them.
*/
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip_for_the_nat_gateway.id
  subnet_id = aws_subnet.public_subnet[0].id

  tags = {
    Application = "ceros-ski" 
    Environment = var.environment 
    Name = "ceros-ski-${var.environment}-us-east-1a"
    Resource = "modules.availability_zone.aws_nat_gateway.nat_gateway"
  }
}

/******************************************************************************
* Private Subnet 
*******************************************************************************/

/** 
* A private subnet for pieces of the infrastructure that we don't want to be
* directly exposed to the public internet.  Infrastructure launched into this
* subnet will not have public IP addresses, and can access the public internet
* only through the route to the NAT Gateway.
*/
resource "aws_subnet" "private_subnet" {
  count = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = aws_vpc.main_vpc.id 
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block = "172.0.${20+count.index}.0/24"

  tags = {
    Application = var.app_name 
    Environment = var.environment 
    Name = "ceros-ski-${var.environment}-private"
    Resource = "modules.availability_zone.aws_subnet.private_subnet"
  }
}

/**
* A route table for the private subnet.
*/
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id 

  tags = {
    Application = var.app_name
    Environment = var.environment 
    Name = "ceros-ski-${var.environment}-private"
    Resource = "modules.availability_zone.aws_route_table.private_route_table"
  }
}

/**
* A route from the private route table out to the internet through the NAT  
* Gateway.
*/
resource "aws_route" "route_from_private_route_table_to_internet" {
  route_table_id = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway.id
}

/**
* Associate the private route table with the private subnet.
*/
resource "aws_route_table_association" "private_route_table_to_private_subnet_association" {
  count = "${length(data.aws_availability_zones.available.names)}"
  subnet_id = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}

/******************************************************************************
* Bastion Host
*******************************************************************************/
/**
* The public key for the key pair we'll use to ssh into our bastion instance.
*/
resource "aws_key_pair" "bastion" {
  key_name = "ceros-ski-bastion-key-us-east-1a"
  public_key = file(var.public_key_path) 
}


/**
* Launch a bastion instance we can use to gain access to the private subnets of
* this availabilty zone.
*/
resource "aws_instance" "bastion" {
  ami = data.aws_ssm_parameter.cluster_ami_id.value
  key_name = aws_key_pair.bastion.key_name 
  instance_type = "t2.micro"

  associate_public_ip_address = true
  subnet_id = aws_subnet.public_subnet[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Application = var.app_name 
    Environment = var.environment 
    Name = "ceros-ski-${var.environment}-bastion"
    Resource = "modules.availability_zone.aws_instance.bastion"
  }
}

/**
* A security group for bastion host. for test purpose we are allowing all Ip to access port 22
*/
resource "aws_security_group" "bastion" {
  name = "${var.app_name}-ecs-sg"
  vpc_id = aws_vpc.main_vpc.id 

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    protocol = -1
    from_port = 0
    to_port = 0
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = {
    Application = var.app_name 
    Environment = var.environment 
    Resource = "modules.availability_zone.aws_security_group.bastion"
  }

}

/******************************************************************************
* ECS Cluster
*
* Create ECS Cluster and its supporting services, in this case EC2 instances in
* and Autoscaling group.
*
* *****************************************************************************/
/**
* The IAM role that will be used by the instances that back the ECS Cluster.
*/
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name = var.ecs-iam-role

  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
    tags = {
    Name        = "${var.app_name}-iam-role"
    Environment = var.environment
  }
}


/**
* The policy resource itself.  Uses the policy document defined above.
*/
resource "aws_iam_policy" "ecs_agent" {
  name = "ceros-ski-ecs-agent-policy"
  path = "/"
  description = "Access policy for the EC2 instances backing the ECS cluster."

  policy = data.aws_iam_policy_document.ecs_agent.json
}

/**
* Attatch the ecs_agent policy to the role.  The assume_role policy is attached
* above in the role itself.
*/
resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  //policy_arn = aws_iam_policy.ecs_agent.arn
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

/**
* The Instance Profile that associates the IAM resources we just finished
* defining with the launch configuration.
*/
resource "aws_iam_instance_profile" "ecs_agent" {
  name = "ceros-ski-ecs-agent"
  role = aws_iam_role.ecsTaskExecutionRole.name 
}

/**
Security group for elb that allow HTTP traffic to instances through Elastic Load Balancer
*/
resource "aws_security_group" "elb_sg" {
  name        = "ceros-ski-${var.environment}-autoscaling_group"
  description = "Allow HTTP traffic to instances through Elastic Load Balancer."
  vpc_id      = aws_vpc.main_vpc.id 

  ingress {
    description = "HTTP Ingress"
    from_port   = 80 
    to_port     = 80 
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Application = var.app_name
    Environment = var.environment
    Resource = "modules.ecs.cluster.aws_security_group.autoscaling_group"
  }
}

/**
ELB that serves traffic to the containers
*/

resource "aws_lb" "web_elb" {
  name = "${var.app_name}-lb"
  load_balancer_type = "application"
  internal = false
  security_groups = [
    aws_security_group.elb_sg.id
  ]
  subnets = [for subnet in aws_subnet.public_subnet : subnet.id]

  enable_cross_zone_load_balancing   = true


}

/**
Load Balancer Target Group, it will relate the Load Balancer with the Containers
*/
resource "aws_lb_target_group" "target_group" {
  name        = "${var.app_name}-${var.environment}-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main_vpc.id

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
    Environment = var.environment
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.web_elb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.id
  }
}


/**
* The launch configuration for the autoscaling group that backs our cluster.  
*/
resource "aws_launch_configuration" "cluster" {
    name = "ceros-ski-${var.environment}-cluster"
    image_id = data.aws_ssm_parameter.cluster_ami_id.value 
    instance_type = "t2.micro"
    iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
    security_groups = [aws_security_group.ecs_sg.id]

    // Register our EC2 instances with the correct ECS cluster.
    user_data = <<EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.cluster.name}" >> /etc/ecs/ecs.config
    EOF
}

/**
* The ECS Cluster and its services and task groups. 
*
* The ECS Cluster has no dependencies, but will be referenced in the launch
* configuration, may as well define it first for clarity's sake.
*/

resource "aws_ecs_cluster" "cluster" {
  name = "ceros-ski-${var.environment}-cluster"

  tags = {
    Application = var.app_name
    Environment = var.environment
    Resource = "modules.ecs.cluster.aws_ecs_cluster.cluster"
  }
}

/**
* A security group for ecs allowing access only from load banlancer.
*/
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.elb_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.app_name}-service-sg"
    Environment = var.environment
  }

}

/**
* The autoscaling group that backs our ECS cluster.
*/
resource "aws_autoscaling_group" "cluster" {
  name = "ceros-ski-${var.environment}-cluster"
  min_size = 2
  max_size = 3 
  
  vpc_zone_identifier = aws_subnet.public_subnet.*.id
  launch_configuration = aws_launch_configuration.cluster.name 

  tags = [{
    "Application" = var.app_name
    "propagate_at_launch" = true
    "Environment" = var.environment
    "Resource" = var.environment
    "Resource" = "modules.ecs.cluster.aws_autoscaling_group.cluster"
  },
  {
    "key" = "Environment"
    "value" = var.environment
    "propagate_at_launch" = true
  },
  {
    "key" = "Resource"
    "value" = "modules.ecs.cluster.aws_autoscaling_group.cluster"
    "propagate_at_launch" = true
  }]
}

/**
* Create the task definition for the ceros-ski backend, in this case a thin
* wrapper around the container definition.
*/
resource "aws_ecs_task_definition" "backend" {
  family = "ceros-ski-${var.environment}-backend"
  network_mode = "awsvpc"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn  

  container_definitions = <<EOF
[
  {
    "name": "${var.app_name}-container",
    "image": "${var.repository_url}:latest",
    "environment": [
      {
        "name": "PORT",
        "value": "8080"
      }
    ],
    "cpu": 512,
    "memoryReservation": 512,
    "executionRoleArn" : "${data.aws_iam_role.ecs_service.arn}",
    "networkMode": "awsvpc",
    "essential": true,
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
    Environment = var.environment 
    Name = "ceros-ski-${var.environment}-backend"
    Resource = "modules.environment.aws_ecs_task_definition.backend"
  }
}


/**
* Create the ECS Service that will wrap the task definition.  Used primarily to
* define the connections to the load balancer and the placement strategies and
* constraints on the tasks.
*/
resource "aws_ecs_service" "backend" {
  name = "ceros-ski-${var.environment}-backend"
  cluster = aws_ecs_cluster.cluster.id 
  task_definition = aws_ecs_task_definition.backend.arn
  
  desired_count = 2
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent = 100

  network_configuration {
    subnets          = aws_subnet.public_subnet.*.id
    assign_public_ip = false
    security_groups = [
      aws_security_group.ecs_sg.id,
      aws_security_group.elb_sg.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "${var.app_name}-container"
    container_port   = 8080
  }

  tags = {
    Application = var.app_name 
    Environment = var.environment 
    Resource = "modules.environment.aws_ecs_service.backend"
  }

  depends_on = [aws_lb_listener.listener]
}

