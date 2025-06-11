# Scalable AWS Cybersecurity Lab for Real-Time Monitoring and Vulnerability Management

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-blue)](https://www.terraform.io/)

☁️ **Cloud Cybersecurity Homelab**

Deploy an attack/defend cybersecurity home lab on AWS, including:

* **Kali Linux** for penetration testing
* **Windows 10** as the attack target
* **Security Tools Box (Ubuntu)** hosting Splunk Enterprise & Nessus Essentials

All infrastructure is defined in Terraform for reproducibility, security, and scalability.

---

## Table of Contents

1. [Topology](#topology)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Repository Structure](#repository-structure)
5. [Getting Started](#getting-started)

   * [Clone the repo](#clone-the-repo)
   * [Configure AWS CLI & Terraform](#configure-aws-cli--terraform)
   * [Deploy with Terraform](#deploy-with-terraform)
6. [Instance Configuration](#instance-configuration)

   * [Kali Linux](#kali-linux)
   * [Windows 10](#windows-10)
   * [Security Tools Box (Ubuntu)](#security-tools-box-ubuntu)
7. [Install & Configure Tools](#install--configure-tools)

   * [Splunk Enterprise](#splunk-enterprise)
   * [Universal Forwarder (Windows)](#universal-forwarder-windows)
   * [Tenable Nessus Essentials](#tenable-nessus-essentials)
8. [Cleanup](#cleanup)
9. [Best Practices](#best-practices)
10. [Next Steps & Enhancements](#next-steps--enhancements)
11. [Resources](#resources)

---

## Topology

[<img width="872" alt="429640939-4b20576d-3fa6-4f0c-8b35-3ab63c32cde9" src="https://github.com/user-attachments/assets/86846a94-2e43-47ad-be05-23a0410bfb7b" />](https://github.com/r-ramos2/scalable-aws-cybersecurity-lab-for-real-time-monitoring-and-vulnerability-management/blob/main/images/architecture-diagram.png?raw=true)

A public VPC with three EC2 hosts in a public subnet, secured by dedicated security groups.

---

## Architecture Overview

* **VPC**: 10.0.0.0/16
* **Public Subnet**: 10.0.1.0/24
* **Internet Gateway & Routing**: Routes all traffic (0.0.0.0/0) to the IGW
* **Security Groups**:

  * **Win/Kali SG**: SSH (22), RDP (3389), ICMP
  * **Tools SG**: SSH (22), Splunk (8000/9997), Nessus (8834), ICMP
* **EC2 Instances**:

  1. **`windows`**: Windows 10 (t2.micro)
  2. **`kali`**: Kali Linux (t2.micro)
  3. **`security_tools`**: Ubuntu (t3.large)

---

## Prerequisites

* **AWS Account** with privileges for EC2, VPC, IAM, S3
* **AWS CLI** (configured via `aws configure`)
* **Terraform** >= 1.5.0
* **SSH Client** (OpenSSH or PuTTY)
* **RDP Client** (e.g. Microsoft Remote Desktop)

---

## Repository Structure

```text
├── images/               # Architecture diagram
├── scripts/              # Post-launch helper scripts
│   ├── nessus_install.sh
│   └── rdp.sh
├── terraform/            # Terraform config
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf
│   └── outputs.tf
└── README.md             # This file
```

---

## Getting Started

### Clone the repo

```bash
git clone https://github.com/r-ramos2/scalable-aws-cybersecurity-lab-for-real-time-monitoring-and-vulnerability-management.git
cd your-repo/terraform
```

### Configure AWS CLI & Terraform

1. **AWS credentials**: `aws configure`
2. **Variables**: Review `variables.tf` and override via `terraform.tfvars` or environment variables.

### Deploy with Terraform

```bash
terraform init
terraform plan -out=plan.out
terraform apply plan.out
```

Upon success, Terraform will output the public IPs for each instance and the path to your SSH private key.

---

## Instance Configuration

### Kali Linux

```bash
ssh -i ../deployer_key.pem ubuntu@<KALI_PUBLIC_IP>
# Enable RDP and XFCE
echo "Running RDP setup..."
bash ../scripts/rdp.sh
# Create RDP user
sudo adduser rdpuser && sudo usermod -aG sudo rdpuser
```

### Windows 10

1. **Retrieve admin password** from AWS Console
2. **RDP**: `rdp://<WINDOWS_PUBLIC_IP>`
3. (Optional) Temporarily disable Firewall for testing

### Security Tools Box (Ubuntu)

```bash
ssh -i ../deployer_key.pem ubuntu@<TOOLS_PUBLIC_IP>
sudo apt update && sudo apt upgrade -y
bash ../scripts/nessus_install.sh
```

---

## Install & Configure Tools

### Splunk Enterprise

```bash
wget -O splunk.deb https://download.splunk.com/releases/9.1.0/linux/splunk.deb
sudo dpkg -i splunk.deb
sudo /opt/splunk/bin/splunk start --accept-license --answer-yes
```

* Web UI: `http://<TOOLS_PUBLIC_IP>:8000`
* Forwarder port: 9997

### Universal Forwarder (Windows)

1. **Install** the Splunk UF MSI on Windows 10
2. **Configure inputs**: place `splunk_inputs.conf` in `C:\Program Files\SplunkUniversalForwarder\etc\system\local\`
3. **Edit** target to `<TOOLS_PRIVATE_IP>:9997`
4. **Restart**:

   ```powershell
   cd "C:\Program Files\SplunkUniversalForwarder\bin\"
   .\splunk.exe restart
   ```

### Tenable Nessus Essentials

```bash
wget -O nessus.deb "https://www.tenable.com/downloads/api/.../nessus/download?i_agree_to_tenable_license_agreement=true"
sudo dpkg -i nessus.deb
sudo systemctl enable --now nessusd
```

* UI: `https://<TOOLS_PUBLIC_IP>:8834`

---

## Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

---

## Best Practices

* **Least-Privilege IAM**: use roles & rotate credentials
* **Security Groups**: restrict to your office/VPN CIDR
* **Key Management**: rotate SSH keys regularly
* **Logging & Monitoring**: enable CloudTrail, CloudWatch, and Alerts

---

## Next Steps & Enhancements

* Use **Terraform modules** for network, security, and compute
* Configure **remote state** in S3 with DynamoDB locking
* Integrate **Ansible** for post-provisioning
* Add **IDS/IPS** (Suricata, Zeek)
* Containerize workloads with **Docker/Kubernetes**

---

## Resources

* [AWS Documentation](https://aws.amazon.com/documentation/)
* [Terraform Docs](https://www.terraform.io/docs)
* [Splunk Docs](https://docs.splunk.com)
* [Tenable Nessus Docs](https://docs.tenable.com/nessus/)
* [Kali Linux](https://www.kali.org/)
* [Windows 10](https://support.microsoft.com/windows)
