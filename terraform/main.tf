// main.tf
locals {
  project_name = "Cyber Lab"
  common_tags  = { Project = local.project_name }
}

# 1. SSH Keypair
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "random_id" "suffix" {
  byte_length = 4
}
resource "aws_key_pair" "deployer" {
  key_name   = "${var.key_name_prefix}-${random_id.suffix.hex}"
  public_key = tls_private_key.deployer.public_key_openssh
}
resource "local_file" "private_key_pem" {
  content         = tls_private_key.deployer.private_key_pem
  filename        = "${path.module}/deployer_key.pem"
  file_permission = "0400"
}

# 2. AMI Data Sources
data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

data "aws_ami" "kali" {
  most_recent = true
  owners      = ["679593333241"]
  filter {
    name   = "name"
    values = ["kali-*-amd64-*-*"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# 3. Networking: VPC, Subnet, IGW, Routing
resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(
    local.common_tags,
    { Name = "${local.project_name} VPC" }
  )
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags = merge(
    local.common_tags,
    { Name = "${local.project_name} Public Subnet" }
  )
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id
  tags   = merge(
    local.common_tags,
    { Name = "${local.project_name} IGW" }
  )
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.lab.id
  tags   = merge(
    local.common_tags,
    { Name = "${local.project_name} RT" }
  )
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

# 4. Security Groups

# Win/Kali Security Group
resource "aws_security_group" "win_kali_sg" {
  name        = "win-kali-sg"
  description = "Allow SSH, RDP, and ICMP from ${var.allowed_cidr}"
  vpc_id      = aws_vpc.lab.id

  # SSH for Win/Kali management
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # RDP to Windows server
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # ICMP (ping/traceroute)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    { Name = "${local.project_name} Win/Kali SG" }
  )
}

# Tools Security Group
resource "aws_security_group" "tools_sg" {
  name        = "tools-sg"
  description = "Allow Splunk, Nessus, SSH & ICMP from ${var.allowed_cidr}"
  vpc_id      = aws_vpc.lab.id

  # SSH for Tools box management
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Splunk Web UI
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Splunk Forwarder port
  ingress {
    from_port   = 9997
    to_port     = 9997
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Nessus UI
  ingress {
    from_port   = 8834
    to_port     = 8834
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # ICMP (ping/traceroute)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    { Name = "${local.project_name} Tools SG" }
  )
}

# 5. EC2 Instances
resource "aws_instance" "windows" {
  ami                         = data.aws_ami.windows.id
  instance_type               = var.windows_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.win_kali_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size = var.windows_volume_size
  }

  tags = merge(
    local.common_tags,
    { Name = "${local.project_name}-Windows" }
  )
}

resource "aws_instance" "kali" {
  ami                         = data.aws_ami.kali.id
  instance_type               = var.kali_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.win_kali_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deployer.key_name
  user_data                   = file("${path.module}/kali_setup.sh")

  root_block_device {
    volume_size = var.kali_volume_size
  }

  tags = merge(
    local.common_tags,
    { Name = "${local.project_name}-Kali" }
  )
}

resource "aws_instance" "tools" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.tools_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.tools_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size = var.tools_volume_size
  }

  tags = merge(
    local.common_tags,
    { Name = "${local.project_name}-Tools" }
  )
}

# 6. Outputs
output "private_key_path" {
  description = "Local path to the generated SSH private key"
  value       = local_file.private_key_pem.filename
}
output "windows_public_ip" {
  description = "Public IP of the Windows server"
  value       = aws_instance.windows.public_ip
}
output "kali_public_ip" {
  description = "Public IP of the Kali server"
  value       = aws_instance.kali.public_ip
}
output "tools_public_ip" {
  description = "Public IP of the Tools server"
  value       = aws_instance.tools.public_ip
}
