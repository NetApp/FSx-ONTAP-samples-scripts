output "ip_address" {
  value = {
    private_ip = module.sqlserver.private_ip
    public_ip  = module.sqlserver.public_ip
  }
}
