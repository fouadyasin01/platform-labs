# AWS Three-Tier Architecture

![AWS Three-Tier Architecture](docs/architecture-diagram.png)

## Architecture Overview

The application is deployed in an AWS VPC spanning two Availability Zones
for high availability and network isolation.

### Network Layout

| Tier | AZ1 | AZ2 |
|---|---|---|
| Public | 10.0.1.0/24 | 10.0.2.0/24 |
| Web | 10.0.11.0/24 | 10.0.12.0/24 |
| Application | 10.0.21.0/24 | 10.0.22.0/24 |
| Database | 10.0.31.0/24 | 10.0.32.0/24 |

### Traffic Flow

Internet → Public ALB → Nginx Web Tier → Internal ALB → Node.js Application Tier → PostgreSQL RDS

- Public ALB receives external traffic.
- Nginx EC2 instances run in private web subnets.
- The internal ALB distributes API traffic to the Node.js instances.
- Node.js connects to PostgreSQL on port `5432`.
- RDS is deployed in isolated database subnets with Multi-AZ enabled.
- NAT Gateways provide outbound Internet access for private tiers.

### Availability and Isolation

The architecture spans two Availability Zones. Each tier is separated into
dedicated subnets, while security groups restrict traffic between tiers.
The database tier has no Internet route and is not publicly accessible.