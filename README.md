# AWS Certified Solutions Architect - Associate (SAA-C03) Practical Labs

Welcome to this repository of practical exercises designed to prepare for the **AWS Certified Solutions Architect - Associate (SAA-C03)** exam. 

The goal of this repository is to systematically build hands-on experience by covering the fundamental architectural domains outlined by AWS.

![AWS Certified Solutions Architect - Associate Badge](https://d1.awsstatic.com/training-and-certification/certification-badges/AWS-Certified-Solutions-Architect-Associate_badge.3419559c682629072f1eb968d59dea0741772c0f.png)

## Exam Domains Covered

The practical exercises in this repository align with the official exam domains:

1. **Design Secure Architectures (30%)**
2. **Design Resilient Architectures (26%)**
3. **Design High-Performing Architectures (24%)**
4. **Design Cost-Optimized Architectures (20%)**

---

## 📚 Completed Labs & Exercises

### Domain 1: Design Secure Architectures
- [**1. Creating a Network for a Web Application**](./1-creating-a-network-for-a-web-application)
  *Design and build an Amazon Virtual Private Cloud (VPC) with public and private subnets across multiple Availability Zones, implementing secure routing and a publicly accessible EC2 web server.*

*(More exercises will be added as I progress through my continuous learning journey!)*

## 🛠️ Repository Best Practices

All practical exercises in this repository aim to follow industry best practices:
- **Infrastructure as Code (IaC)**: Deployments are handled using HashiCorp **Terraform** with modular structures (`main.tf`, `variables.tf`, `outputs.tf`).
- **AWS CLI Alternatives**: Imperative Bash scripts are included as alternative deployment methods to understand the raw AWS API interactions.
- **Security First**: Following the Principle of Least Privilege for Security Groups, IAM Roles, and Subnet routing.
- **Reproducibility**: Labs include structured destruction scripts (`destroy.sh` or Terraform commands) to avoid incurring unexpected costs.

## Prerequisites to Follow Along

1. An active [AWS Account](https://aws.amazon.com/free/).
2. The [AWS CLI](https://aws.amazon.com/cli/) installed and configured (`aws configure`).
3. [Terraform](https://www.terraform.io/downloads.html) installed locally.
4. Basic understanding of Bash and Command-Line interfaces.

Happy Building in the Cloud! ☁️
