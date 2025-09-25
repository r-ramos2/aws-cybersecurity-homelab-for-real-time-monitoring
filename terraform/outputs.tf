# SSH Key
output "private_key_path" {
  description = "Path to the generated SSH private key"
  value       = local_file.private_key_pem.filename
  sensitive   = true
}

# EC2 Public IPs
output "windows_public_ip" {
  description = "Public IP of the Windows Server instance"
  value       = aws_instance.windows.public_ip
}

output "kali_public_ip" {
  description = "Public IP of the Kali Linux instance"
  value       = aws_instance.kali.public_ip
}

output "tools_public_ip" {
  description = "Public IP of the Security Tools (Ubuntu) instance"
  value       = aws_instance.tools.public_ip
}

# RDP / SSH convenience commands
output "windows_rdp_url" {
  description = "RDP URL for Windows Server"
  value       = "rdp://${aws_instance.windows.public_ip}:${var.rdp_port}"
}

output "kali_ssh_cmd" {
  description = "SSH command to connect to Kali Linux"
  value       = "ssh -i ${local_file.private_key_pem.filename} kali@${aws_instance.kali.public_ip}"
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
