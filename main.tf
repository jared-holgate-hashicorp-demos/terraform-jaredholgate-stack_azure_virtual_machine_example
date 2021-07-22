locals {
    subnets = cidrsubnets(var.parent_ip_range, 8, 8, 8)
    consul_ip_addresses = [ for index in range(10, var.consul_cluster_size + 10) : cidrhost(local.subnets[0], index) ]
    vault_ip_addresses = [ for index in range(10, var.vault_cluster_size + 10) : cidrhost(local.subnets[1], index) ]

    consul_ip_addresses_flat = join("\",\"", local.consul_ip_addresses)
    vault_ip_addresses_flat = join("\",\"", local.vault_ip_addresses)
}

resource "azurerm_virtual_network" "vault" {
  name                = "vnet-vault"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = local.subnets

  subnet {
    name           = "vault"
    address_prefix = local.subnets[0]
  }

  subnet {
    name           = "consul"
    address_prefix = local.subnets[1]
  }

  dynamic "subnet" {
      for_each = var.include_demo_vm ? { subnet = "demo" } : {}
      content {
        name           = "demo"
        address_prefix = local.subnets[2]
      }
  }

  tags = {
    environment = var.environment
  }
}

data "azurerm_client_config" "current" {
}

resource "random_string" "key_vault_name" {
  length           = 24
  special          = false
  number           = false
  upper            = false
}


resource "azurerm_key_vault" "vault" {
  name                = random_string.key_vault_name.result
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  enabled_for_deployment = true

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "get",
      "list",
      "create",
      "delete",
      "update",
      "wrapKey",
      "unwrapKey",
    ]
  }

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

resource "azurerm_key_vault_key" "vault_unseal" {
  name         = "vault-unseal-key"
  key_vault_id = azurerm_key_vault.vault.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "wrapKey",
    "unwrapKey",
  ]
}


resource "azurerm_public_ip" "demo" {
  name                = "demo-public-ip"
  count               = var.include_demo_vm ? 1 : 0
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "demo" {
  name                = "demo-nic"
  count               = var.include_demo_vm ? 1 : 0
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.vault.subnet.*.id[2]
    private_ip_address_allocation = "Dynamic"
    primary                       = true
    public_ip_address_id          = azurerm_public_ip.demo[0].id
  }
}

resource "random_string" "demo" {
  length           = 16
  special          = false
  number           = true
  upper            = true
}

resource "azurerm_windows_virtual_machine" "demo" {
  name                = "demo"
  count = var.include_demo_vm ? 1 : 0
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.demo_vm_size
  admin_username      = "adminuser"
  admin_password      = random_string.demo.result
  network_interface_ids = [
    azurerm_network_interface.demo[0].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "21h1-pro-g2"
    version   = "latest"
  }
}


data "azurerm_shared_image_version" "consul" {
  name                = "latest"
  image_name          = "consul-ubuntu-1804"
  gallery_name        = "sig_jared_holgate"
  resource_group_name = "azure-vault-build"
}

resource "tls_private_key" "vault" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_network_interface" "consul" {
  name                = "consul-nic-${count.index}"
  count               = var.consul_cluster_size
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.vault.subnet.*.id[0]
    private_ip_address_allocation = "Static"
    primary                       = true
    private_ip_address            = local.consul_ip_addresses[count.index]
  }
}

resource "azurerm_linux_virtual_machine" "consul" {
  count               = var.consul_cluster_size
  name                = "consul-server-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vault_vm_size
  admin_username      = "adminuser"
  custom_data         = base64encode(templatefile("${path.module}/consul.bash", { 
    server_count = var.consul_cluster_size, 
    server_name = "consul-server-${count.index}", 
    server_ip = local.consul_ip_addresses[count.index], 
    cluster_ips = local.consul_ip_addresses_flat 
  }))

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.vault.public_key_openssh
  }

  source_image_id = data.azurerm_shared_image_version.consul.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface_ids = [
    azurerm_network_interface.consul[count.index].id,
  ]
}


data "azurerm_shared_image_version" "vault" {
  name                = "latest"
  image_name          = "vault-ubuntu-1804"
  gallery_name        = "sig_jared_holgate"
  resource_group_name = "azure-vault-build"
}

resource "azurerm_network_interface" "vault" {
  name                = "vault-nic-${count.index}"
  count               = var.vault_cluster_size
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.vault.subnet.*.id[1]
    private_ip_address_allocation = "Static"
    primary                       = true
    private_ip_address            = local.vault_ip_addresses[count.index]
  }
}

data "azurerm_subscription" "current" {
} 

resource "azurerm_role_assignment" "vault_master" {
  count                = 1
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Owner"
  principal_id         = azurerm_linux_virtual_machine.vault_master[count.index].identity.0.principal_id
}

resource "azurerm_role_assignment" "vault" {
  count                = var.vault_cluster_size - 1
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Owner"
  principal_id         = azurerm_linux_virtual_machine.vault[count.index].identity.0.principal_id
}

#TODO: Add The 'Application Administrator' Role Assignment to the MSI using REST

resource "azurerm_linux_virtual_machine" "vault_master" {
  count               = 1
  depends_on          = [ azurerm_key_vault_key.vault_unseal, azurerm_linux_virtual_machine.consul ]
  name                = "vault-server-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.consul_vm_size
  admin_username      = "adminuser"
  custom_data         = base64encode(templatefile("${path.module}/vault.bash", { 
    server_name = "vault-server-${count.index}", 
    server_ip = local.vault_ip_addresses[count.index], 
    cluster_ips = local.consul_ip_addresses_flat,
    tenant_id           = data.azurerm_client_config.current.tenant_id
    subscription_id     = data.azurerm_client_config.current.subscription_id
    client_id           = data.azurerm_client_config.current.client_id
    client_secret       = var.client_secret_for_unseal
    vault_name          = azurerm_key_vault.vault.name
    key_name            = "vault-unseal-key"
  }))

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.vault.public_key_openssh
  }

  source_image_id = data.azurerm_shared_image_version.vault.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface_ids = [
    azurerm_network_interface.vault[count.index].id,
  ]

  identity {
    type         = "SystemAssigned"
  }
}

resource "azurerm_linux_virtual_machine" "vault" {
  count               = var.vault_cluster_size - 1
  depends_on          = [ azurerm_linux_virtual_machine.vault_master, azurerm_key_vault_key.vault_unseal, azurerm_linux_virtual_machine.consul ]
  name                = "vault-server-${count.index + 1}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.consul_vm_size
  admin_username      = "adminuser"
  custom_data         = base64encode(templatefile("${path.module}/vault.bash", { 
    server_name = "vault-server-${count.index + 1}", 
    server_ip = local.vault_ip_addresses[count.index + 1], 
    cluster_ips = local.consul_ip_addresses_flat,
    tenant_id           = data.azurerm_client_config.current.tenant_id
    subscription_id     = data.azurerm_client_config.current.subscription_id
    client_id           = data.azurerm_client_config.current.client_id
    client_secret       = var.client_secret_for_unseal
    vault_name          = azurerm_key_vault.vault.name
    key_name            = "vault-unseal-key"
  }))

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.vault.public_key_openssh
  }

  source_image_id = data.azurerm_shared_image_version.vault.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface_ids = [
    azurerm_network_interface.vault[count.index + 1].id,
  ]

  identity {
    type         = "SystemAssigned"
  }
}