output "alb_dns" { value = module.alb.dns_name }
output "jenkins_private_ip" { value = module.jenkins.private_ip }

output "bastion_public_ip" {
  value = module.bastion.public_ip
}

output "bastion_ssh" {
  value = module.bastion.ssh_command
}
