This module deploys a HashiCorp Vault cluster on Microsoft Azure IaaS. The Cluster is backed by a HashiCorp Consul cluster.

The module deploys the virtual machines from a template defined and build by HashiCorp Packer.

It then configure the Vault and Consul clusters ready for use. As a final step it provision the Azure Secrets Engine into Vault using the MSI of the virtual machine.

# Example Usage

```terraform
module "stack_azure_hashicorp_vault" {
    source  = "app.terraform.io/jared-holgate-hashicorp/stack_azure_hashicorp_vault/jaredholgate"
    environment = var.deployment_environment
    resource_group_name = format("%s%s", var.resource_group_name_prefix, var.deployment_environment)
    client_secret_for_unseal = var.client_secret_for_unseal
}
```