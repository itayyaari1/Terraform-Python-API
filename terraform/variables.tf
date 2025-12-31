variable "my_ip" {
  description = "Your public IP address (for security group whitelist)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"  # Free tier eligible
}

variable "ami_id" {
  description = "AMI ID (optional, defaults to Ubuntu 22.04 LTS)"
  type        = string
  default     = ""
}

