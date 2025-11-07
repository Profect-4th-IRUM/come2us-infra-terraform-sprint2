output "public_ip" {
  value       = aws_instance.this.public_ip
  description = "Public IP of the Bastion host"
}

output "ssh_command" {
  value       = "ssh -i ${var.prefix}-key.pem ubuntu@${aws_instance.this.public_ip}"
  description = "SSH command to connect to Bastion"
}
