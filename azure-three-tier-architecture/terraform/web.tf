# Private web servers behind the public Application Gateway.
resource "azurerm_network_interface" "web" {
  count               = 2
  name                = "${var.project_name}-${var.environment}-web-nic-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web-nic-${count.index + 1}"
    Tier = "web"
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  count               = 2
  name                = "${var.project_name}-${var.environment}-web-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_B2s"

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.web[count.index].id
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
    "${path.module}/user-data/web.sh.tftpl",
    {
      index_html = file("${path.module}/../app/web/index.html")

      nginx_conf = replace(
        file("${path.module}/../app/web/nginx.conf.template"),
        "$${APP_ALB_DNS}",
        "${azurerm_lb.internal.frontend_ip_configuration[0].private_ip_address}:3000"
      )
    }
  ))

  tags = {
    Name = "${var.project_name}-${var.environment}-web-${count.index + 1}"
    Tier = "web"
  }
}