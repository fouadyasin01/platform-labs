# AWS to Azure Service Mapping

The Azure implementation replicates the same three-tier architecture deployed on AWS.
The goal is to understand the equivalent Azure services and the key architectural
differences between the two cloud platforms.

| AWS Service | Azure Equivalent | Purpose | Key Difference |
|---|---|---|---|
| Amazon VPC | Azure Virtual Network (VNet) | Provides isolated networking, subnets, routing, and private connectivity. | AWS VPC is regional and uses route tables and security groups as core networking controls; Azure VNet uses subnet-based networking with NSGs and Azure-specific routing constructs. |
| Amazon EC2 | Azure Virtual Machines | Provides virtual machine compute for the web and application tiers. | Azure VMs integrate closely with Azure Managed Disks, Managed Identity, VM extensions, and Azure Resource Manager. |
| Application Load Balancer (ALB) | Azure Application Gateway | Provides Layer 7 HTTP/HTTPS load balancing for the application. | AWS ALB uses listeners and target groups, while Application Gateway uses frontend IPs, listeners, backend pools, and routing rules, with optional WAF capabilities. |
| Internal Application Load Balancer | Internal Azure Load Balancer | Provides private load balancing between the web and application tiers. | AWS uses an internal ALB with private access, while Azure uses an internal Load Balancer with a private frontend IP and backend pool. |
| Amazon RDS for PostgreSQL | Azure Database for PostgreSQL Flexible Server | Provides managed PostgreSQL without managing the database operating system. | RDS is an AWS managed database service with AWS-specific Multi-AZ capabilities, while Flexible Server provides Azure-native PostgreSQL deployment, networking, maintenance, and high-availability options. |
| Security Groups | Network Security Groups (NSGs) | Control network traffic between application tiers. | AWS security groups are stateful controls primarily associated with ENIs/resources; Azure NSGs can be associated with subnets and network interfaces. |
| NAT Gateway | Azure NAT Gateway | Provides controlled outbound Internet connectivity for private resources. | Both provide managed outbound NAT, but Azure NAT Gateway is associated with a subnet and provides outbound connectivity for resources in that subnet. |
| IAM Roles | Azure Managed Identities | Allows Azure resources to authenticate to supported Azure services without storing credentials in application code. | AWS IAM roles are part of AWS IAM and are assumed by AWS resources; Azure Managed Identities are identities managed through Microsoft Entra ID and assigned to Azure resources. |

## Three-Tier Architecture Mapping

The application tiers map as follows:

| AWS Tier | AWS Components | Azure Components |
|---|---|---|
| Network | VPC, subnets, route tables | VNet, subnets, route tables |
| Web | EC2 + Nginx | Azure VM + Nginx |
| Application | EC2 + Node.js | Azure VM + Node.js |
| Load Balancing | Application Load Balancer + Internal Application Load Balancer | Application Gateway + Internal Azure Load Balancer |
| Database | RDS PostgreSQL | PostgreSQL Flexible Server |
| Network Security | Security Groups | Network Security Groups |
| Outbound Connectivity | NAT Gateway | NAT Gateway |
| Identity | IAM Roles | Managed Identities |

## Architectural Flow

```text
Internet
    |
    v
Azure Application Gateway :80
    |
    v
Web Subnet
    |
    +-- Nginx VM :80
    +-- Nginx VM :80
    |
    v
Internal Azure Load Balancer :80
    |
    v
App Subnet
    |
    +-- Node.js VM :3000
    +-- Node.js VM :3000
    |
    v
Database Subnet
    |
    v
Azure Database for PostgreSQL Flexible Server :5432