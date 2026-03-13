# 1. VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Elasticity-VPC"
  }
}

# 2. Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "Elasticity-IGW"
  }
}

# 3. Public Routing Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Elasticity-Public-RT"
  }
}

# 4. Public Subnets (in 2 Availability Zones)
# AZ 1
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true # Instances get a public IP automatically

  tags = {
    Name = "Elasticity-Public-1"
  }
}

# AZ 2
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Elasticity-Public-2"
  }
}

# 5. Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# -------------------------------------------------------------
# Security Groups
# -------------------------------------------------------------

# 6. Security Group for the Application Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "elasticity-alb-sg"
  description = "Allow HTTP traffic from the internet to the ALB"
  vpc_id      = aws_vpc.main.id

  # Inbound rule: allow HTTP from ANYWHERE
  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule: allow all traffic leaving the ALB
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Elasticity-ALB-SG"
  }
}

# 7. Security Group for the EC2 Instances (Web Servers)
resource "aws_security_group" "web_sg" {
  name        = "elasticity-web-sg"
  description = "Allow HTTP traffic ONLY from the ALB"
  vpc_id      = aws_vpc.main.id

  # CRITICAL SECURITY RULE: Only allow HTTP traffic if it comes from our ALB. 
  # We use security_groups instead of cidr_blocks to enforce this.
  ingress {
    description     = "HTTP strictly from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Elasticity-Backend-SG"
  }
}
