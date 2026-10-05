terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100, < 5.0"
    }
  }
}

provider "azurerm" {
  features {}
  # For Azure Government: environment = "usgovernment"
}

module "aks" {
  source = "../../modules/aks-cluster"

  name                = "platform-prod"
  location            = "usgovvirginia"
  resource_group_name = "platform-rg"
  kubernetes_version  = "1.31"
  subnet_id           = "/subscriptions/<subscription-id>/resourceGroups/platform-rg/providers/Microsoft.Network/virtualNetworks/platform-prod/subnets/app"

  additional_node_pools = {
    app = {
      vm_size         = "Standard_D8s_v3"
      node_count      = 3
      os_disk_size_gb = 128
    }
  }

  log_analytics_workspace_id = "/subscriptions/<subscription-id>/resourceGroups/shared-rg/providers/Microsoft.OperationalInsights/workspaces/platform-logs"

  tags = { env = "prod", managed-by = "terraform" }
}
