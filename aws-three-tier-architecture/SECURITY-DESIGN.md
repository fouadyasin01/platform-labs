# Security Design

## 1. Network Security and Traffic Flow

The architecture separates the application into web, application, and database tiers.
Each tier is protected by a dedicated security group and placed in the appropriate
subnets.

### Traffic Between Tiers

| Source | Destination | Port | Protocol | Purpose |
|---|---|---:|---|---|
| Internet | Public ALB | 80 | HTTP | Public application access |
| Internet | Public ALB | 443 | HTTPS | Secure public application access |
| Public ALB | Web EC2 | 80 | HTTP | Deliver frontend traffic to Nginx |
| Web EC2 | Internal ALB | 80 | HTTP | Forward `/api/` requests to the application tier |
| Internal ALB | App EC2 | 3000 | HTTP | Forward API requests to Node.js |
| App EC2 | RDS PostgreSQL | 5432 | PostgreSQL | Database communication |

### Security Group Rules

#### Public ALB

The public Application Load Balancer accepts:

- TCP port `80` from the Internet.
- TCP port `443` from the Internet.

The public ALB is the only internet-facing application component.

#### Web Tier

The Nginx EC2 instances accept:

- TCP port `80` only from the Public ALB security group.

The web servers are located in private subnets and cannot be accessed
directly from the Internet.

#### Internal Application ALB

The internal ALB accepts:

- TCP port `80` only from the Web Tier security group.

The internal ALB is not internet-facing. It provides a stable endpoint for
the Nginx servers while distributing requests across the application servers.

#### Application Tier

The Node.js EC2 instances accept:

- TCP port `3000` only from the Internal Application ALB security group.

The application servers are not directly exposed to the Internet or to the
web servers.

#### Database Tier

The PostgreSQL RDS instance accepts:

- TCP port `5432` only from the Application Tier security group.

The database is deployed in isolated database subnets and is not publicly
accessible.

This security-group design follows the principle of least privilege by
allowing each tier to communicate only with the next required tier.

---

## 2. Database Credential Management

The PostgreSQL database uses the following application configuration:

- Database name: `appdb`
- Database username: `appadmin`
- Database password: provided through the Terraform `database_password`
  variable.

The password is represented as a sensitive Terraform variable:

```hcl
variable "database_password" {
  description = "Master password for the PostgreSQL database"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!" # Change this to a secure password in production
}
```

The default password is provided only as a placeholder for this assignment
and must be replaced with a secure password in production.

The actual Terraform variable file containing the deployment password must
not be committed to Git.

For a production deployment, the password should be stored in a dedicated
secret-management service such as AWS Secrets Manager instead of using a
default value in Terraform.

---

## 3. Encryption at Rest

The PostgreSQL RDS instance uses encryption at rest:

```hcl
storage_encrypted = true
```

This encrypts the database storage and protects data stored on the RDS
instance.

For a production environment, AWS Key Management Service (AWS KMS) can be
used with a customer-managed key to provide additional control over
encryption keys, access policies, and key rotation.

---

## 4. Encryption in Transit

The Node.js application connects to PostgreSQL using SSL/TLS.

The application enables PostgreSQL SSL through:

```text
DB_SSL=true
```

This protects data transmitted between the application tier and the
PostgreSQL database.

For client-to-application traffic, HTTPS should be enabled on the public
Application Load Balancer using an AWS Certificate Manager (ACM)
certificate.

The public ALB should:

- Listen on HTTPS port `443`.
- Redirect HTTP port `80` requests to HTTPS.
- Terminate TLS at the ALB.

The resulting production traffic flow is:

```text
Internet
   |
   | HTTPS :443
   v
Public ALB
   |
   | HTTP :80
   v
Nginx Web Tier
   |
   | HTTP :80
   v
Internal ALB
   |
   | HTTP :3000
   v
Node.js Application Tier
   |
   | TLS :5432
   v
PostgreSQL RDS
```

This design protects sensitive database traffic in transit while allowing
the public ALB to provide secure HTTPS access to external clients.
