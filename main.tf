terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}


#Configure s3 as backend for your statefile
terraform {
  backend "s3" {
    bucket = "sirri-ec2-bucket"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }
}

# Declare the data source for availablity zone depending on region specified
data "aws_availability_zones" "available" {
  state = "available"
}

#create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main"

  }
}
#create public and private subnets
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public subnet"


  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "Private subnet"

  }
}

#internet gate way
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "mainGW"
  }
}

#elastic ip for nat gateway
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "NAT Gateway EIP"
  }
}


# Nat gate way
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "Main Nat Gateway"
  }
}

#Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route table"
  }
}
#Associate between public and private Route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
#Route Table for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private Route table"
  }
}

#Associate between public and private Route table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}


###########################################################################
# create a security group
###########################################################################
resource "aws_security_group" "allow_tls" {

  name        = "appDMZ"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "allow_tls"
  }
}

######################################################################################
# create an instance
######################################################################################
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami = data.aws_ami.ubuntu.id
  #count         = var.instance_count
  instance_type        = var.instance_type
  key_name             = var.key_name
  subnet_id            = aws_subnet.private.id
  security_groups      = ["${aws_security_group.allow_tls.id}"]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id

  tags = {
    Name = "nodeapp"
  }

}
