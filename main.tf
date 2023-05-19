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
     
