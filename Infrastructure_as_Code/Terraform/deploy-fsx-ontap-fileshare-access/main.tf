terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.44.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
  }

}

provider "aws" {
  region = var.aws_location

  default_tags {
    tags = {
      "creator" = var.creator_tag
    }
  }
}

module "fsxontap" {
  source = "./modules/fsxn"

  fsxn_password           = var.fsxn_password
  fsxn_deployment_type    = "SINGLE_AZ_1"
  fsxn_subnet_ids         = [aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id]
  fsxn_security_group_ids = [aws_security_group.sg-fsx.id]
  fsxn_volume_name_prefix = "${var.environment}_shares"

  ad = {
    domain_name              = "AD.FSXN.COM"
    administrators_group     = "FSXN Administrators"
    ou                       = "OU=FSXN,DC=AD,DC=FSXN,DC=com"
    service_account          = "fsxnadmin"
    service_account_password = var.ad_admin_password
    dns_ips                  = [module.ec2-ad.ip_address.private_ip]
  }
  creator_tag = var.creator_tag
}

module "vpn" {
  source             = "./modules/vpn"
  vpc_id             = aws_vpc.vpc.id
  vpn_cidr           = "10.100.0.0/22"
  public_subnet_id   = aws_subnet.public_subnet[0].id
  ca_crt             = file("${path.root}/modules/vpn/certs/ca.pem")
  client_cert        = file("${path.root}/modules/vpn/certs/client.fsxn.pem")
  client_private_key = file("${path.root}/modules/vpn/certs/client.fsxn.key")
  server_cert        = file("${path.root}/modules/vpn/certs/server.fsxn.pem")
  server_private_key = file("${path.root}/modules/vpn/certs/server.fsxn.key")
  depends_on         = [module.ec2-ad, module.fsxontap]
}

module "ec2-ad" {
  source                  = "./modules/ec2ad"
  ad_domain               = "ad.fsxn.com"
  ad_service_account      = "fsxnadmin"
  ad_service_account_pwd  = var.ad_admin_password
  ad_administrators_group = "FSXN ADMINISTRATORS"
  ec2_instance_key_pair   = var.ec2_instance_keypair
  ec2_subnet_id           = aws_subnet.private_subnet[0].id
  ec2_instance_name       = "FSxN"
  ec2_instance_type       = var.ec2_instance_type
  ec2_iam_role            = var.ec2_iam_role
  creator_tag             = var.creator_tag
  ssm_password_key        = aws_ssm_parameter.adadminpassword.name
  security_groups_ids     = [aws_security_group.sg-AllowRemoteToEC2.id, aws_security_group.sg-AD-Server.id]
}

resource "aws_instance" "ec2-jump-config-server" {
  ami           = data.aws_ami.ubuntu-server-2004.id
  instance_type = "t2.micro"
  monitoring    = false

  vpc_security_group_ids = [aws_security_group.sg-AllowRemoteToEC2.id]
  subnet_id              = aws_subnet.public_subnet[0].id
  key_name               = var.ec2_instance_keypair
  iam_instance_profile   = var.ec2_iam_role

  user_data = <<EOF
#!/bin/bash
apt update
apt -y install awscli
vserver="${module.fsxontap.fsxn_svm.name}"
share_name_1="Share_Vol1"
path_1="${module.fsxontap.fsxn_volume_1.junction_path}"
share_name_2="Share_Vol2"
path_2="${module.fsxontap.fsxn_volume_2.junction_path}"
cluster="${sort(module.fsxontap.fsxn_management_management_ip)[0]}"
username="fsxadmin"
password=$(aws ssm get-parameter --name "${aws_ssm_parameter.fsxpassword.name}" --with-decryption --output text --query Parameter.Value --region ${var.aws_location})
response=$(curl -ks -u "$username:$password" -X GET "https://$cluster/api/protocols/cifs/shares?name=$share_name_1&svm.name=$vserver")
echo $response | grep -q "\"name\":\"$share_name_1\"" && echo "Share $share_name_1 already exists." || { curl -ks -u "$username:$password" -X POST -H "Content-Type: application/json" -d '{ "svm": { "name": "'"$vserver"'" }, "name": "'"$share_name_1"'", "path": "'"$path_1"'" }' "https://$cluster/api/protocols/cifs/shares" && echo "Share $share_name_1 created." || echo "Failed to create share $share_name_1."; }
response=$(curl -ks -u "$username:$password" -X GET "https://$cluster/api/protocols/cifs/shares?name=$share_name_2&svm.name=$vserver")
echo $response | grep -q "\"name\":\"$share_name_2\"" && echo "Share $share_name_2 already exists." || { curl -ks -u "$username:$password" -X POST -H "Content-Type: application/json" -d '{ "svm": { "name": "'"$vserver"'" }, "name": "'"$share_name_2"'", "path": "'"$path_2"'" }' "https://$cluster/api/protocols/cifs/shares" && echo "Share $share_name_2 created." || echo "Failed to create share $share_name_2."; }
EOF

  depends_on = [
    module.fsxontap,
    aws_vpc.vpc,
    aws_subnet.public_subnet
  ]
  tags = {
    Name = "${var.creator_tag}-${var.environment}-Jump-Server"
  }
}

data "aws_ami" "ubuntu-server-2004" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Amazon
}
