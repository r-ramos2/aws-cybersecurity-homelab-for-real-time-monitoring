# SSH Key
output "private_key_path" {
  description = "Path to the generated SSH private key"
  value       = local_file.private_key_pem.filename
  sensitive   = true
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
  value       = "ssh -i ${local_file.private_key_pem.filename} kali@${aws_instance.kali.public_ip}"
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
  value       = "ssh -i ${local_file.private_key_pem.filename} ubuntu@${aws_instance.tools.public_ip}"
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
  value       = "aws ec2 get-password-data --instance-id ${aws_instance.windows.id} --priv-launch-key ${local_file.private_key_pem.filename} --query 'PasswordData' --output text | base64 -d"
}
