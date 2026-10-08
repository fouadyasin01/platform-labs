# Discover the Availability Zones available in the selected AWS region.
# The VPC is deployed across two AZs to provide high availability.
data "aws_availability_zones" "available" {
  state = "available"
}

# Create the VPC that provides the isolated network boundary
# for all three application tiers.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# =========================================================
# Public subnets
# =========================================================
# Public subnets host internet-facing infrastructure such as
# the public Application Load Balancer and NAT Gateways.
# Each subnet is placed in a different AZ for high availability.

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Tier = "public"
  }
}

# =========================================================
# Private web subnets
# =========================================================
# Private web subnets host the Nginx web tier.
# They are not directly reachable from the Internet.
# Outbound Internet access is provided through NAT Gateways.

resource "aws_subnet" "web" {
  count = 2

  vpc_id            = aws_vpc.this.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = var.web_subnet_cidrs[count.index]
  tags = {
    Name = "${var.project_name}-${var.environment}-web-${count.index + 1}"
    Tier = "web"
  }
}

# =========================================================
# Private application subnets
# =========================================================
# Private application subnets host the Node.js application tier.
# Application instances are never directly exposed to the Internet.
# They use NAT Gateways only for required outbound connections.

resource "aws_subnet" "app" {
  count = 2

  vpc_id            = aws_vpc.this.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = var.app_subnet_cidrs[count.index]
  tags = {
    Name = "${var.project_name}-${var.environment}-app-${count.index + 1}"
    Tier = "app"
  }
}

# =========================================================
# Isolated database subnets
# =========================================================
# Database subnets are dedicated to RDS PostgreSQL.
# They have no default route to the Internet or NAT Gateway,
# providing network-level isolation for the database tier.

resource "aws_subnet" "database" {
  count = 2

  vpc_id            = aws_vpc.this.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = var.database_subnet_cidrs[count.index]
  tags = {
    Name = "${var.project_name}-${var.environment}-database-${count.index + 1}"
    Tier = "database"
  }
}

# =========================================================
# Internet Gateway
# =========================================================
# Provides Internet connectivity for resources in public subnets.
# The public route tables use this gateway for outbound Internet traffic.

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# =========================================================
# Elastic IPs for NAT Gateways
# =========================================================
# Each NAT Gateway requires a stable public Elastic IP.
# One EIP is allocated per AZ so private workloads can use
# a NAT Gateway located in their own AZ.

resource "aws_eip" "nat" {
  count = 2

  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
  }
}

# =========================================================
# NAT Gateways
# =========================================================
# NAT Gateways allow private web and application instances
# to initiate outbound Internet connections without accepting
# inbound Internet traffic.
#
# A NAT Gateway is deployed in each AZ to avoid a single-AZ
# dependency and improve availability.

resource "aws_nat_gateway" "this" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  }
}

# =========================================================
# Public route tables
# =========================================================
# Public route tables provide Internet access through the
# Internet Gateway. Each public subnet uses the route table
# associated with its AZ.

resource "aws_route_table" "public" {
  count = 2

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt-${count.index + 1}"
  }
}

# Associate each public subnet with its corresponding
# public route table.
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

# =========================================================
# Private web route tables
# =========================================================
# Web-tier instances remain private but can initiate outbound
# connections through the NAT Gateway in the same AZ.
#
# Keeping the NAT Gateway in the same AZ avoids unnecessary
# cross-AZ traffic and improves fault isolation.

resource "aws_route_table" "web" {
  count = 2

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web-rt-${count.index + 1}"
  }
}

# Associate each private web subnet with its AZ-specific
# route table and NAT Gateway.
resource "aws_route_table_association" "web" {
  count = 2

  subnet_id      = aws_subnet.web[count.index].id
  route_table_id = aws_route_table.web[count.index].id
}

# =========================================================
# Private application route tables
# =========================================================
# Application instances remain private and use the NAT Gateway
# in their own AZ for outbound Internet access when required.

resource "aws_route_table" "app" {
  count = 2

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-rt-${count.index + 1}"
  }
}

# Associate each application subnet with its AZ-specific
# application route table.
resource "aws_route_table_association" "app" {
  count = 2

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# =========================================================
# Isolated database route tables
# =========================================================
# Database subnets intentionally have no default route.
# This prevents direct Internet and NAT-based outbound access.
#
# RDS will use these subnets through a DB subnet group, while
# security groups provide the required application-to-database
# connectivity on PostgreSQL port 5432.

resource "aws_route_table" "database" {
  count = 2

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.environment}-database-rt-${count.index + 1}"
  }
}

# Associate each database subnet with its isolated route table.
resource "aws_route_table_association" "database" {
  count = 2

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[count.index].id
}
