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

variable "github_repo" {
  description = "GitHub repository URL (e.g., https://github.com/username/repo.git)"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token for private repositories"
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "Optional API key for POST /update endpoint authentication (leave empty to disable auth)"
  type        = string
  default     = ""
  sensitive   = true
}

