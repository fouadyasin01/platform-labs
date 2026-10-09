output "entry_point_url" {
  description = "Public URL of the application"
  value       = "http://${azurerm_public_ip.application_gateway.ip_address}"
}