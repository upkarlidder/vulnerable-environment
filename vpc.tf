resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${local.prefix.value}-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${local.prefix.value}-gw"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnets("10.0.0.0/16", 8, 8)[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.prefix.value}-subnet-${count.index}"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id     = aws_internet_gateway.gw.id
    nat_gateway_id = "<nat-gateway-id>"
  }

  tags = {
    Name = "${local.prefix.value}-public-route"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}

resource "aws_flow_log" "vpc" {
  vpc_id          = "${aws_vpc.vpc.id}"
  iam_role_arn    = "<iam_role_arn>"
  log_destination = "${aws_s3_bucket.vpc.arn}"
  traffic_type    = "ALL"

  tags = {
    GeneratedBy      = "Accurics"
    ParentResourceId = "aws_vpc.vpc"
  }
}
resource "aws_s3_bucket" "vpc" {
  bucket        = "vpc_flow_log_s3_bucket"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled    = true
    mfa_delete = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
resource "aws_s3_bucket_policy" "vpc" {
  bucket = "${aws_s3_bucket.vpc.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "vpc-restrict-access-to-users-or-roles",
      "Effect": "Allow",
      "Principal": [
        {
          "AWS": [
            <principal_arn>
          ]
        }
      ],
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.vpc.id}/*"
    }
  ]
}
POLICY
}