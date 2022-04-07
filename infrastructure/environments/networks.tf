###########################################
# Network 
##########################################
# Creating VPC 
resource "aws_vpc" "main-vpc" {
  cidr_block           = "172.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.tags
}


# Internet gateway for accessing internet outside VPC
resource "aws_internet_gateway" "main-gw" {
  vpc_id = aws_vpc.main-vpc.id

  tags = local.tags
}

# Create Elestic Ip for NAT within the AZ to be associated with NAT gateway
resource "aws_eip" "eip-for-nat" {
  count = local.az-count
  vpc   = true

  tags = local.tags
}

########################################
# Subnets
#######################################
# Creating a public subnet
resource "aws_subnet" "public-subnet" {
  count             = local.az-count
  vpc_id            = aws_vpc.main-vpc.id
  availability_zone = data.aws_availability_zones.az-available.names[count.index]
  cidr_block        = "172.0.${10 + count.index}.0/24"

  tags = local.tags
}

# create a NAT Gateway within the public the public subnet accross all az
# to grante access to instances with the private subnet
resource "aws_nat_gateway" "nat-gateway" {
  count         = local.az-count
  allocation_id = aws_eip.eip-for-nat[count.index].id
  subnet_id     = aws_subnet.public-subnet[count.index].id

  tags = local.tags
}

# create a private subnet
resource "aws_subnet" "private-subnet" {
  count             = local.az-count
  vpc_id            = aws_vpc.main-vpc.id
  availability_zone = data.aws_availability_zones.az-available.names[count.index]
  cidr_block        = "172.0.${20 + count.index}.0/24"

  tags = local.tags
}


#######################################
# Route table
#######################################

# Create a route table for pubic subnet
# and a route to the gateway
resource "aws_route_table" "public-route-tb" {
  count  = local.az-count
  vpc_id = aws_vpc.main-vpc.id

  tags = local.tags
}

# A route from public subnet to internet
resource "aws_route" "public-route-to-gw" {
  count                  = local.az-count
  route_table_id         = aws_route_table.public-route-tb[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main-gw.id
}

# Associate the public route table to public subnet
resource "aws_route_table_association" "public-subnet-associate" {
  count          = local.az-count
  subnet_id      = aws_subnet.public-subnet[count.index].id
  route_table_id = aws_route_table.public-route-tb[count.index].id
}

# private route table
resource "aws_route_table" "private-route-tb" {
  count  = local.az-count
  vpc_id = aws_vpc.main-vpc.id


  tags = local.tags
}

# Creating a route from private subnet to nat gateway within
# the public subnet
resource "aws_route" "private-route-nat" {
  count                  = local.az-count
  route_table_id         = aws_route_table.private-route-tb[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat-gateway[count.index].id

}

# Asscoiating route table to private subnet
resource "aws_route_table_association" "private-subnet-associate" {
  count          = local.az-count
  subnet_id      = aws_subnet.private-subnet[count.index].id
  route_table_id = aws_route_table.private-route-tb[count.index].id
}
