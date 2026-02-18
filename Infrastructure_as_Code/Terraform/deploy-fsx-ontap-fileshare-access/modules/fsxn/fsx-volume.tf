resource "aws_fsx_ontap_volume" "fsxn_volume_1" {
  name                       = "${var.fsxn_volume_name_prefix}_vol1"
  junction_path              = "/${var.fsxn_volume_name_prefix}_vol1"
  security_style             = var.fsxn_volume_security_style
  size_in_megabytes          = 500000
  snapshot_policy            = "default"
  storage_efficiency_enabled = true
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.fsxsvm01.id
  skip_final_backup          = true
  tiering_policy {
    name           = "AUTO"
    cooling_period = "7"
  }
}

resource "aws_fsx_ontap_volume" "fsxn_volume_2" {
  name                       = "${var.fsxn_volume_name_prefix}_vol2"
  junction_path              = "/${var.fsxn_volume_name_prefix}_vol2"
  security_style             = var.fsxn_volume_security_style
  size_in_megabytes          = 500000
  snapshot_policy            = "default"
  storage_efficiency_enabled = true
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.fsxsvm01.id
  skip_final_backup          = true
  tiering_policy {
    name = "ALL"
  }
}


