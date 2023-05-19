variable "vpccidr_block" {
    description = "vpcid"
    type = string
    default = "10.0.0.0/24"
}

variable "subnetcidr_block" {
    description = "vpcid"
    type = string
    default = "10.0.0.0/24"
}

variable "name" {
    description = "sg-name"
    type = string
    default = "terraform-networking"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-gov-west-1"
}

variable "ingress_rules" {
    description = "list of port ranges for ingress rules"
    type = list(object({
       from_port   = number
       to_port     = number
       protocol    = string
       cidr_blocks = list(string)
}))
default = [ 
  {from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"]},
  {from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"]},
  {from_port = 8000, to_port = 9000, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"]},
 ]
}
variable "egress_rules" {
    description = "list of port ranges for ingress rules"
    type = list(object({
       from_port = number
       to_port   = number
       protocol    = string
       cidr_blocks = list(string)
}))
default = [ 
  {from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"]},
  {from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"]},
  {from_port = 8000, to_port = 9000, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"]},
 ]
}

