output "ssh_key" {
  value     = tls_private_key.vault.public_key_openssh
}

output "demo_password" {
  value = var.include_demo_vm ? random_string.demo.result : ""
}

output "demo_public_ip_address" {
  value = var.include_demo_vm ? azurerm_public_ip.demo[0].ip_address : ""
}