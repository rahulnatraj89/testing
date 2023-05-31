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
  
resource "aws_iam_user" "bucket_user" {
    count = length(var.buckets)
    name = "${var.buckets[count.index]}"    
  }
  resource "aws_iam_policy" "bucket_policy" { 
    count = length(var.buckets)
    name = "${var.buckets[count.index]}" 
    policy = jsonencode(
      {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "arn:aws-us-gov:s3:::${var.buckets[count.index]}/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets"
            ],
            "Resource": "arn:aws-us-gov:s3:::${var.buckets[count.index]}/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws-us-gov:s3:::${var.buckets[count.index]}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion"
            ],
            "Resource": "arn:aws-us-gov:s3:::${var.buckets[count.index]}/*"
        }
    ]
}
    )
    
  }
  resource "aws_iam_user_policy_attachment" "bucket_policy_attachment" {
    count = length(var.buckets)
    user = aws_iam_user.bucket_user[count.index].name
    policy_arn = aws_iam_policy.bucket_policy[count.index].arn   
  }

  resource "aws_s3_bucket_policy" "s3_bucket" {
    count = length(var.buckets)
    bucket = var.buckets[count.index]
    policy = jsonencode({
    "Version": "2012-10-17",
    "Id": "Policy1643297892890",
    "Statement": [
        {
            "Sid": "Stmt1643297888916",
            "Effect": "Allow",
            "Principal": {
                "AWS":  "arn:aws-us-gov:iam::${var.id}:user/${aws_iam_user.bucket_user[count.index].name}"
            },
            "Action": "s3:*",
            "Resource": "arn:aws-us-gov:s3:::${var.buckets[count.index]}"
        }
    ]
})
}
