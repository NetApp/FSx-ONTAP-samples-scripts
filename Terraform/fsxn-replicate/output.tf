output "volume_details" {
  value = {
    for key, volume in data.netapp-ontap_storage_volume_data_source.my_vol : key => {
      name      = volume.name
      type      = volume.type
      size      = "${volume.space.size}${volume.space.size_unit}"
    }
  }
  description = "Details of the volumes including name, type, size, and size unit"
}
