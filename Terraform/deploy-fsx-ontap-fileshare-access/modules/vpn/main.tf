data "aws_vpc" "vpc" {
  id = var.vpc_id
}

resource "aws_acm_certificate" "server_vpn_cert" {
  certificate_body  = var.server_cert
  private_key       = var.server_private_key
  certificate_chain = var.ca_crt
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "client_vpn_cert" {
  certificate_body  = var.client_cert
  private_key       = var.client_private_key
  certificate_chain = var.ca_crt
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ec2_client_vpn_endpoint" "my_client_vpn" {
  description            = "Demo VPN"
  server_certificate_arn = aws_acm_certificate.server_vpn_cert.arn
  client_cidr_block      = var.vpn_cidr
  vpc_id                 = var.vpc_id

  security_group_ids = [aws_security_group.vpn_secgroup.id]
  split_tunnel       = true

  # Client authentication
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_vpn_cert.arn
  }

  connection_log_options {
    enabled = false
  }

  depends_on = [
    aws_acm_certificate.server_vpn_cert,
    aws_acm_certificate.client_vpn_cert
  ]
}

resource "aws_ec2_client_vpn_network_association" "client_vpn_association_public" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.my_client_vpn.id
  subnet_id              = var.public_subnet_id
}

resource "aws_ec2_client_vpn_authorization_rule" "authorization_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.my_client_vpn.id

  target_network_cidr  = data.aws_vpc.vpc.cidr_block
  authorize_all_groups = true
}

