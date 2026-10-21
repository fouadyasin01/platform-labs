resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.project_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_eip" "nat" {
  count = var.enable_nat_gateways ? length(aws_subnet.public) : 0

  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateways ? length(aws_subnet.public) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "${var.project_name}-nat-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                              = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.karpenter_discovery_cluster_name

  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = length(aws_subnet.private)

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateways ? [1] : []

    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[count.index].id
    }
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}