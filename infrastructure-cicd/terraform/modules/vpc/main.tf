# =============================================================================
# modules/vpc — Production VPC with public + private subnets across 3 AZs
#
# Topology:
#   - 1 VPC, /16 CIDR
#   - 3 AZs (us-west-2a/b/c)
#   - 3 public subnets  (one per AZ) — host the NAT and any public ALBs
#   - 3 private subnets (one per AZ) — host EKS nodes and RDS
#   - 1 Internet Gateway (public-subnet egress)
#   - 1 NAT Gateway     (private-subnet egress) — single NAT for cost
#
# Single NAT trade-off:
#   - Cost: 1x NAT (~$32/mo) vs 3x NAT (~$96/mo)
#   - Risk: if that AZ fails, all private subnets lose internet egress.
#   - Production at a real Bay Area startup: 1 NAT per AZ. For portfolio
#     scope, this trade-off is defensible — call it out explicitly in
#     interviews ("I chose single-NAT for cost; here's what I'd change at
#     scale and the AZ-failure blast radius today").
#
# Why public/private split:
#   EKS worker nodes have no public IPs (private subnets). They reach the
#   internet via the NAT for: pulling images outside ECR, calling external
#   APIs. Inbound traffic comes through ALBs in public subnets via the AWS
#   Load Balancer Controller.
# =============================================================================

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Required for EKS — pods need internal DNS to resolve service names.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway — public subnet egress
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# -----------------------------------------------------------------------------
# Subnets — for_each over the AZ list (not count, per CLAUDE.md)
#
# Using for_each with stable keys (AZ names) means: removing or reordering
# AZs in var.azs doesn't recreate the other subnets. With count, removing
# the middle item shifts every later subnet's index, forcing recreation
# and likely an outage.
# -----------------------------------------------------------------------------

# Public subnets — one per AZ. /20 = ~4000 IPs each.
resource "aws_subnet" "public" {
  for_each = { for idx, az in var.azs : az => idx }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key

  # Carves the VPC /16 into /20s. Public subnets get indices 0,1,2.
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, each.value)
  map_public_ip_on_launch = true # required for NAT and public LBs

  tags = {
    Name = "${var.name_prefix}-public-${each.key}"

    # EKS subnet discovery tags — without these, the AWS Load Balancer
    # Controller can't find which subnets to place ALBs in.
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/elb"                        = "1"
  }
}

# Private subnets — one per AZ. Indices 8,9,10 (gap avoids overlap with public).
resource "aws_subnet" "private" {
  for_each = { for idx, az in var.azs : az => idx }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, each.value + 8)

  tags = {
    Name = "${var.name_prefix}-private-${each.key}"

    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    # internal-elb tag = "place INTERNAL load balancers here".
    # Public ALBs use the public subnets tagged role/elb=1 above.
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# -----------------------------------------------------------------------------
# NAT Gateway — private-subnet egress to the internet
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id

  # First public subnet by AZ name (the for_each map iterates in sorted order).
  subnet_id = values(aws_subnet.public)[0].id

  tags = {
    Name = "${var.name_prefix}-nat"
  }

  # Explicit IGW dependency — implicit via the route table would also work,
  # but explicit makes the ordering obvious to anyone reading the file.
  depends_on = [aws_internet_gateway.this]
}

# -----------------------------------------------------------------------------
# Route tables
# -----------------------------------------------------------------------------

# Public route table — sends 0.0.0.0/0 to the IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private route table — sends 0.0.0.0/0 to the NAT.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
