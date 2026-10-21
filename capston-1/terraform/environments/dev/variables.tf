variable "availability_zones" {
  description = "Availability zones for the VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
variable "cluster_endpoint_public_access_cidrs" {
  description = "Public IPv4 CIDRs allowed to access the EKS API endpoint"
  type        = list(string)
}
