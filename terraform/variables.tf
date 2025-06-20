// variables.tf
variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}
variable "key_name_prefix" {
  description = "Prefix for the auto-generated SSH keypair"
  type        = string
  default     = "lab-deployer"
}
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
variable "allowed_cidr" {
  description = "CIDR block permitted to reach instances (SSH/RDP/etc.)"
  type        = string
  default     = "0.0.0.0/0"
}
variable "windows_instance_type" {
  description = "EC2 type for Windows server"
  type        = string
  default     = "t3.small"
}
variable "kali_instance_type" {
  description = "EC2 type for Kali attacker VM"
  type        = string
  default     = "t3.small"
}
variable "tools_instance_type" {
  description = "EC2 type for security tools server"
  type        = string
  default     = "t3.large"
}
variable "windows_volume_size" {
  description = "Root EBS volume size for Windows (GB)"
  type        = number
  default     = 30
}
variable "kali_volume_size" {
  description = "Root EBS volume size for Kali (GB)"
  type        = number
  default     = 12
}
variable "tools_volume_size" {
  description = "Root EBS volume size for Tools server (GB)"
  type        = number
  default     = 30
}
