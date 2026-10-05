resource "azurerm_user_assigned_identity" "this" {
  name                = "${var.name}-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version

  private_cluster_enabled = var.private_cluster

  # Workload identity + OIDC issuer: required for pod-level Azure RBAC without mounted service account secrets.
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  default_node_pool {
    name            = "system"
    node_count      = var.system_node_pool.node_count
    vm_size         = var.system_node_pool.vm_size
    vnet_subnet_id  = var.subnet_id
    os_disk_size_gb = var.system_node_pool.os_disk_size_gb
    type            = "VirtualMachineScaleSets"

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  network_profile {
    network_plugin = "azure"
    network_policy = var.network_policy
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
  }

  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = var.additional_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  vnet_subnet_id        = var.subnet_id
  os_disk_size_gb       = each.value.os_disk_size_gb

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags
}
