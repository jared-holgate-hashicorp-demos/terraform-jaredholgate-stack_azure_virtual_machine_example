output "ssh_key" {
  value     = tls_private_key.vault.public_key_openssh
  sensitive = true
}

output "demo_public_ip_address" {
  value = azurerm_public_ip.demo.ip_address
}