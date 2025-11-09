terraform {
  backend "azurerm" {
    resource_group_name  = "tf-state-rg"
    storage_account_name = "tfstatenomadcluster"
    container_name       = "tfstate"
    key                  = "nomad-cluster.tfstate"
  }
}
