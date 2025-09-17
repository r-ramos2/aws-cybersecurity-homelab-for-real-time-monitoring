output "deployer_key_path" {
  description = "Path to the SSH private key generated for this lab"
  value       = "${path.module}/../deployer_key.pem"
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
  value       = aws_instance.security_tools.public_ip
}
