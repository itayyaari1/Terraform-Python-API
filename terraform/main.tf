# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group for API access
resource "aws_security_group" "api_sg" {
  name        = "python-api-sg"
  description = "Security group for Python API on EC2"

  # Inbound: Allow port 5000 from Terraform runner IP only
  ingress {
    description = "API access from Terraform runner"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  # Outbound: Allow all traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "python-api-sg"
  }
}

# EC2 Instance
resource "aws_instance" "api" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.api_sg.id]

  # User data script for Docker installation and container deployment
  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "python-api-instance"
  }
}

