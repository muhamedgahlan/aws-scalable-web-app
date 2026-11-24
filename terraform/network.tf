resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# ---------- Subnets (3 tiers x 2 AZs) ----------
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-${count.index + 1}" }
}

resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.project_name}-private-app-${count.index + 1}" }
}

resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.project_name}-private-db-${count.index + 1}" }
}

# ---------- NAT ----------
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : 2
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip-${count.index + 1}" }
}

resource "aws_nat_gateway" "nat" {
  count         = var.single_nat_gateway ? 1 : 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${var.project_name}-nat-${count.index + 1}" }
  depends_on    = [aws_internet_gateway.igw]
}

# ---------- Route tables ----------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  count  = 2
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[var.single_nat_gateway ? 0 : count.index].id
  }
  tags = { Name = "${var.project_name}-app-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# DB tier: no route to the internet at all
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-db-rt" }
}

resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# ---------- NACL for the DB tier (stateless, extra layer) ----------
resource "aws_network_acl" "db" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.db[*].id
  tags       = { Name = "${var.project_name}-db-nacl" }
}

resource "aws_network_acl_rule" "db_in_mysql" {
  count          = 2
  network_acl_id = aws_network_acl.db.id
  rule_number    = 100 + count.index
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_subnet.app[count.index].cidr_block
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "db_out_ephemeral" {
  count          = 2
  network_acl_id = aws_network_acl.db.id
  rule_number    = 100 + count.index
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_subnet.app[count.index].cidr_block
  from_port      = 1024
  to_port        = 65535
}
