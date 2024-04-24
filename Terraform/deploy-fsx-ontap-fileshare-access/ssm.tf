resource "aws_ssm_parameter" "fsxpassword" {
  name        = "/fsxn/password/fsxadmin"
  description = "FSxN Admin Password"
  type        = "SecureString"
  value       = var.fsxn_password

  tags = {
    creator = var.creator_tag
  }
}

resource "aws_ssm_parameter" "adadminpassword" {
  name        = "/ad/password/adadmin"
  description = "AD Admin Password"
  type        = "SecureString"
  value       = var.ad_admin_password

  tags = {
    creator = var.creator_tag
  }
}
