variable "region" {
    description = "AWS region to deploy resources"
    type        = string
    default     = "us-east-1"
}

variable "cidr_block" {
    description = "value for the CIDR block of the VPC"
    type        = string
    default = "10.0.0.0/16"
}
