# Provider: tells Terraform we're using AWS
provider "aws" {
  region = var.aws_region
}

# Upload your public key to AWS so EC2 can use it
resource "aws_key_pair" "my_key" {
  key_name   = "my-ec2-key"
  public_key = file("C:/Users/rajak/.ssh/my-ec2-key.pub")

  # If key already exists, import it instead of failing
  lifecycle {
    ignore_changes = [public_key]
  }
}

# VPC — use the default one (already exists in every AWS account)
data "aws_vpc" "default" {
  default = true
}

# Get the first available public subnet in the default VPC
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group — allows SSH in, everything out
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-kubectl-sg"
  description = "Allow SSH access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-kubectl-sg"
  }

  # If SG already exists, don't fail
  lifecycle {
    ignore_changes = [name]
  }
}

# Fetch the latest Amazon Linux 2023 AMI automatically
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.18-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# The EC2 instance itself
resource "aws_instance" "kubectl_host" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.my_key.key_name
  subnet_id                   = tolist(data.aws_subnets.public.ids)[0]
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  # Install kubectl + eksctl automatically on first boot
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    dnf update -y

    # Install kubectl (latest stable)
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl

    # Install eksctl
    curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
    tar -xzf eksctl_Linux_amd64.tar.gz
    mv eksctl /usr/local/bin/
    rm eksctl_Linux_amd64.tar.gz

    # Install useful tools
    dnf install -y git vim jq

    # Configure AWS CLI default region
    mkdir -p /home/ec2-user/.aws
    echo "[default]" > /home/ec2-user/.aws/config
    echo "region = us-east-1" >> /home/ec2-user/.aws/config
    chown -R ec2-user:ec2-user /home/ec2-user/.aws

    echo "kubectl: $(kubectl version --client --short 2>/dev/null)" >> /var/log/user-data-complete.log
    echo "eksctl: $(eksctl version)" >> /var/log/user-data-complete.log
    echo "Setup complete!" >> /var/log/user-data-complete.log
  EOF

  tags = {
    Name        = "kubectl-host"
    Environment = "learning"
    ManagedBy   = "terraform"
  }
}