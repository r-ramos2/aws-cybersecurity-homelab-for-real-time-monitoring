# SSH Key
output "private_key_pem" {
  description = "Private key PEM — pipe to a file: terraform output -raw private_key_pem > deployer_key.pem && chmod 400 deployer_key.pem"
  value       = tls_private_key.deployer.private_key_pem
  sensitive   = true
}

# Logging & IAM
output "vpc_flow_log_group_name" {
  description = "CloudWatch Logs group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "tools_instance_profile_name" {
  description = "IAM instance profile attached to the tools instance"
  value       = aws_iam_instance_profile.tools.name
}

# EC2 Instance IDs
output "kali_instance_id" {
  description = "Instance ID of Kali Linux"
  value       = aws_instance.kali.id
}

output "windows_instance_id" {
  description = "Instance ID of Windows Server (needed for password retrieval)"
  value       = aws_instance.windows.id
}

output "tools_instance_id" {
  description = "Instance ID of Security Tools server"
  value       = aws_instance.tools.id
}

# EC2 Public IPs
output "kali_public_ip" {
  description = "Public IP of the Kali Linux instance"
  value       = aws_instance.kali.public_ip
}

output "windows_public_ip" {
  description = "Public IP of the Windows Server instance"
  value       = aws_instance.windows.public_ip
}

output "tools_public_ip" {
  description = "Public IP of the Security Tools (Ubuntu) instance"
  value       = aws_instance.tools.public_ip
}

# RDP / SSH convenience commands
output "kali_ssh_cmd" {
  description = "SSH command to connect to Kali Linux"
  value       = "ssh -i deployer_key.pem kali@${aws_instance.kali.public_ip}"
}

output "kali_rdp_cmd" {
  description = "RDP command to connect to Kali Linux (XFCE desktop)"
  value       = "xfreerdp /u:kali /v:${aws_instance.kali.public_ip}:${var.rdp_port} /cert:ignore"
}

output "windows_rdp_url" {
  description = "RDP URL for Windows Server"
  value       = "rdp://${aws_instance.windows.public_ip}:${var.rdp_port}"
}

output "tools_ssh_cmd" {
  description = "SSH command to connect to Tools server"
  value       = "ssh -i deployer_key.pem ubuntu@${aws_instance.tools.public_ip}"
}

# Service URLs on Tools server
output "splunk_url" {
  description = "Splunk Web UI URL"
  value       = "http://${aws_instance.tools.public_ip}:${var.splunk_web_port}"
}

output "nessus_url" {
  description = "Nessus Web UI URL"
  value       = "https://${aws_instance.tools.public_ip}:${var.nessus_port}"
}

# Helpful reminders
output "windows_password_cmd" {
  description = "Command to retrieve Windows Administrator password (wait 4-5 minutes after launch)"
  value       = "aws ec2 get-password-data --instance-id ${aws_instance.windows.id} --priv-launch-key deployer_key.pem --query 'PasswordData' --output text | base64 -d"
}