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

output "cloudtrail_log_group_name" {
  description = "CloudWatch Logs group for CloudTrail events — use this to build metric filters and alarms for real-time API monitoring"
  value       = aws_cloudwatch_log_group.cloudtrail_cw.name
}

output "tools_log_group_name" {
  description = "CloudWatch Logs group for the tools (Splunk / Nessus) instance"
  value       = aws_cloudwatch_log_group.tools.name
}

output "tools_instance_profile_name" {
  description = "IAM instance profile attached to the tools instance"
  value       = aws_iam_instance_profile.tools.name
}

output "logs_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.id
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

# EC2 IPs
output "kali_public_ip" {
  description = "Public IP of the Kali Linux instance"
  value       = aws_instance.kali.public_ip
}

# Windows has no public IP — it is in the private subnet.
# Use its private IP to reach it from Kali or via the RDP tunnel below.
output "windows_private_ip" {
  description = "Private IP of the Windows Server instance"
  value       = aws_instance.windows.private_ip
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
  description = "RDP command to connect to Kali Linux (XFCE desktop) — /cert:tofu trusts the cert on first use instead of ignoring it permanently"
  value       = "xfreerdp /u:rdpuser /v:${aws_instance.kali.public_ip}:${var.rdp_port} /cert:tofu"
}

# Windows is in the private subnet. Open an SSH tunnel through Kali first,
# then RDP to localhost:13389 on your machine.
output "windows_rdp_tunnel_cmd" {
  description = "Step 1 — open SSH tunnel through Kali to reach Windows RDP"
  value       = "ssh -i deployer_key.pem -L 13389:${aws_instance.windows.private_ip}:${var.rdp_port} kali@${aws_instance.kali.public_ip} -N"
}

output "windows_rdp_url" {
  description = "Step 2 — RDP URL to use after the tunnel is open"
  value       = "rdp://localhost:13389"
}

output "tools_ssh_cmd" {
  description = "SSH command to connect to Tools server"
  value       = "ssh -i deployer_key.pem ubuntu@${aws_instance.tools.public_ip}"
}

# Service URLs on Tools server
output "splunk_url" {
  description = "Splunk Web UI URL (HTTPS — self-signed cert, accept browser warning)"
  value       = "https://${aws_instance.tools.public_ip}:${var.splunk_web_port}"
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
