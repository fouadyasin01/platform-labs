resource "azurerm_network_interface" "app" {
  count               = 2
  name                = "${var.project_name}-${var.environment}-app-nic-${count.index + 1}"
  #name                = "${var.project_name}-${var.environment}-app-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-nic-${count.index + 1}"
    #Name = "${var.project_name}-${var.environment}-app-nic"
    Tier = "application"
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  count               = 2
  name                = "${var.project_name}-${var.environment}-app-${count.index + 1}"
  #name                = "${var.project_name}-${var.environment}-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_B2s"

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.app[count.index].id
   #azurerm_network_interface.app.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile(
    "${path.module}/user-data/app.sh.tftpl",
    {
      package_json = file("${path.module}/../app/api/package.json")
      db_js        = file("${path.module}/../app/api/db.js")
      server_js    = file("${path.module}/../app/api/server.js")
      schema_sql   = file("${path.module}/../app/api/schema.sql")

      database_host     = azurerm_postgresql_flexible_server.main.fqdn
      database_password = var.database_password
    }
  ))

  tags = {
    Name = "${var.project_name}-${var.environment}-app-${count.index + 1}"
    #Name = "${var.project_name}-${var.environment}-app"
    Tier = "application"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "app" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.app[count.index].id
  #network_interface_id    = azurerm_network_interface.app.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.app.id
}