# Offline unit tests: `terraform test` against a mocked provider, no Azure credentials required.

mock_provider "azurerm" {}

variables {
  name                = "unit-test"
  location            = "usgovvirginia"
  resource_group_name = "platform-rg"
  kubernetes_version  = "1.35"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/platform-rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/app"
}

run "workload_identity_and_oidc_enabled" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.workload_identity_enabled == true
    error_message = "Workload identity must be enabled."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.oidc_issuer_enabled == true
    error_message = "OIDC issuer must be enabled for workload identity federation."
  }
}

run "private_cluster_by_default" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.private_cluster_enabled == true
    error_message = "Cluster must be private by default."
  }
}

run "azure_rbac_enabled" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled == true
    error_message = "Azure RBAC must be enabled."
  }
}

run "user_assigned_identity_used" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.identity[0].type == "UserAssigned"
    error_message = "Cluster must use a user-assigned managed identity."
  }
}

run "additional_node_pool_created" {
  command = plan

  variables {
    additional_node_pools = {
      app = {
        vm_size         = "Standard_D4s_v3"
        node_count      = 2
        os_disk_size_gb = 128
      }
    }
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster_node_pool.this) == 1
    error_message = "Expected one additional node pool."
  }
}

run "no_additional_pools_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_kubernetes_cluster_node_pool.this) == 0
    error_message = "No additional node pools should be created by default."
  }
}

run "azure_policy_enabled_by_default" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.azure_policy_enabled == true
    error_message = "Azure Policy add-on must be enabled by default."
  }
}

run "azure_policy_can_be_disabled" {
  command = plan

  variables {
    azure_policy_enabled = false
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.azure_policy_enabled == false
    error_message = "azure_policy_enabled = false must disable the add-on."
  }
}

run "platform_managed_keys_by_default" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.disk_encryption_set_id == null
    error_message = "No disk encryption set should be configured by default."
  }

  assert {
    condition     = length(azurerm_role_assignment.disk_encryption_set_reader) == 0
    error_message = "No disk encryption set role assignment should be created by default."
  }
}

run "customer_managed_key_disk_encryption" {
  command = plan

  variables {
    disk_encryption_set_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/platform-rg/providers/Microsoft.Compute/diskEncryptionSets/platform-des"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.disk_encryption_set_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/platform-rg/providers/Microsoft.Compute/diskEncryptionSets/platform-des"
    error_message = "Cluster must use the supplied disk encryption set."
  }

  assert {
    condition     = length(azurerm_role_assignment.disk_encryption_set_reader) == 1
    error_message = "Cluster identity must be granted access to the disk encryption set."
  }

  assert {
    condition     = azurerm_role_assignment.disk_encryption_set_reader[0].role_definition_name == "Reader"
    error_message = "Disk encryption set grant must be Reader."
  }
}

run "rejects_invalid_disk_encryption_set_id" {
  command = plan

  variables {
    disk_encryption_set_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/platform-rg/providers/Microsoft.KeyVault/vaults/platform-kv"
  }

  expect_failures = [var.disk_encryption_set_id]
}

run "rejects_invalid_network_policy" {
  command = plan

  variables {
    network_policy = "cilium"
  }

  expect_failures = [var.network_policy]
}
