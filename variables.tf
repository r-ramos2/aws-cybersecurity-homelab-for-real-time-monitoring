variable "region" {
  default = "us-east-1"
}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "availability_zone" {
  default = "us-east-1a"
}

variable "aws_key_name" {
  description = "SSH Public Key Name Created in AWS (keys are unique per region)."
  default     = "US-EAST-1-KEY"
}

variable "allowed_cidr" {
  description = "CIDR block allowed for inbound traffic."
  default     = "0.0.0.0/0"
}

variable "windows_ami" {
  description = "AMI ID for Windows 10 instance"
  default     = "ami-09e67e426f25ce0d7"
}

variable "kali_ami" {
  description = "AMI ID for Kali Linux instance"
  default     = "ami-08d4ac5b634553e16"
}

variable "security_tools_ami" {
  description = "AMI ID for Security Tools instance"
  default     = "ami-0a91cd140a1fc148a"
}

variable "windows_instance_type" {
  default = "t2.micro"
}

variable "kali_instance_type" {
  default = "t2.micro"
}

variable "security_tools_instance_type" {
  default = "t3.large"
}

variable "windows_volume_size" {
  default = 30
}

variable "kali_volume_size" {
  default = 12
}

variable "security_tools_volume_size" {
  default = 30
}
