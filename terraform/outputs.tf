output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.kubectl_host.id
}

output "public_ip" {
  description = "Public IP address — use this to SSH"
  value       = aws_instance.kubectl_host.public_ip
}

output "public_dns" {
  description = "Public DNS hostname"
  value       = aws_instance.kubectl_host.public_dns
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i C:/Users/rajak/.ssh/my-ec2-key ec2-user@${aws_instance.kubectl_host.public_ip}"
}

output "ami_used" {
  description = "AMI ID that was selected"
  value       = data.aws_ami.amazon_linux_2023.id
}