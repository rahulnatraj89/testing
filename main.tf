provider "aws" {
    region = var.region 
}
resource "aws_vpc" "usacvpc" {
  name =  var.name
  cidr_block = var.vpccidr_block
  instance_tenancy = var.instance_tenancy
  enable_dns_support = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
  dhcp_options_domain_name_servers = var.dhcp_options_domain_name_servers
  dhcp_options_domain_name = var.dhcp_options_domain_name
  main_network_acl = true

  tags = {
    name = "new-vpc"
  } 
}
resource "aws_subnet" "usacsubnet" {
  name = var.name
  vpc_id = aws_vpc.usacvpc.id
  cidr_block = var.subnetcidr_block
  availability_zone = var.availability_zone

  tags = {
    name = "new-subnet"
  }
}
resource "aws_internet_gateway" "usacigw" {
  name  =  var.name
  vpc_id = aws_vpc.usacvpc.id
  tags = {
    name = "new-igw"
  }
}
resource "aws_vpc_attachment" "usacigwattachment" {
  vpc_id = aws_vpc.usacvpc.id
  internet_gateway_id = aws_internet_gateway.usacigw.id
}
resource "aws_route_table" "usacroutetable" {
  name = var.name
  vpc_id = aws_vpc.usacvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.usacigw.id
  }
  tags = {
    name  = "usac-route-table"
  }
}
resource "aws_route_table_association" "usacroutetableassociation" {
  subnet_id = aws_subnet.usacsubnet.id
  route_table_id = aws_route_table.usacroutetable.id
}

resource "aws_security_group" "usac-sg" {
  name = var.name
  description = "security group for dev"
  vpc_id = aws_vpc.usacvpc.id

   dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port  
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
   }
   dynamic "egress" {
     for_each = var.egress_rules
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
   }
    tags = {
     name  =  "usac-security-group"
   }
}   

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  providers = aws.primary
  count = length(var.buckets)
  bucket = var.buckets[count.index]
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  versioning = {
    enabled = true
}
  force_destroy = true
server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm ="AES256"
      }
    }
}
tags = merge(var.tags,{
    Name = "${var.buckets[count.index]}"
  })
}
data "aws_iam_policy_document" "secondary" {
  provider = aws.secondary
  count = length(var.buckets)
  name = "${var.buckets[count.index]}" 
  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]
    resources = ["${aws_s3_bucket.secondary.arn}/*"]
  }
}
data "aws_iam_policy_document" "s3-assume-role" {
  provider = aws.primary
  count = length(var.buckets)
  name = "${var.buckets[count.index]}"
  statement {
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_s3_bucket_replication_configuration" "primary" {
  provider = aws.primary
  count = length(var.buckets)
  name = "${var.buckets[count.index]}"
  depends_on = [aws_s3_bucket_versioning.primary]
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.bucket
  rule {
    id = aws_s3_bucket.secondary.bucket
    filter {} 
    status = "Enabled"
    delete_marker_replication {
      status = "Enabled"
    }
    destination {
      bucket = aws_s3_bucket.secondary.arn
    }
  }
}
data "aws_iam_policy_document" "primary" {
  provider = aws.primary
  count = length(var.buckets)
  name = "${var.buckets[count.index]}"
  statement {
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]
    resources = ["arn:aws-us-gov:s3:::${var.primary_name}"]
  }
  statement {
    actions = [
      "s3:GetObjectVersion",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["arn:aws-us-gov:s3:::${var.primary_name}/*"]
  }
}
resource "aws_iam_role" "replication" {
  provider = aws.primary
  count = length(var.buckets)
  name = "${var.buckets[count.index]}"
  #name               = "s3-${var.primary_name}-replication"
  assume_role_policy = data.aws_iam_policy_document.s3-assume-role.json
}
resource "aws_iam_role_policy" "replication-primary" {
  provider = aws.primary
  count = length(var.buckets)
  name = "${var.buckets[count.index]}"
  name   = "primary"
  role   = aws_iam_role.replication.name
  policy = data.aws_iam_policy_document.primary.json
}
resource "aws_iam_role_policy" "replication-secondary" {
  provider = aws.primary
  count = length(var.buckets)
  name = "${var.buckets[count.index]}"
  name   = "secondary"
  role   = aws_iam_role.replication.name
  policy = data.aws_iam_policy_document.secondary.json
}

