variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to monitoring resources."
  type        = map(string)
}

variable "ecs_cluster_name" {
  description = "ECS cluster name monitored by the alarms."
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name monitored by the alarms."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer."
  type        = string
}

variable "alb_target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group."
  type        = string
}