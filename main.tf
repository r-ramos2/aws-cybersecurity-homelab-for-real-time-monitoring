# Provider Configuration
provider "aws" {
  region = var.region
}

# VPC Creation
resource "aws_vpc" "homelab_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Cybersecurity Homelab VPC"
  }
}

# Create Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.homelab_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone

  map_public_ip_on_launch = true

  tags = {
    Name = "Cybersecurity Homelab Public Subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.homelab_vpc.id

  tags = {
    Name = "Cybersecurity Homelab IGW"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.homelab_vpc.id
}

# Route to Internet Gateway
resource "aws_route" "route_to_internet" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Route Table Association
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group for Windows and Kali
resource "aws_security_group" "win_kali_sg" {
  name        = "win-kali-sg"
  description = "Allow SSH, RDP, and ICMP"
  vpc_id      = aws_vpc.homelab_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    from_port   = -1  # ICMP
    to_port     = -1  # ICMP
    protocol    = "icmp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Windows and Kali Security Group"
  }
}

# Security Group for Linux Security Tools
resource "aws_security_group" "security_tools_sg" {
  name        = "security-tools-sg"
  description = "Security group for tools box"
  vpc_id      = aws_vpc.homelab_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    from_port   = 9997
    to_port     = 9997
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Tools Box Security Group"
  }
}

# Windows Instance
resource "aws_instance" "windows" {
  ami               = var.windows_ami
  instance_type     = var.windows_instance_type
  subnet_id         = aws_subnet.public_subnet.id
  security_groups   = [aws_security_group.win_kali_sg.name]
  associate_public_ip_address = true

  key_name          = var.aws_key_name
  root_block_device {
    volume_size = var.windows_volume_size
  }

  tags = {
    Name = "Cybersecurity Homelab [Windows 10]"
  }
}

# Kali Linux Instance
resource "aws_instance" "kali" {
  ami               = var.kali_ami
  instance_type     = var.kali_instance_type
  subnet_id         = aws_subnet.public_subnet.id
  security_groups   = [aws_security_group.win_kali_sg.name]
  associate_public_ip_address = true

  key_name          = var.aws_key_name
  root_block_device {
    volume_size = var.kali_volume_size
  }

  tags = {
    Name = "Cybersecurity Homelab [Kali Linux]"
  }
}

# Security Tools Box Instance
resource "aws_instance" "security_tools" {
  ami               = var.security_tools_ami
  instance_type     = var.security_tools_instance_type
  subnet_id         = aws_subnet.public_subnet.id
  security_groups   = [aws_security_group.security_tools_sg.name]
  associate_public_ip_address = true

  key_name          = var.aws_key_name
  root_block_device {
    volume_size = var.security_tools_volume_size
  }

  tags = {
    Name = "Cybersecurity Homelab [Security Tools]"
  }
}
