
variable "instance_type" {
  type        = string
  description = "The type of instance to launch"
}
variable "key_name" {
  type        = string
  }

  variable "region" {
  type        = string
  description = "The AWS region to launch VPC"
  default     = "us.east.1"
}

variable "cidr" {
  type        = string
  description = "The CIDR of the VPC."
}

variable "public_subnet" {
  type        = string
  description = "The public subnet to create."
}
variable "private_subnet" {
  type        = string
  description = "The public subnet to create."
}