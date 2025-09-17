output "deployer_key_name" {
  description = "Name of the key pair uploaded to AWS"
  value       = aws_key_pair.deployer.key_name
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
