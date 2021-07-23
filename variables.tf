variable "consul_cluster_size" {
  description = "The number of virtual machines to provision for the Consul cluster."
  type        = number
  default     = 3
}

variable "vault_cluster_size" {
  description = "The number of virtual machines to provision for the Vault cluster."
  type        = number
  default     = 3
}

variable "resource_group_name" {
  description = "The name of the resource group to deploy to."
  type        = string
}

variable "location" {
  description = "The Azure Region to deploy the resources in."
  type        = string
  default     = "UK South"
}

variable "consul_virtual_machine_prefix" {
  description = "The virtual machine name prefix for the Consul Cluster."
  type        = string
  default     = "consul-server"
}

variable "vault_virtual_machine_prefix" {
  description = "The virtual machine name prefix for the Vault Cluster."
  type        = string
  default     = "vault-server"
}

variable "parent_ip_range" {
  description = "The IP Range for the network."
  type        = string
  default     = "10.1.0.0/16"
}

variable "include_demo_vm" {
  description = "Whether to provision a Windows virtual machine into the environment to use for testing / demos."
  type        = bool
  default     = true
}

variable "vault_vm_size" {
  description = "The SKU of virtual machine for the Vault Cluster."
  type        = string
  default     = "Standard_B1s"
}

variable "consul_vm_size" {
  description = "The SKU of virtual machine for the Consul Cluster."
  type        = string
  default     = "Standard_B1s"
}

variable "demo_vm_size" {
  description = "The SKU of virtual machine for the Demo Windows virtual machine."
  type        = string
  default     = "Standard_B2s"
}

variable "client_secret_for_unseal" {
  description = "The client secret used for the auto unseal of vault."
  type        = string
  sensitive   = true
}

variable "tags" {
  type    = map(string)
  default = {}
}