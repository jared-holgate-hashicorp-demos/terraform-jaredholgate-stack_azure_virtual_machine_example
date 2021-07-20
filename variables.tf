variable "consul_cluster_size" {
  type    = number
  default = 3
}

variable "vault_cluster_size" {
  type    = number
  default = 3
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
  default = "UK South"
}

variable "environment" {
  type = string
}

variable "consul_virtual_machine_prefix" {
  type    = string
  default = "consul-server"
}

variable "vault_virtual_machine_prefix" {
  type    = string
  default = "vault-server"
}

variable "parent_ip_range" {
    type = string
    default = "10.0.0.0/16"
}

variable "include_demo_vm" {
  type    = bool
  default = true
}