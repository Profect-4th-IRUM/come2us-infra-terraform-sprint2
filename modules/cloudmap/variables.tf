variable "prefix" {
  description = "Prefix for namespace"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Cloud Map namespace"
  type        = string
}

variable "services" {
  description = "Map of Cloud Map services to create"
  type        = map(any)
}
