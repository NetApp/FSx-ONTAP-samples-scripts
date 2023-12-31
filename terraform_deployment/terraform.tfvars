vpc_id = "vpc-445d4f21"
fsx_subnets = {
      "primarysub" = "subnet-8fba81f8"
      "secondarysub" = "subnet-542bae0f"
   }
fs_capacity_size_gb = "1024"
deploy_type = "SINGLE_AZ_1"
fs_tput_in_MBps = "256"
svm_name = "first_svm"
vol_info = {
     "vol_name" = "vol1"
	  "junction_path" = "/vol1"
	  "size_mg" = 1024
	  "efficiency" = true
	  "tier_policy_name" = "AUTO"
	  "cooling_period" = 31
   }
