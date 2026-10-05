output "lb_dns_name" {
  value = aws_lb.main.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.api.arn
}

output "lb_listener_http" {
  value = aws_lb_listener.http
}

output "lb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer."
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group."
  value       = aws_lb_target_group.api.arn_suffix
}