# outputing all the elactic ip
# for all the nat with in the zones
output "eip-for-nat" {
  value = aws_eip.eip-for-nat.*.public_ip
}

# Load balancer dns name
output "elb_dns_name" {
  value = aws_lb.web_elb.dns_name
}