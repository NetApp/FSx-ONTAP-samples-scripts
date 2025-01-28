module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.33"
  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  subnet_ids      = module.vpc.private_subnets

  enable_irsa = true

  tags = {
    Environment = "training"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  vpc_id = module.vpc.vpc_id

  eks_managed_node_group_defaults = {
    ami_type               = "AL2_x86_64"
    instance_types         = ["t3.medium"]
    vpc_security_group_ids = [aws_security_group.all_worker_mgmt.id]
  }

  eks_managed_node_groups = {

    fsx_group = {
      min_size     = 2
      max_size     = 6
      desired_size = 2

      enable_bootstrap_user_data = true

      pre_bootstrap_user_data = data.cloudinit_config.cloudinit.rendered
    }
  }
}
#
# Create a random id for the policy and role names to ensure no conflict.
resource "random_id" "id" {
  byte_length = 4
}
#
# Get access to the aws provider identity data to get account ID.
data "aws_caller_identity" "current" {}
#
# Add pod-identity add-on to the EKS cluster.
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = module.eks.cluster_name
  addon_name   = "eks-pod-identity-agent"
}
#
# Add Trident to the EKS cluster with a role that will allow it to read secrets
# add manage the fsxn file system.
resource "aws_eks_addon" "fsxn_csi_addon" {
  cluster_name = module.eks.cluster_name
  addon_name   = "netapp_trident-operator"
  addon_version = var.trident_version
  resolve_conflicts_on_create = "OVERWRITE"

  configuration_values = jsonencode({
    cloudIdentity = "'eks.amazonaws.com/role-arn: ${aws_iam_role.trident_role.arn}'"
  })
}
#
# Create a policy that will allow trident to manage FSxN resources, and get AWS Secrets Manager secret values.
resource "aws_iam_policy" "trident_policy" {
  name = "trident_policy-${random_id.id.hex}"

  policy = jsonencode({
    "Version": "2012-10-17"
    "Statement": [
        {
            "Action": [
                "fsx:DescribeFileSystems",
                "fsx:DescribeVolumes",
                "fsx:CreateVolume",
                "fsx:RestoreVolumeFromSnapshot",
                "fsx:DescribeStorageVirtualMachines",
                "fsx:UntagResource",
                "fsx:UpdateVolume",
                "fsx:TagResource",
                "fsx:DeleteVolume"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": "secretsmanager:GetSecretValue",
            "Effect": "Allow",
            "Resource": module.svm_rotate_secret.secret_arn
        }
    ],
  })
}
#
# Create a role that holds the trident policy so Trident can assume it.
resource "aws_iam_role" "trident_role" {
  name = "trident_role-${random_id.id.hex}"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${module.eks.oidc_provider}:aud": "sts.amazonaws.com",
                    "${module.eks.oidc_provider}:sub": "system:serviceaccount:trident:trident-controller"
                }
            }
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "trident_policy_attachment" {
  role       = aws_iam_role.trident_role.name
  policy_arn = aws_iam_policy.trident_policy.arn
}

resource "aws_iam_role_policy_attachments_exclusive" "trident_policy_attachment_exclusive" {
  role_name   = aws_iam_role.trident_role.name
  policy_arns = [aws_iam_policy.trident_policy.arn]
}

data "cloudinit_config" "cloudinit" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = <<EOT
#!/bin/bash
sudo yum install -y lsscsi iscsi-initiator-utils sg3_utils device-mapper-multipath
rpm -q iscsi-initiator-utils
sudo sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf
cat /etc/iscsi/initiatorname.iscsi
sudo mpathconf --enable --with_multipathd y --find_multipaths n
#
# Blacklist any EBS volume since they don't support them!
sed -i -e '/^blacklist {/,/^}/{/^}/i\    device {\n        vendor "NVME"\n        product "Amazon Elastic Block Store"\n    }\n' -e '}' /etc/multipath.conf
sudo systemctl restart multipathd
sudo systemctl enable --now iscsid multipathd
sudo systemctl enable --now iscsi
EOT
  }
}
