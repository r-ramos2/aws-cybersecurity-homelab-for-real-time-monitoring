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

Single public VPC containing three EC2 hosts in a public subnet, each secured by its own security group.

---

## Architecture Overview

- **VPC**: 10.0.0.0/16  
- **Public Subnet**: 10.0.1.0/24  
- **Internet Gateway & Route**: 0.0.0.0/0 → IGW  
- **Security Groups**
  - **Win/Kali SG**: SSH (22), RDP (3389), ICMP  
  - **Tools SG**: SSH (22), Splunk (8000/9997), Nessus (8834), ICMP  
- **EC2 Instances**
  1. **windows**: Windows Server 2019 (t3.small)  
  2. **kali**: Kali Linux (t3.small)  
  3. **security_tools**: Ubuntu 20.04 (t3.large)

---

## Prerequisites

- **AWS account** with EC2, VPC, IAM permissions  
- **AWS CLI** (run `aws configure`)  
- **Terraform** >= 1.5.0  
- **SSH client** (OpenSSH or PuTTY)  
- **RDP client** (Microsoft Remote Desktop)

---

## Repository Structure

```text
.
├── images/               # Architecture diagram
├── scripts/              # Post-launch scripts
│   ├── kali_setup.sh     # Kali user_data script
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

- Run `aws configure` to set credentials.
- Edit `terraform/variables.tf` or create `terraform/terraform.tfvars`:
  ```ini
  region                   = "us-east-1"
  key_name_prefix          = "lab-deployer"
  allowed_cidr             = "192.0.2.0/24"
  windows_instance_type    = "t3.small"
  kali_instance_type       = "t3.small"
  tools_instance_type      = "t3.large"
  ```

### 3. Deploy

```bash
terraform init
tf plan -out=lab.plan
terraform apply lab.plan
```

On success you’ll see outputs for key path and public IPs.

---

## Instance Configuration

### Kali Linux

```bash
ssh -i ../deployer_key.pem ubuntu@<KALI_PUBLIC_IP>
```

Kali is configured via `scripts/kali_setup.sh` (desktop + xrdp).

### Windows Server 2019

1. Retrieve Administrator password in AWS Console.
2. RDP to `RDP://<WINDOWS_PUBLIC_IP>`.

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

- UI: `http://<TOOLS_PUBLIC_IP>:8000`
- Forwarder port: 9997

### Tenable Nessus Essentials

```bash
wget -O nessus.deb "https://www.tenable.com/downloads/api/v2/pages/nessus/files/Nessus-10.3.0-debian6_amd64.deb"
sudo dpkg -i nessus.deb || sudo apt-get install -f -y
sudo systemctl enable --now nessusd
```

UI: `https://<TOOLS_PUBLIC_IP>:8834`

---

## Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

---

## Best Practices

- Least-privilege IAM
- Restrict SG ingress to your CIDR
- Rotate SSH keys regularly
- Enable CloudTrail & CloudWatch alerts

---

## Next Steps & Enhancements

- Modularize Terraform
- Remote state (S3 + DynamoDB)
- Integrate Ansible
- Add IDS/IPS (Suricata, Zeek)

---

## Resources

- AWS: [https://aws.amazon.com/documentation/](https://aws.amazon.com/documentation/)
- Terraform: [https://www.terraform.io/docs](https://www.terraform.io/docs)
- Splunk: [https://docs.splunk.com/](https://docs.splunk.com/)
- Nessus: [https://docs.tenable.com/nessus/](https://docs.tenable.com/nessus/)
- Kali: [https://www.kali.org/](https://www.kali.org/)
- Windows: [https://support.microsoft.com/windows](https://support.microsoft.com/windows)
