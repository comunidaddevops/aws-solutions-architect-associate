output "web_public_ip" {
  value       = aws_instance.web.public_ip
  description = "The public IP to access the web application"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the created VPC"
}
