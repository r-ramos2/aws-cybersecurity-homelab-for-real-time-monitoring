locals {
  project_name = "aws-cybersecurity-homelab"
  common_tags = {
    Project     = local.project_name
    ManagedBy   = "Terraform"
    Environment = "Development"
  }
}

# ============================================
# 1. SSH Keypair Generation
# ============================================
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

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-keypair"
  })
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.deployer.private_key_pem
  filename        = "${path.module}/deployer_key.pem"
  file_permission = "0400"
}

# ============================================
# 2. AMI Data Source (Windows, Kali, Ubuntu)
# ============================================
data "aws_ami" "windows" {
  most_recent = true
  owners      = [var.windows_ami_owner]

  filter {
    name   = "name"
    values = [var.windows_ami_name_filter]
  }
}

data "aws_ami" "kali" {
  most_recent = true
  owners      = [var.kali_ami_owner]

  filter {
    name   = "name"
    values = [var.kali_ami_name_filter]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.ubuntu_ami_owner]

  filter {
    name   = "name"
    values = [var.ubuntu_ami_name_filter]
  }
}

# ============================================
# 3. Networking: VPC, Subnet, IGW, Routing
# ============================================
resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-subnet"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-igw"
  })
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-rt"
  })
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

# ============================================
# 4. Security Group
# ============================================
resource "aws_security_group" "win_kali_sg" {
  name        = "win-kali-sg"
  description = "Allow SSH, RDP, and ICMP from ${var.allowed_cidr}"
  vpc_id      = aws_vpc.lab.id

  # SSH access
  ingress {
    description = "SSH from allowed CIDR"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # RDP access
  ingress {
    description = "RDP from allowed CIDR"
    from_port   = var.rdp_port
    to_port     = var.rdp_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # ICMP access
  ingress {
    description = "ICMP from allowed CIDR"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-sg"
  })
}

resource "aws_security_group" "tools_sg" {
  name        = "tools-sg"
  description = "Allow Splunk, Nessus, SSH & ICMP from ${var.allowed_cidr}"
  vpc_id      = aws_vpc.lab.id

  # SSH access
  ingress {
    description = "SSH from allowed CIDR"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Splunk Web UI
  ingress {
    description = "Splunk Web UI from allowed CIDR"
    from_port   = var.splunk_web_port
    to_port     = var.splunk_web_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Splunk Forwarder
  ingress {
    description = "Splunk Forwarder from allowed CIDR"
    from_port   = var.splunk_forwarder_port
    to_port     = var.splunk_forwarder_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Nessus UI
  ingress {
    description = "Nessus UI from allowed CIDR"
    from_port   = var.nessus_port
    to_port     = var.nessus_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # ICMP access
  ingress {
    description = "ICMP from allowed CIDR"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-sg"
  })
}

# ============================================
# 5. EC2 Instance (Kali, Windows, and Tools)
# ============================================
resource "aws_instance" "kali" {
  ami                         = data.aws_ami.kali.id
  instance_type               = var.kali_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.win_kali_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deployer.key_name
  user_data                   = file("${path.module}/../scripts/kali_setup.sh")

  root_block_device {
    volume_size           = var.kali_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(local.common_tags, {
      Name = "${local.project_name}-kali-root-volume"
    })
  }

  # Use on-demand instances for reliability
  # Note: Spot instances can be terminated with 2-minute notice
  # Uncomment the block below to use Spot instances (cost savings)
  # instance_market_options {
  #   market_type = "spot"
  #   spot_options {
  #     allocation_strategy            = "capacity-optimized"
  #     instance_interruption_behavior = "terminate"
  #     spot_instance_type             = "one-time"
  #   }
  # }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-kali-server"
  })
}

resource "aws_instance" "windows" {
  ami                         = data.aws_ami.windows.id
  instance_type               = var.windows_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.win_kali_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size           = var.windows_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(local.common_tags, {
      Name = "${local.project_name}-windows-root-volume"
    })
  }

  # Use on-demand instances for reliability
  # Note: Spot instances can be terminated with 2-minute notice
  # Uncomment the block below to use Spot instances (cost savings)
  # instance_market_options {
  #   market_type = "spot"
  #   spot_options {
  #     allocation_strategy            = "capacity-optimized"
  #     instance_interruption_behavior = "terminate"
  #     spot_instance_type             = "one-time"
  #   }
  # }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-windows-server"
  })
}

resource "aws_instance" "tools" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.tools_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.tools_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size           = var.tools_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(local.common_tags, {
      Name = "${local.project_name}-tools-root-volume"
    })
  }

  # Use on-demand instances for reliability (no spot configuration)

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-tools-server"
  })
}
