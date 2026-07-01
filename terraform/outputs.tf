output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP address for the EC2 instance."
  value       = aws_instance.web.public_ip
}

output "instance_url" {
  description = "HTTP URL for the demo Nginx page."
  value       = "http://${aws_instance.web.public_ip}"
}
