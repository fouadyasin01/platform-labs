output "lb_dns_name" {
  value =  aws_lb.main.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.api.arn
}

output "lb_listener_http" {
  value = aws_lb_listener.http
}