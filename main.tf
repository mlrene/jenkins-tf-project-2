terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.5.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}

# Configuring a backend to store our state files in s3 and a LockID to ensure only one user can "execute to the dynamodb table at a time"

terraform {
  backend "s3" {
    bucket         = "rene-terraform-backend-s3"
    key            = "terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "rene-terraform-backend-dynamodb"
    encrypt        = false
  }
}

variable "demo_vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "availability_zone" {}
variable "env_prefix" {}
variable "myIP" {}
variable "ami" {}
variable "instance_type" {}
variable "public_key" {}
# variable "public_key_location" {}


resource "aws_vpc" "demo-vpc" {
  cidr_block = var.demo_vpc_cidr_block

  tags = {
    Name = "${var.env_prefix}-demo-vpc"
  }
}

resource "aws_subnet" "demo-vpc-subnet_1" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.availability_zone
  tags = {
    Name = "${var.env_prefix}-subnet-1"
  }
}

resource "aws_internet_gateway" "demo-vpc-igw" {
  vpc_id = aws_vpc.demo-vpc.id
  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

resource "aws_default_route_table" "demo-vpc-default-rt" {
  default_route_table_id = aws_vpc.demo-vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo-vpc-igw.id
  }
  tags = {
    Name = "${var.env_prefix}-demo-vpc-default-rt"
  }
}

resource "aws_default_security_group" "demo-vpc-default-sg" {
  vpc_id = aws_vpc.demo-vpc.id

  ingress {
    protocol    = "tcp"
    cidr_blocks = [var.myIP]
    from_port   = 22
    to_port     = 22
  }
  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8080
    to_port     = 8080
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.env_prefix}-default-sg"
  }
}
data "aws_ami" "most_recent_amazon_linux_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Creating a KeyPair using terraform

resource "aws_key_pair" "My-Ca-KeyPair3" {
  key_name   = "My-Ca-KeyPair3"
  public_key = var.public_key
}

# resource "aws_key_pair" "My-Ca-KeyPair3" {
#   key_name   = "My-Ca-KeyPair3"
#   public_key = file(var.public_key_location)
# }

resource "aws_instance" "dev-ec2-1" {
  ami                         = data.aws_ami.most_recent_amazon_linux_ami.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.demo-vpc-subnet_1.id
  vpc_security_group_ids      = [aws_default_security_group.demo-vpc-default-sg.id]
  key_name                    = aws_key_pair.My-Ca-KeyPair3.key_name
  associate_public_ip_address = true
  user_data                   = file("entry_script.sh")
  # user_data = <<EOF
  #             #!/bin/bash
  #             sudo yum update -y && sudo yum install -y docker
  #             sudo systemctl start docker
  #             sudo usermod -aG docker ec2-user
  #             docker run -p 8080:80 nginx
  #             EOF

  tags = {
    Name = "${var.env_prefix}-ec2-1"
  }
}

output "aws_ami_id" {
  description = "ami id of source ami"
  value       = data.aws_ami.most_recent_amazon_linux_ami.id
}
output "aws_ami_creation_date" {
  description = "ami creation date"
  value       = data.aws_ami.most_recent_amazon_linux_ami.creation_date
}
output "aws_instance_public_ip_address" {
  description = "public ip of dev-ec2-1"
  value       = aws_instance.dev-ec2-1.public_ip
}

# resource "aws_security_group" "subnet-1-sg" {
#   name        = "ssh-sg"
#   description = "Allow ssh inbound traffic"
#   vpc_id      = aws_vpc.demo-vpc.id

#   ingress {
#     description = "https from internet"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "${var.env_prefix}-sg"
#   }
# }

# resource "aws_route_table" "demo-vpc-rt" {
#   vpc_id = aws_vpc.demo-vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.demo-vpc-igw.id
#   }
#   tags = {
#     Name = "${var.env_prefix}-route-table"
#   }
# }

# resource "aws_route_table_association" "a" {
#   subnet_id      = aws_subnet.demo-vpc-subnet_1.id
#   route_table_id = aws_route_table.demo-vpc-rt.id
# }
