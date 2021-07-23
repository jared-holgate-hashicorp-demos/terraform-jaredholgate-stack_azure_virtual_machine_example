locals {
  subnets                  = cidrsubnets(var.parent_ip_range, 8, 8, 8)
  consul_ip_addresses      = [for index in range(10, var.consul_cluster_size + 10) : cidrhost(local.subnets[0], index)]
  vault_ip_addresses       = [for index in range(10, var.vault_cluster_size + 10) : cidrhost(local.subnets[1], index)]
  consul_ip_addresses_flat = join("\",\"", local.consul_ip_addresses)
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

  tags = var.tags
}

data "azurerm_client_config" "current" {
}

data "azurerm_subscription" "current" {
}

resource "random_string" "key_vault_name" {
  length  = 24
  special = false
  number  = false
  upper   = false
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

  tags = var.tags
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

resource "random_string" "demo" {
  length  = 16
  special = false
  number  = true
  upper   = true
}

module "resource_windows_virtual_machine_demo" {
  source              = "app.terraform.io/jared-holgate-hashicorp/resource_windows_virtual_machine/jaredholgate"
  count               = var.include_demo_vm ? 1 : 0
  name                = "demo"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.demo_vm_size

  admin_password         = random_string.demo.result
  source_image_offer     = "Windows-10"
  source_image_publisher = "MicrosoftWindowsDesktop"
  source_image_sku       = "21h1-pro-g2"
  subnet_id              = azurerm_virtual_network.vault.subnet.*.id[2]
  tags = merge({
    cluster = "demo"
  }, var.tags)
}

resource "tls_private_key" "vault" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "resource_linux_virtual_machine_consul" {
  source              = "app.terraform.io/jared-holgate-hashicorp/resource_linux_virtual_machine/jaredholgate"
  count               = var.consul_cluster_size
  name                = "consul-server-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.consul_vm_size
  cloud_init_script = templatefile("${path.module}/consul.bash", {
    server_count = var.consul_cluster_size,
    server_name  = "consul-server-${count.index}",
    server_ip    = local.consul_ip_addresses[count.index],
    cluster_ips  = local.consul_ip_addresses_flat
  })
  ssh_public_key                           = tls_private_key.vault.public_key_openssh
  source_image_name                        = "consul-ubuntu-1804"
  source_image_gallery_name                = "sig_jared_holgate"
  source_image_gallery_resource_group_name = "azure-vault-build"
  subnet_id                                = azurerm_virtual_network.vault.subnet.*.id[0]
  static_ip_address                        = local.consul_ip_addresses[count.index]
  tags = merge({
    cluster = "consul"
  }, var.tags)
}

module "resource_linux_virtual_machine_vault" {
  source              = "app.terraform.io/jared-holgate-hashicorp/resource_linux_virtual_machine/jaredholgate"
  count               = var.vault_cluster_size
  depends_on          = [module.resource_linux_virtual_machine_consul]
  name                = "vault-server-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vault_vm_size
  cloud_init_script = templatefile("${path.module}/vault.bash", {
    server_name     = "vault-server-${count.index}",
    server_ip       = local.vault_ip_addresses[count.index],
    cluster_ips     = local.consul_ip_addresses_flat,
    tenant_id       = data.azurerm_client_config.current.tenant_id
    subscription_id = data.azurerm_client_config.current.subscription_id
    client_id       = data.azurerm_client_config.current.client_id
    client_secret   = var.client_secret_for_unseal
    vault_name      = azurerm_key_vault.vault.name
    key_name        = "vault-unseal-key"
  })
  ssh_public_key                           = tls_private_key.vault.public_key_openssh
  source_image_name                        = "vault-ubuntu-1804"
  source_image_gallery_name                = "sig_jared_holgate"
  source_image_gallery_resource_group_name = "azure-vault-build"
  subnet_id                                = azurerm_virtual_network.vault.subnet.*.id[1]
  static_ip_address                        = local.vault_ip_addresses[count.index]
  has_managed_identity                     = true
  tags = merge({
    cluster = "consul"
  }, var.tags)
}

resource "azurerm_role_assignment" "vault" {
  count                = var.vault_cluster_size
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Owner"
  principal_id         = module.resource_linux_virtual_machine_vault[count.index].managed_identity_principal_id
}

module "resource_azure_ad_role_assignment" {
  source             = "app.terraform.io/jared-holgate-hashicorp/resource_azure_ad_role_assignment/jaredholgate"
  count              = var.vault_cluster_size
  client_id          = data.azurerm_client_config.current.client_id
  client_secret      = var.client_secret_for_unseal
  principal_id       = module.resource_linux_virtual_machine_vault[count.index].managed_identity_principal_id
  role_definition_id = "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3"
  tenant_id          = data.azurerm_client_config.current.tenant_id
}