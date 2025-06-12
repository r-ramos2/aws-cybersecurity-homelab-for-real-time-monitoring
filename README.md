# Scalable AWS Cybersecurity Lab for Real-Time Monitoring and Vulnerability Management

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-blue)](https://www.terraform.io/)

☁️ **Cloud Cybersecurity Homelab**  
Attack/defend lab on AWS with:

- **Kali Linux** for penetration testing  
- **Windows 10** as attack target  
- **Security Tools Box (Ubuntu)** running Splunk Enterprise & Nessus Essentials  

All infrastructure defined in Terraform for reproducibility, security, and scalability.

---

## Table of Contents

1. [Topology](#topology)  
2. [Architecture Overview](#architecture-overview)  
3. [Prerequisites](#prerequisites)  
4. [Repository Structure](#repository-structure)  
5. [Getting Started](#getting-started)  
6. [Instance Configuration](#instance-configuration)  
7. [Tool Installation & Configuration](#tool-installation--configuration)  
8. [Cleanup](#cleanup)  
9. [Best Practices](#best-practices)  
10. [Next Steps & Enhancements](#next-steps--enhancements)  
11. [Resources](#resources)  

---

## Topology

![Architecture Diagram](images/architecture-diagram.png)

A single public VPC containing three EC2 hosts in a public subnet, each secured by its own security group.

---

## Architecture Overview

- **VPC**: 10.0.0.0/16  
- **Public Subnet**: 10.0.1.0/24  
- **Internet Gateway & Route**: 0.0.0.0/0 → IGW  
- **Security Groups**  
  - **Win/Kali SG**: SSH (22), RDP (3389), ICMP  
  - **Tools SG**: SSH (22), Splunk (8000/9997), Nessus (8834), ICMP  
- **EC2 Instances**  
  1. **windows**: Windows 10 (t2.micro)  
  2. **kali**: Kali Linux (t2.micro)  
  3. **security_tools**: Ubuntu 20.04 (t3.large)  

---

## Prerequisites

- **AWS account** with EC2, VPC, IAM, S3 permissions  
- **AWS CLI** (run `aws configure`)  
- **Terraform** >= 1.5.0  
- **SSH client** (OpenSSH or PuTTY)  
- **RDP client** (e.g. Microsoft Remote Desktop)  

---

## Repository Structure

```text
.
├── images/               # Architecture diagram
├── scripts/              # Post-launch scripts
│   ├── nessus_install.sh
│   └── rdp.sh
├── terraform/            # Terraform config
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf
│   └── outputs.tf
└── README.md             # This file
````

---

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/r-ramos2/scalable-aws-cybersecurity-lab-for-real-time-monitoring-and-vulnerability-management.git
cd scalable-aws-cybersecurity-lab-for-real-time-monitoring-and-vulnerability-management/terraform
```

### 2. Configure AWS & Terraform

* Run `aws configure` to set up your AWS credentials.
* Review `variables.tf`. Override defaults by creating `terraform.tfvars` or setting environment variables:

  ```ini
  region             = "us-east-1"
  key_name_prefix    = "lab-deployer"
  allowed_cidr       = "192.0.2.0/24"
  ```

### 3. Deploy

```bash
terraform init
terraform plan -out lab.plan
terraform apply lab.plan
```

On success you’ll see:

* **Public IPs** for each instance
* **Path** to `deployer_key.pem`

---

## Instance Configuration

### Kali Linux

```bash
ssh -i ../deployer_key.pem ubuntu@<KALI_PUBLIC_IP>
bash ../scripts/rdp.sh
sudo adduser rdpuser
sudo usermod -aG sudo rdpuser
```

### Windows 10

1. In AWS Console, retrieve the Administrator password.
2. RDP to `RDP://<WINDOWS_PUBLIC_IP>` with that password.

### Security Tools Box (Ubuntu)

```bash
ssh -i ../deployer_key.pem ubuntu@<TOOLS_PUBLIC_IP>
sudo apt update && sudo apt upgrade -y
bash ../scripts/nessus_install.sh
```

---

## Tool Installation & Configuration

### Splunk Enterprise

```bash
wget -O splunk.deb https://download.splunk.com/releases/9.1.0/linux/splunk.deb
sudo dpkg -i splunk.deb
sudo /opt/splunk/bin/splunk start --accept-license --answer-yes
```

* **UI**: `http://<TOOLS_PUBLIC_IP>:8000`
* **Forwarder port**: 9997

### Splunk Universal Forwarder (Windows)

1. Install the UF MSI on the Windows instance.
2. Copy `splunk_inputs.conf` to:

   ```
   C:\Program Files\SplunkUniversalForwarder\etc\system\local\
   ```
3. Edit `outputs.conf` to point at `<TOOLS_PRIVATE_IP>:9997`.
4. Restart:

   ```powershell
   cd "C:\Program Files\SplunkUniversalForwarder\bin"
   .\splunk.exe restart
   ```

### Tenable Nessus Essentials

```bash
wget -O nessus.deb "https://www.tenable.com/downloads/api/v2/pages/nessus/files/Nessus-10.3.0-debian6_amd64.deb"
sudo dpkg -i nessus.deb || sudo apt-get install -f -y
sudo systemctl enable --now nessusd
```

* **UI**: `https://<TOOLS_PUBLIC_IP>:8834`

---

## Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

---

## Best Practices

* **Least-privilege IAM**: use roles, rotate credentials.
* **Restrict SGs**: lock inbound to your office/VPN CIDR.
* **Key management**: rotate SSH keys regularly.
* **Logging & monitoring**: enable CloudTrail, CloudWatch, and alerts.

---

## Next Steps & Enhancements

* Break into **Terraform modules** (network, security, compute).
* Enable **remote state** (S3 + DynamoDB locking).
* Integrate **Ansible** for post-provisioning.
* Add **IDS/IPS** (Suricata, Zeek).
* Containerize with **Docker/Kubernetes**.

---

## Resources

* [AWS Documentation](https://aws.amazon.com/documentation/)
* [Terraform Docs](https://www.terraform.io/docs)
* [Splunk Docs](https://docs.splunk.com/)
* [Tenable Nessus Docs](https://docs.tenable.com/nessus/)
* [Kali Linux](https://www.kali.org/)
* [Windows 10 Support](https://support.microsoft.com/windows)
