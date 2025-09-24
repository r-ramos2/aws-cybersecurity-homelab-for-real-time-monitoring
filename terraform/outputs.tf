output "private_key_path" {
  description = "Path to the generated SSH private key"
  value       = local_file.private_key_pem.filename
  sensitive   = true
}

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

output "splunk_url" {
  description = "Splunk Web UI URL"
  value       = "http://${aws_instance.tools.public_ip}:${var.splunk_web_port}"
}

output "nessus_url" {
  description = "Nessus Web UI URL"
  value       = "https://${aws_instance.tools.public_ip}:${var.nessus_port}"
}
