# Global settings
variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "key_name_prefix" {
  description = "Prefix for the auto-generated SSH keypair"
  type        = string
  default     = "cyberlab-deployer"
}

# Networking
variable "vpc_cidr_block" {
  description = "CIDR block for the primary VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "AZ for the public subnet"
  type        = string
  default     = "us-east-1a"
}

# AMI Lookup
variable "kali_ami_owner" {
  description = "Owner ID for Kali AMI"
  type        = string
  default     = "679593333241"
}

variable "kali_ami_name_filter" {
  description = "Filter for Kali AMI"
  type        = string
  default     = "kali-*-amd64-*-*"
}

variable "windows_ami_owner" {
  description = "Owner ID for Windows AMI"
  type        = string
  default     = "amazon"
}

variable "windows_ami_name_filter" {
  description = "Filter for Windows AMI"
  type        = string
  default     = "Windows_Server-2019-English-Full-Base-*"
}

variable "ubuntu_ami_owner" {
  description = "Owner ID for Ubuntu AMI"
  type        = string
  default     = "099720109477"
}

variable "ubuntu_ami_name_filter" {
  description = "Filter for Ubuntu AMI"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
}

# Allowed CIDR for access (replace with your public IP /32)
variable "allowed_cidr" {
  description = "CIDR block permitted to reach instances (e.g. 203.0.113.25/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0))
    error_message = "allowed_cidr must be a valid IPv4 CIDR block, e.g. 203.0.113.25/32"
  }
}

# Ports
variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

variable "rdp_port" {
  description = "RDP port for Windows"
  type        = number
  default     = 3389
}

variable "splunk_web_port" {
  description = "Splunk Web UI port"
  type        = number
  default     = 8000
}

variable "splunk_forwarder_port" {
  description = "Splunk Forwarder port"
  type        = number
  default     = 9997
}

variable "nessus_port" {
  description = "Nessus UI port"
  type        = number
  default     = 8834
}

# EC2 Sizing
variable "kali_instance_type" {
  description = "EC2 instance type for Kali attacker VM"
  type        = string
  default     = "t3.small"
}

variable "windows_instance_type" {
  description = "EC2 instance type for Windows server"
  type        = string
  default     = "t3.medium"
}

variable "tools_instance_type" {
  description = "EC2 instance type for security tools server"
  type        = string
  default     = "t3.large"
}

# Volume Sizes (GB)
variable "kali_volume_size" {
  description = "Root EBS volume size for Kali"
  type        = number
  default     = 12
}

variable "windows_volume_size" {
  description = "Root EBS volume size for Windows"
  type        = number
  default     = 30
}

variable "tools_volume_size" {
  description = "Root EBS volume size for Tools server"
  type        = number
  default     = 30
}
