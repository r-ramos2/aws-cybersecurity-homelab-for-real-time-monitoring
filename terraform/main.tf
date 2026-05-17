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
# 3. Networking: VPC, Subnets, IGW, Routing
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

# Private subnet for the Windows victim machine.
# No public IP; outbound internet via NAT Gateway (needed for Windows Update / agents).
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-subnet"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-igw"
  })
}

# Public route table
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

# NAT Gateway (in public subnet) so Windows can reach the internet outbound
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-nat-gw"
  })

  depends_on = [aws_internet_gateway.igw]
}

# Private route table — all outbound goes through NAT Gateway
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-rt"
  })
}

resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

# ============================================
# 4. VPC Flow Logs (to CloudWatch Logs)
# ============================================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc-flow-logs/${aws_vpc.lab.id}"
  retention_in_days = 14

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc-flow-logs"
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.project_name}-vpc-flow-logs-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc-flow-logs-role"
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${local.project_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]

        Resource = [
          aws_cloudwatch_log_group.vpc_flow_logs.arn,
          "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:log-stream:*",
        ]
      }
    ]
  })
}

resource "aws_flow_log" "vpc" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  vpc_id               = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc-flow-log"
  })
}

# ============================================
# 4b. CloudTrail CloudWatch Logs delivery
# ============================================
resource "aws_cloudwatch_log_group" "cloudtrail_cw" {
  name              = "/aws/cloudtrail/${local.project_name}"
  retention_in_days = 14

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-cloudtrail-cw-logs"
  })
}

resource "aws_iam_role" "cloudtrail_cw" {
  name = "${local.project_name}-cloudtrail-cw-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-cloudtrail-cw-role"
  })
}

resource "aws_iam_role_policy" "cloudtrail_cw" {
  name = "${local.project_name}-cloudtrail-cw-policy"
  role = aws_iam_role.cloudtrail_cw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = [
          aws_cloudwatch_log_group.cloudtrail_cw.arn,
          "${aws_cloudwatch_log_group.cloudtrail_cw.arn}:log-stream:*",
        ]
      }
    ]
  })
}

# ============================================
# 4c. Tools instance CloudWatch log group
# ============================================
resource "aws_cloudwatch_log_group" "tools" {
  name              = "/aws/ec2/${local.project_name}-tools"
  retention_in_days = 14

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-tools-logs"
  })
}

# ============================================
# 5. Security Groups
# ============================================
resource "aws_security_group" "win_kali_sg" {
  name        = "win-kali-sg"
  description = "Allow SSH, RDP, and ICMP from ${var.allowed_cidr}"
  vpc_id      = aws_vpc.lab.id

  # SSH access from your IP (Kali)
  ingress {
    description = "SSH from allowed CIDR"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # RDP access from your IP (Kali)
  ingress {
    description = "RDP from allowed CIDR"
    from_port   = var.rdp_port
    to_port     = var.rdp_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # ICMP from your IP
  ingress {
    description = "ICMP from allowed CIDR"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.allowed_cidr]
  }

  # All TCP from within the VPC so Kali can attack Windows and
  # Nessus can scan Windows across the subnet boundary
  ingress {
    description = "All TCP from VPC (Kali attacks and Nessus scans)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  # ICMP from within the VPC (ping, traceroute during lab exercises)
  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr_block]
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

  # Splunk Forwarder from your workstation / jump host
  ingress {
    description = "Splunk Forwarder from allowed CIDR"
    from_port   = var.splunk_forwarder_port
    to_port     = var.splunk_forwarder_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Allow the Windows Universal Forwarder (private subnet) to reach Splunk.
  # The UF connects from 10.0.2.x, not from the operator's external IP.
  ingress {
    description = "Splunk Forwarder from VPC (Windows UF in private subnet)"
    from_port   = var.splunk_forwarder_port
    to_port     = var.splunk_forwarder_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
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
# 6. IAM Role for Tools Instance (least privilege for logging & SSM)
# ============================================
resource "aws_iam_role" "tools_instance" {
  name = "${local.project_name}-tools-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-tools-role"
  })
}

# SSM actions are left at Resource="*" because SSM does not support resource-
# level permissions for most of these API calls.
resource "aws_iam_role_policy" "tools_policy" {
  name = "${local.project_name}-tools-logs-ssm-policy"
  role = aws_iam_role.tools_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.tools.arn,
          "${aws_cloudwatch_log_group.tools.arn}:log-stream:*",
        ]
      },
      {
        Sid    = "AllowSSMCore"
        Effect = "Allow"
        Action = [
          "ssm:DescribeAssociation",
          "ssm:GetDeployablePatchSnapshotForInstance",
          "ssm:GetDocument",
          "ssm:DescribeDocument",
          "ssm:GetManifest",
          "ssm:GetParameters",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:PutInventory",
          "ssm:PutComplianceItems",
          "ssm:PutConfigurePackageResult",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceAssociationStatus",
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        # SSM does not support resource-level permissions for these actions.
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "tools" {
  name = "${local.project_name}-tools-instance-profile-${random_id.suffix.hex}"
  role = aws_iam_role.tools_instance.name
}

# ============================================
# 7. EC2 Instances (Kali, Windows, Tools)
# ============================================

# Kali — attacker, stays public (needs internet for tools; you SSH in directly)
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

# Windows — victim, moved to private subnet.
# No public IP; access via RDP tunnel through Kali (see outputs).
# Outbound internet (Windows Update, agents) goes via NAT Gateway.
resource "aws_instance" "windows" {
  ami                         = data.aws_ami.windows.id
  instance_type               = var.windows_instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.win_kali_sg.id]
  associate_public_ip_address = false
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

# Tools (Splunk + Nessus) — stays public (browser access to ports 8000 / 8834)
resource "aws_instance" "tools" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.tools_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.tools_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deployer.key_name
  iam_instance_profile        = aws_iam_instance_profile.tools.name

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

# ============================================
# 8. CloudTrail (API audit logging to S3 + CloudWatch Logs)
# ============================================

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "${local.project_name}-cloudtrail-${random_id.suffix.hex}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-cloudtrail-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket                  = aws_s3_bucket.cloudtrail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning protects log integrity — deleted or overwritten objects can be
# recovered, satisfying tamper-evidence requirements for audit logs.
resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket     = aws_s3_bucket.cloudtrail_logs.id
  depends_on = [aws_s3_bucket_public_access_block.cloudtrail_logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "lab" {
  name                          = "${local.project_name}-trail-${random_id.suffix.hex}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  # Deliver CloudTrail events to CloudWatch Logs for real-time monitoring.
  # Metric filters and alarms can fire on API events within seconds; S3
  # delivery has no guaranteed latency SLA and is not suitable for alerting.
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_cw.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cw.arn

  depends_on = [
    aws_s3_bucket_policy.cloudtrail_logs,
    aws_iam_role_policy.cloudtrail_cw,
  ]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-cloudtrail"
  })
}
