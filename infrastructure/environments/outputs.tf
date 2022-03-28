// elb dns
output "elb_dns_name" {
  value = aws_lb.web_elb.dns_name
}

// elip
output "aws_eip" {
  value = aws_eip.eip_for_the_nat_gateway.public_ip
}