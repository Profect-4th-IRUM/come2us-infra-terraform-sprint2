variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDRs"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs"
}

variable "enable_nat" {
  type        = bool
  description = "Enable NAT Gateway"
  default     = true
}

variable "prefix" {
  type        = string
  description = "Prefix for resource names"
  default     = "come2us"
}

variable "db_subnet_cidrs" {
  type = list(string)
  description = "Private subnet CIDRs for RDS"
}
