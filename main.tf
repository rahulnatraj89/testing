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
#######variables.tf
module "C1B-Workloads-BankApp-UAT-01" {
  source = "./modules/aft-account-request"

  control_tower_parameters = {
    AccountEmail              = "aws.bnk.app.uat01@creditone.com"
    AccountName               = "C1B-Workloads-BankApp-UAT-01"
    ManagedOrganizationalUnit = "Staging"
    SSOUserEmail              = "aws.bnk.app.uat01@creditone.com"
    SSOUserFirstName          = "C1B-Workloads-BankApp-UAT-01"
    SSOUserLastName           = "Creditone"
  }

  account_tags = {
      "c1b:BusinessUnit"       = "IT"
      "c1b:CostCenter"         = "0320"
      "c1b:Department"         = "Cloud Infrastructure"
      "c1b:Owner"              = "Cloud_Operations_Team@creditone.com"
      "c1b:ContactDistroEmail" = "Cloud_Operations_Team@creditone.com"
      "c1b:Environment"        = "UA"
  }

  change_management_parameters = {
    change_requested_by = "Cloud Infrastructure"
    change_reason       = "Workloads-BankApp-UAT-01"
  }

  custom_fields = {
    group = "Workloads-BankApp-UAT-01"
  }

  account_customizations_name = "C1B-Workloads-BankApp-UAT-01"
}
#######ddb.tf
    resource "aws_dynamodb_table_item" "account-request" {
  table_name = var.account-request-table
  hash_key   = var.account-request-table-hash

  item = jsonencode({
    id = { S = lookup(var.control_tower_parameters, "AccountEmail") }
    control_tower_parameters = { M = {
      AccountEmail              = { S = lookup(var.control_tower_parameters, "AccountEmail") }
      AccountName               = { S = lookup(var.control_tower_parameters, "AccountName") }
      ManagedOrganizationalUnit = { S = lookup(var.control_tower_parameters, "ManagedOrganizationalUnit") }
      SSOUserEmail              = { S = lookup(var.control_tower_parameters, "SSOUserEmail") }
      SSOUserFirstName          = { S = lookup(var.control_tower_parameters, "SSOUserFirstName") }
      SSOUserLastName           = { S = lookup(var.control_tower_parameters, "SSOUserLastName") }
      }
    }
    change_management_parameters = { M = {
      change_reason       = { S = lookup(var.change_management_parameters, "change_reason") }
      change_requested_by = { S = lookup(var.change_management_parameters, "change_requested_by") }
      }
    }
    account_tags                = { S = jsonencode(var.account_tags) }
    account_customizations_name = { S = var.account_customizations_name }
    custom_fields               = { S = jsonencode(var.custom_fields) }
  })
}
    
    
    #######variables.tf
variable "account-request-table" {
  type        = string
  description = "name of account-request-table"
  default     = "aft-request"
}

variable "account-request-table-hash" {
  type        = string
  description = "name of account-request-table hash key"
  default     = "id"
}

variable "control_tower_parameters" {
  type = object({
    AccountEmail              = string
    AccountName               = string
    ManagedOrganizationalUnit = string
    SSOUserEmail              = string
    SSOUserFirstName          = string
    SSOUserLastName           = string
  })
}

variable "change_management_parameters" {
  type = object({
    change_requested_by = string
    change_reason       = string
  })
}

variable "account_tags" {
  type        = map(any)
  description = "map of account-level tags"
}

variable "custom_fields" {
  type        = map(any)
  description = "map of custom fields defined by the customer"
  default     = {}
}

variable "account_customizations_name" {
  type        = string
  default     = null
  description = "The name of the account customizations to apply"
}
    
    
#######main
    account id creation
    locals {
  environment_prefix = "${var.platform}-${var.platform_half}-${var.environment}"
}

module "vpc-module" {
  source  = "app.terraform.io/creditonebank/vpc-module/aws"
  version = "1.1.6"
  name    = "${local.environment_prefix}-vpc"
  cidr    = var.vpc_cidr

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = false
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  transit_gateway_id = "tgw-0473c470df70bb9bf"

  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  map_public_ip_on_launch = false
   private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
    
    
    main.tf
    
    output "account_id" {
  value = var.account_id
}

output "private_subnets" {
  value = module.vpc-module.private_subnets
}

output "platform" {
  value = var.platform
}

output "platform_half" {
  value = var.platform_half
}

output "environment" {
  value = var.environment
}

output "vpc_id" {
  value = module.vpc-module.vpc_id
}

output "project_name" {
  value = var.project_name
}

output "environment_tag" {
  value = var.environment_tag
}
      
      variable "platform" {}
variable "platform_half" {}
variable "environment" {}
variable "vpc_cidr" {}
variable "public_subnets" {}
variable "private_subnets" {}
variable "account_id" {}
variable "workspace_name" {}
variable "project_name" {}
variable "environment_tag" {}
      
      #####vpc modules
      
      ocals {
  max_subnet_length = max(
    length(var.private_subnets),
    length(var.elasticache_subnets),
    length(var.database_subnets),
    length(var.redshift_subnets),
  )
  nat_gateway_count = var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.max_subnet_length

  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = element(
    concat(
      aws_vpc_ipv4_cidr_block_association.this.*.vpc_id,
      aws_vpc.this.*.id,
      [""],
    ),
    0,
  )
}
      
      
      ####


