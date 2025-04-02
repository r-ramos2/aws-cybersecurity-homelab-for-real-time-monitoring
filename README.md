# Scalable AWS Cybersecurity Lab for Real-Time Monitoring and Vulnerability Management

## Table of Contents  

1. [Introduction](#introduction)  
2. [Lab Architecture Overview](#lab-architecture-overview)  
3. [Prerequisites](#prerequisites)  
4. [Setting Up the Environment](#setting-up-the-environment)  
   - [AWS Account Configuration](#aws-account-configuration)  
   - [Provisioning Infrastructure with Terraform](#provisioning-infrastructure-with-terraform)  
5. [Configuring the Instances](#configuring-the-instances)  
   - [Kali Linux Setup](#kali-linux-setup)  
   - [Windows 10 Workstation Setup](#windows-10-workstation-setup)  
   - [Security Tools Box (Ubuntu) Setup](#security-tools-box-ubuntu-setup)  
6. [Installing and Configuring Tools](#installing-and-configuring-tools)  
   - [Splunk Enterprise](#splunk-enterprise)  
   - [Universal Forwarder for Windows Logs](#universal-forwarder-for-windows-logs)  
   - [Tenable Nessus Essentials](#tenable-nessus-essentials)  
7. [Best Practices and Security Measures](#best-practices-and-security-measures)  
8. [Potential Enhancements and Next Steps](#potential-enhancements-and-next-steps)  
9. [Conclusion](#conclusion)  
10. [Resources](#resources)  

---

## Introduction  

This project demonstrates the creation of a cloud-based cybersecurity home lab on AWS. It consists of three core systems: a **Kali Linux instance** for penetration testing, a **Windows 10 instance** serving as a target for attacks, and a **Security Tools Box (Ubuntu)** hosting tools like **Splunk** and **Tenable Nessus**. The infrastructure is managed using **Terraform**, ensuring scalability, reproducibility, and adherence to security best practices.  

---

## Lab Architecture Overview  

### Components:  
- **Kali Linux**: A penetration testing platform for vulnerability assessments.  
- **Windows 10 Workstation**: The target system for simulating attacks.  
- **Security Tools Box (Ubuntu)**: Runs Splunk for log management and Tenable Nessus for vulnerability scanning.  

### Network Architecture:  
- **VPC**: Isolated environment for lab resources.  
- **Subnets**: Public subnet for accessible systems and private subnet for internal services.  
- **Security Groups**: Firewall rules control SSH, RDP, and HTTP/S traffic.  

<img width="872" alt="2 396430826-9bab234a-a197-4089-b8e5-62cdeb9e9ba1" src="https://github.com/user-attachments/assets/4b20576d-3fa6-4f0c-8b35-3ab63c32cde9" />

*Architecutre diagram*

---

## Prerequisites  

Before starting:  
- **AWS Account** with necessary permissions for EC2, VPC, S3, and IAM.  
- **Terraform** installed locally.  
- **SSH Client** (e.g., OpenSSH or PuTTY) and **RDP Client** for remote connections.  

---

## Setting Up the Environment  

### AWS Account Configuration  

1. Create a dedicated **IAM User** with programmatic access and permissions for EC2, VPC, S3, and IAM.  
2. Install and configure the **AWS CLI** with IAM user credentials.  

### Provisioning Infrastructure with Terraform  

1. Clone the repository containing the Terraform configuration files.  
2. Modify `variables.tf` to include your AWS settings (region, SSH key pair, etc.).  
3. Run these commands in your terminal to deploy the infrastructure:  
    ```bash  
    terraform init  
    terraform plan  
    terraform apply  
    ```  

---

## Configuring the Instances  

### Kali Linux Setup  

1. SSH into the Kali Linux instance:  
    ```bash  
    ssh -i your-key.pem ubuntu@<Kali-IP>  
    ```  
2. Install tools and enable RDP:  
    ```bash  
    sudo apt update && sudo apt upgrade -y  
    sudo apt install -y xrdp firefox  
    sudo systemctl enable --now xrdp  
    ```  
3. Create a user for RDP access:  
    ```bash  
    sudo adduser rdpuser  
    sudo usermod -aG sudo rdpuser  
    ```  

### Windows 10 Workstation Setup  

1. Decrypt the admin password and use an RDP client to connect to the instance.  
2. Disable the firewall temporarily for initial setup (via Windows Defender Firewall settings).  

### Security Tools Box (Ubuntu) Setup  

1. SSH into the Security Tools instance:  
    ```bash  
    ssh -i your-key.pem ubuntu@<Security-Tools-IP>  
    ```  
2. Update the system:  
    ```bash  
    sudo apt update && sudo apt upgrade -y  
    ```  

---

## Installing and Configuring Tools  

### Splunk Enterprise  

1. Install Splunk:  
    ```bash  
    wget -O splunk.deb https://download.splunk.com/releases/9.1.0/splunk.deb  
    sudo dpkg -i splunk.deb  
    sudo /opt/splunk/bin/splunk start  
    ```  
2. Configure log forwarding via Splunk’s **Settings > Forwarding and Receiving**.  

### Universal Forwarder for Windows Logs  

1. Install the **Splunk Universal Forwarder** on Windows 10.  
2. Configure the forwarder to send logs to the Splunk instance.  

### Tenable Nessus Essentials  

1. Install Nessus Essentials:  
    ```bash  
    wget -O nessus.deb https://www.tenable.com/downloads/nessus  
    sudo dpkg -i nessus.deb  
    sudo systemctl start nessusd  
    ```  
2. Complete the Nessus setup via its web interface.  

---

## Best Practices and Security Measures  

- **IAM Best Practices**: Implement least privilege and rotate credentials regularly.  
- **Security Groups**: Restrict SSH, RDP, and HTTP access to specific IPs.  
- **Key Management**: Rotate SSH keys periodically and use strong passwords.  
- **Logging**: Enable **CloudTrail** and **CloudWatch** for monitoring.  

---

## Potential Enhancements and Next Steps  

- **Automation**: Use **Ansible** to configure tools and systems.  
- **Intrusion Detection**: Add tools like **Snort** or **Suricata** for network monitoring.  
- **Containerization**: Simulate containerized environments using **Docker** or **Kubernetes**.  

---

## Conclusion  

This project showcases the design and deployment of a cloud-based cybersecurity lab on AWS. The lab integrates a secure VPC with three key components: a Kali Linux instance for penetration testing, a Windows 10 workstation for simulating attacks, and an Ubuntu server hosting security tools like Splunk and Nessus. Infrastructure is deployed with Terraform, following cloud security best practices. This lab serves as a scalable platform for practicing security operations, testing vulnerabilities, and deploying advanced monitoring solutions.  

---

## Resources  

- [AWS Documentation](https://aws.amazon.com/documentation/)  
- [Terraform Documentation](https://www.terraform.io/docs)  
- [Splunk Documentation](https://docs.splunk.com)  
- [Tenable Nessus Documentation](https://docs.tenable.com/nessus/)  
- [Kali Linux Official Site](https://www.kali.org/)  
- [Windows 10 Documentation](https://support.microsoft.com/en-us/windows)  
