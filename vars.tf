# VARIABLES TERRAFORM
variable "instance_type" {
  default = "c5.large"
}

variable "ami" {
  default = "ami-0985b5a5ed84b9c36"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "key_name" {
  default = "terraform"
}

variable "key_path" {
  default = "./terraform.pem"
}

variable "security_group" {
  default = "terraform-security-group"
}

variable "tag_name_nodejs" {
  default = "my-ec2-nodejs"
}

variable "tag_name_mongo" {
  default = "my-ec2-mongodb"
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
  default     = "vpc-03ddae115c1c99ea4"
}

# variable "vpc_id2" {
#   description = "ID de la VPC-2"
#   type        = string
#   default     = "vpc-02814e15f57ba19e7"
# }

# variable "subnet_id1" {
#   description = "ID de la SUBNET 1"
#   type        = string
#   default     = "subnet-09c5820088097ac0e"
# }

# variable "subnet_id2" {
#   description = "ID de la SUBNET 2"
#   type        = string
#   default     = "subnet-03e6935872d4b98c7"
# }