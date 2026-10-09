resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.project_name}-${var.environment}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                = "${var.project_name}-${var.environment}-postgres-dns-link"
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
  virtual_network_id  = azurerm_virtual_network.main.id

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                = "${var.project_name}-${var.environment}-postgres"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  version                = "16"
  delegated_subnet_id    = azurerm_subnet.db.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  administrator_login    = "appadmin"
  administrator_password = var.database_password

  public_network_access_enabled = false

  storage_mb   = 32768
  storage_tier = "P4"

  sku_name = "B_Standard_B1ms"
  zone     = "1"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Tier        = "database"
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres
  ]
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.main.id
}