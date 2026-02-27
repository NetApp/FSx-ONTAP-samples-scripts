
locals {
  server_name = "${var.creator_tag}-${var.ec2_instance_name}-AD"
}

resource "aws_instance" "ec2-ad" {
  ami           = data.aws_ami.windows-core-server.id
  instance_type = var.ec2_instance_type
  monitoring    = true

  vpc_security_group_ids = var.security_groups_ids
  subnet_id              = var.ec2_subnet_id
  key_name               = var.ec2_instance_key_pair
  iam_instance_profile   = var.ec2_iam_role
  get_password_data      = true

  root_block_device {
    volume_type = "gp2"
    volume_size = 70
  }

  lifecycle {
    ignore_changes = [tags]
  }

  user_data = <<EOT
  <powershell>
$Domain = "${var.ad_domain}"
$DN = "DC=" + $Domain.Replace(".",",DC=")
$ssmPass = (Get-SSMParameterValue -Name ${var.ssm_password_key} -WithDecryption 1).Parameters.Value 
$Pass = ConvertTo-SecureString "$($ssmPass)" -AsPlainText -Force 
$InstanceId = Get-EC2InstanceMetadata -Category InstanceId 
$Tags = Get-EC2Tag -Filter @{Name="resource-type";Values="instance"},@{Name="resource-id";Values=$InstanceId}

if(($Tags | Where-Object { $_.Key -eq "ADStatus" }).Value -eq "Completed") {
  exit
}

if(($Tags | Where-Object { $_.Key -eq "ADStatus" }) -eq $null) { 
    $tag = New-Object Amazon.EC2.Model.Tag
    $tag.Key = "ADStatus"
    $tag.Value = "Provisioning"

    New-EC2Tag -Resource $InstanceId -Tag $tag
}

if((Get-WindowsFeature -Name AD-Domain-Services).InstallState -ne "Installed") {
  Add-WindowsFeature AD-Domain-Services
}

if((Get-WindowsFeature -Name RSAT-AD-Tools).InstallState -ne "Installed") {
  Add-WIndowsFeature RSAT-AD-Tools
}

if((Get-WindowsFeature -Name RSAT-ADDS).InstallState -ne "Installed") {
  Add-WIndowsFeature RSAT-ADDS
}

Try {
  (Get-ADDomain | Where-Object { $_.DNSRoot -eq "${var.ad_domain}"})
} Catch {
  Install-ADDSForest -DomainName ${var.ad_domain} -InstallDNS -SafeModeAdministratorPassword $Pass -Confirm:$false 
}

if((Get-ADOrganizationalUnit -Filter "Name -like 'FSXN'") -eq $null) {
  New-ADOrganizationalUnit -Name "FSXN" -Path $DN
}

if((Get-ADUser -Filter "samAccountName -like 'fsxnadmin'") -eq $null) {
  New-ADUser -Name ${var.ad_service_account} -AccountPassword $Pass -Passwordneverexpires $true -Enabled $true -ChangePasswordAtLogon $false
  Add-ADGroupMember -Identity "Domain Admins" -Members ${var.ad_service_account}
  Add-ADGroupMember -Identity "Administrators" -Members ${var.ad_service_account}
  New-ADGroup -DisplayName "${var.ad_administrators_group}" -GroupCategory Security -GroupScope Global -Name "${var.ad_administrators_group}" -SamAccountName "${var.ad_administrators_group}"  
  Add-ADGroupMember -Identity "${var.ad_administrators_group}" -Members ${var.ad_service_account}

  $tag = New-Object Amazon.EC2.Model.Tag
  $tag.Key = "ADStatus"
  $tag.Value = "Completed"

  New-EC2Tag -Resource $InstanceId -Tag $tag
}

  </powershell>
  <persist>true</persist>
  EOT 

  tags = {
    Name = local.server_name
  }
}
