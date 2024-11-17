variable "key_name" {
  description = "Name of the AWS key pair to use for EC2 instances"
  type        = string
}

variable "app_private_ips" {
  description = "List of private IPs of application instances"
  type        = list(string)
}

variable "custom_vpc_cidr" {
  type = string
}

variable "peering_connection_id" {
  type = string
}
