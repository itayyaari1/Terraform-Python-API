variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "my_ip" {
  description = "IP address of the machine running Terraform (for security group whitelist)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for Amazon Linux 2 (leave empty to use latest)"
  type        = string
  default     = ""
}

