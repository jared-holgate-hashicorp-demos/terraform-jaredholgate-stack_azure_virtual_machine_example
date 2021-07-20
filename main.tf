variable "consul_cluster_size" {
    type = number
    default = 3
}

variable "vault_cluster_size" {
    type = number
    default = 3
}

variable "resource_group_name" {
    type = string
}

variable "location" {
    type = string
    default = "UK South"
}

variable "environment" {
    type = string
}

variable "consul_virtual_machine_prefix" {
    type = string
    default = "consul-server"
}

variable "vault_virtual_machine_prefix" {
    type = string
    default = "vault-server"
}

resource "azurerm_virtual_network" "vault" {
  name                = "vnet-vault"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.1.0/24", "10.0.2.0/24" ]

  subnet {
    name           = "vault"
    address_prefix = "10.0.1.0/24"
  }

  subnet {
    name           = "consul"
    address_prefix = "10.0.2.0/24"
  }

  tags = {
    environment = var.environment
  }
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}

data "azurerm_shared_image_version" "vault" {
  name                = "latest"
  image_name          = "vault-ubuntu-1804"
  gallery_name        = "sig_jared_holgate"
  resource_group_name = "azure-vault-build"
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

resource "azurerm_network_interface" "vault" {
  name                = "vault-nic"
  count = var.vault_cluster_size
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.vault.subnet[0].id
    private_ip_address_allocation = "Static"
    primary = true
    private_ip_address = "10.0.1.${ 10 + count.index }"
  }
}

resource "azurerm_network_interface" "consul" {
  name                = "consul-nic"
  count = var.consul_cluster_size
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.consul.subnet[0].id
    private_ip_address_allocation = "Static"
    primary = true
    private_ip_address = "10.0.2.${ 10 + count.index }"
  }
}

data "template_file" "consul" {
  template = file("consul.bash")
}

data "template_file" "vault" {
  template = file("vault.bash")
}

resource "azurerm_linux_virtual_machine" "consul" {
  count = var.consul_cluster_size
  name                = "consul-server-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                 = "Standard_DS2_v2"
  admin_username      = "adminuser"
  custom_data = base64encode(data.template_file.consul.rendered)

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.vault.public_key_openssh
  }

  source_image_id = azurerm_shared_image_version.consul.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface_ids = [
    azurerm_network_interface.consul[count.index].id,
  ]
}

resource "azurerm_user_assigned_identity" "vault" {
  resource_group_name = var.resource_group_name
  location            = var.location

  name = "azure-vault-identity-${var.environment}"
}

resource "azurerm_linux_virtual_machine" "vault" {
  count = var.vault_cluster_size
  name                = "vault-server-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                 = "Standard_DS2_v2"
  admin_username      = "adminuser"
  custom_data = base64encode(data.template_file.vault.rendered)

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.vault.public_key_openssh
  }

  source_image_id = azurerm_shared_image_version.vault.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface_ids = [
    azurerm_network_interface.vault[count.index].id,
  ]

  identity {
      type = "UserAssigned"
      identity_ids = [ azurerm_user_assigned_identity.vault.id ]
  }
}

output "ssh_key" {
    value = tls_private_key.vault.public_key_openssh
    sensitive = true
}