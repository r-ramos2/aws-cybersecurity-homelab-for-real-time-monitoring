// variables.tf
# Global settings
variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}
variable "key_name_prefix" {
  description = "Prefix for the auto-generated SSH keypair"
  type        = string
  default     = "devsecops-deployer"
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
  description = "AZ in which to create the public subnet"
  type        = string
  default     = "us-east-1a"
}
variable "my_ip" {
  description = "Your IP CIDR block for SSH access"
  type        = string
  default     = "203.0.113.0/32"
}

# AMI Lookup
variable "ami_name_filter" {
  description = "Filter to find the latest Amazon Linux 2 AMI"
  type        = string
  default     = "amzn2-ami-hvm-*-gp2"
}

# EC2 Sizing
variable "instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t2.large"
}
variable "root_volume_size" {
  description = "Root EBS volume size for Jenkins (GB)"
  type        = number
  default     = 30
}

# Ports
variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}
variable "http_port" {
  description = "HTTP port for React App"
  type        = number
  default     = 80
}
variable "https_port" {
  description = "HTTPS port for secure access"
  type        = number
  default     = 443
}
variable "jenkins_port" {
  description = "Jenkins Web UI port"
  type        = number
  default     = 8080
}
variable "sonarqube_port" {
  description = "SonarQube UI port"
  type        = number
  default     = 9000
}
variable "react_port" {
  description = "React App port"
  type        = number
  default     = 3000
}

# Security
variable "allowed_cidr" {
  description = "CIDR block permitted to reach instances (SSH/HTTP/etc.)"
  type        = string
  default     = "0.0.0.0/0"
}
