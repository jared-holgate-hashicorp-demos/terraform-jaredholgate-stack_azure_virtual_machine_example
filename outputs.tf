output "ssh_key" {
  description = "The SSH private key for connecting to the Linux virtual machines. NOTE: The should be encrypted or provided in production."
  value       = nonsensitive(tls_private_key.vault.private_key_pem)
}

output "demo_password" {
  description = "The password for connecting to the Windows virtual machine. NOTE: The should be encrypted or provided in production."
  value       = var.include_demo_vm ? random_string.demo.result : ""
}

output "demo_public_ip_address" {
  description = "The public ip address for connecting to the Windows virtual machine."
  value       = var.include_demo_vm ? module.resource_windows_virtual_machine_demo[0].public_ip : ""
}