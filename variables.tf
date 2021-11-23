variable "primary_cluster_size" {
  description = "The number of virtual machines to provision for the primary cluster."
  type        = number
  default     = 3
}

variable "secondary_cluster_size" {
  description = "The number of virtual machines to provision for the secomndary cluster."
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

variable "primary_virtual_machine_prefix" {
  description = "The virtual machine name prefix for the Primary Cluster."
  type        = string
  default     = "primary-server"
}

variable "secondary_virtual_machine_prefix" {
  description = "The virtual machine name prefix for the Secondary Cluster."
  type        = string
  default     = "secondary-server"
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

variable "primary_vm_size" {
  description = "The SKU of virtual machine for the Primary Cluster."
  type        = string
  default     = "Standard_B1s"
}

variable "secondary_vm_size" {
  description = "The SKU of virtual machine for the Secondary Cluster."
  type        = string
  default     = "Standard_B1s"
}

variable "demo_vm_size" {
  description = "The SKU of virtual machine for the Demo Windows virtual machine."
  type        = string
  default     = "Standard_B2s"
}

variable "tags" {
  type    = map(string)
  default = {}
}
