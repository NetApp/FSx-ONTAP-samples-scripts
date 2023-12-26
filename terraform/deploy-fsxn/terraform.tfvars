vpc_id = ""
fsx_subnets = {
      "primarysub" = "subnet-0363569f91f7bac2d"
      "secondarysub" = "subnet-0ad787406f660bcbb"
   }
fs_capacity_size_gb = "1024"
deploy_type = "SINGLE_AZ_1"
fs_tput_in_MBps = "256"
svm_name = "first_svm"
vol_info = {
     "vol_name" = "vol1"
	  "junction_path" = "/vol1"
	  "size" = 1024
	  "efficiency" = true
	  "tier_policy_name" = "AUTO"
	  "cooling_period" = 31
   }
