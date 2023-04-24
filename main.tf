locals {
  subnets                  = cidrsubnets(var.parent_ip_range, 8, 8, 8)
  primary_ip_addresses      = [for index in range(10, var.primary_cluster_size + 10) : cidrhost(local.subnets[0], index)]
  secondary_ip_addresses       = [for index in range(10, var.secondary_cluster_size + 10) : cidrhost(local.subnets[1], index)]
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-main"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = local.subnets

  subnet {
    name           = "primary"
    address_prefix = local.subnets[0]
  }

  subnet {
    name           = "secondary"
    address_prefix = local.subnets[1]
  }

  dynamic "subnet" {
    for_each = var.include_demo_vm ? { subnet = "demo" } : {}
    content {
      name           = "demo"
      address_prefix = local.subnets[2]
    }
  }

  tags = var.tags
}

data "azurerm_client_config" "current" {
}

data "azurerm_subscription" "current" {
}

resource "random_string" "demo" {
  length      = 16
  special     = false
  numeric      = true
  upper       = true
  min_lower   = 1
  min_numeric = 1
  min_upper   = 1
}

module "resource_windows_virtual_machine_demo" {
  source              = "app.terraform.io/jared-holgate-microsoft/resource_windows_virtual_machine/jaredholgate"
  count               = var.include_demo_vm ? 1 : 0
  name                = "demo"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.demo_vm_size

  admin_password         = random_string.demo.result
  source_image_offer     = "Windows-10"
  source_image_publisher = "MicrosoftWindowsDesktop"
  source_image_sku       = "21h1-pro-g2"
  subnet_id              = azurerm_virtual_network.main.subnet.*.id[2]
  tags = merge({
    cluster = "demo"
  }, var.tags)
}

resource "tls_private_key" "vault" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "resource_linux_virtual_machine_primary" {
  source              = "app.terraform.io/jared-holgate-microsoft/resource_linux_virtual_machine/jaredholgate"
  count               = var.primary_cluster_size
  name                = "${var.primary_virtual_machine_prefix}-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.primary_vm_size
  ssh_public_key                           = tls_private_key.vault.public_key_openssh
  source_image_offer                       = "UbuntuServer"
  source_image_publisher                   = "Canonical"
  source_image_sku                         = "18.04-LTS"
  subnet_id                                = azurerm_virtual_network.main.subnet.*.id[0]
  static_ip_address                        = local.primary_ip_addresses[count.index]
  tags = merge({
    cluster = "primary"
  }, var.tags)
}

module "resource_linux_virtual_machine_secondary" {
  source              = "app.terraform.io/jared-holgate-microsoft/resource_linux_virtual_machine/jaredholgate"
  count               = var.secondary_cluster_size
  name                = "${var.secondary_virtual_machine_prefix}-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.secondary_vm_size
  ssh_public_key                           = tls_private_key.vault.public_key_openssh
  source_image_offer                       = "UbuntuServer"
  source_image_publisher                   = "Canonical"
  source_image_sku                         = "18.04-LTS"
  subnet_id                                = azurerm_virtual_network.main.subnet.*.id[1]
  static_ip_address                        = local.secondary_ip_addresses[count.index]
  has_managed_identity                     = true
  tags = merge({
    cluster = "secondary"
  }, var.tags)
}
