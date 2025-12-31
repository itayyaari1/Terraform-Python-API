output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.api.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.api.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.api_sg.id
}

