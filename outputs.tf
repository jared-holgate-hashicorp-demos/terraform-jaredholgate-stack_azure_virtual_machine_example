output "ssh_key" {
  value     = tls_private_key.vault.public_key_openssh
  sensitive = true
}