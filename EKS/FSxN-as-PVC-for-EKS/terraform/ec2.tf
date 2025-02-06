#
# Gets the latest version of Ubuntu.
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "eks_jump_server" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.large"
  associate_public_ip_address = true
  vpc_security_group_ids = [module.eks.cluster_primary_security_group_id, aws_security_group.eks_jump_server.id]
  subnet_id       =  module.vpc.public_subnets[0]
  key_name        = var.key_pair_name
  user_data       = <<EOF
#!/bin/bash
#
ARCH=amd64
#
# Get the system up to date:
apt update
apt upgrade -y
#
# Install some required tools:
apt install -y jq unzip
#
# Install the aws cli:
cd /var/tmp
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws
#
# Install kubectl:
curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$ARCH/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
#
# Install helm:
snap install helm --classic
#
# Install eksctl:
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin
#
# Install the eks samples repo into the ubuntu home directory:
cd /home/ubuntu
git clone https://github.com/NetApp/FSx-ONTAP-samples-scripts.git
chown -R ubuntu:ubuntu FSx-ONTAP-samples-scripts
EOF

  tags = {
    Name = "eks_jump_server"
  }
}
