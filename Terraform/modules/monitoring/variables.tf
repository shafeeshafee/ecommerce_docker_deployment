variable "key_name" {
  description = "Name of the AWS key pair to use for EC2 instances"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "app_private_ips" {
  description = "List of private IPs of application instances"
  type        = list(string)
}
