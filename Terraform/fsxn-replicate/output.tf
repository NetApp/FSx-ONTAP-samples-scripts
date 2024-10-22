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

#output "lifs" {
#  value = {
#    for key, lif in data.netapp-ontap_networking_ip_interfaces_data_source.primary_intercluster_lifs : key => {
#      name       = lif.ip_interfaces.name
#      ip_address = lif.ip_interfaces.ip.ip_address
#    }
#  }
#  description = "Details of source intercluster LIFs"
#}

output "primary_intercluster_lifs_details" {
  value = {
    for lif in data.netapp-ontap_networking_ip_interfaces_data_source.primary_intercluster_lifs.ip_interfaces : lif.name => lif.ip.address
  }
  description = "Intercluster LIF names and IP addresses for the primary existing cluster"
}

