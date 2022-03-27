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
        Application = "ceros-ski" 
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
        Application = "ceros-ski"
        Environment = var.environment
        Name = "ceros-ski-${var.environment}-main_internet_gateway"
        Resource = "modules.environment.aws_internet_gateway.main_internet_gateway"
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
        Application = "ceros-ski" 
        Environment = var.environment 
        Name = "ceros-ski-${var.environment}-us-east-1a-public"
        Resource = "modules.availability_zone.aws_subnet.public_subnet"
    }
}

/**
* A route table for our public subnet.
*/
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id 

  tags = {
    Application = "ceros-ski" 
    Environment = var.environment 
    Name = "ceros-ski-${var.environment}-us-east-1a-public"
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
resource "aws_iam_role" "ecs_agent" {
  name = var.ecs-iam-role

  assume_role_policy = data.aws_iam_policy_document.ecs_agent_assume_role_policy.json
    tags = {
    Name        = "${var.app_name}-iam-role"
    Environment = var.app_environment
  }
}
