# Variables for my environment.  Source is Development FSxN system.

# Primary FSxN variables
prime_hostname                = "<cluster mgmt ip address>"
prime_fsxid                   = "fs-xxxxxxxxxxxxxxxxx"
prime_svm                     = "fsx"
prime_cluster_vserver         = "FsxIdxxxxxxxxxxxxxxxx"
prime_aws_region              = "us-west-2"
username_pass_secrets_id      = "<Name of AWS secret>"
list_of_volumes_to_replicate  = ["vol1", "vol2", "vol3"]

# DR FSxN variables
dr_aws_region                 = "us-west-2"
dr_fsx_name                   = "terraform-dr-fsxn"
dr_fsx_subnets                = {
                                   "primarysub" = "subnet-11111111"
                                   "secondarysub" = "subnet-33333333"
                                }
dr_svm_name                   = "fsx_dr"
dr_security_group_name_prefix = "fsxn-sg"
dr_vpc_id                     = "vpc-xxxxxxxx"
dr_username_pass_secrets_id   = "<Name of AWS secret>"
dr_snapmirror_policy_name     = "<Name of Policy to create>"
dr_retention                  = "[{ \"label\": \"weekly\", \"count\": 4 }, { \"label\": \"daily\", \"count\": 7 }]"
