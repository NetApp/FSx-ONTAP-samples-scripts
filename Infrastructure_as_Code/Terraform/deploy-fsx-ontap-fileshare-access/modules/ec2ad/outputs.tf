output "ip_address" {
  value = {
    private_ip = aws_instance.ec2-ad.private_ip
    public_ip  = aws_instance.ec2-ad.public_ip
  }
}
