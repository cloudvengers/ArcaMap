resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = { Name = "arcamap-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  for_each = {
    "ap-northeast-2a" = "10.0.1.0/24"
    "ap-northeast-2c" = "10.0.2.0/24"
  }

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = { Name = "arcamap-public-${each.key}" }
}

resource "aws_subnet" "api" {
  for_each = {
    "ap-northeast-2a" = "10.0.11.0/24"
    "ap-northeast-2c" = "10.0.12.0/24"
  }

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = { Name = "arcamap-api-${each.key}" }
}

resource "aws_subnet" "database" {
  for_each = {
    "ap-northeast-2a" = "10.0.21.0/24"
    "ap-northeast-2c" = "10.0.22.0/24"
  }

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = { Name = "arcamap-database-${each.key}" }
}

resource "aws_eip" "nat" {
  for_each = aws_subnet.public

  domain = "vpc"
}

resource "aws_nat_gateway" "public" {
  for_each = aws_subnet.public

  availability_mode = "zonal"
  connectivity_type = "public"
  subnet_id         = aws_subnet.public[each.key].id
  allocation_id     = aws_eip.nat[each.key].id

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table" "api" {
  for_each = aws_subnet.api

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.public[each.key].id
  }
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id
  route  = []
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "api" {
  for_each = aws_subnet.api

  subnet_id      = each.value.id
  route_table_id = aws_route_table.api[each.key].id
}

resource "aws_route_table_association" "database" {
  for_each = aws_subnet.database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database.id
}
