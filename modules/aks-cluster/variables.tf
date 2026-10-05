variable "name" {
  description = "AKS cluster name."
  type        = string
}

variable "location" {
  description = "Azure region, e.g. \"eastus\" or \"usgovvirginia\"."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into (must already exist)."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version, e.g. \"1.31\"."
  type        = string
}

variable "subnet_id" {
  description = "Subnet resource ID for all node pools."
  type        = string
}

variable "private_cluster" {
  description = "Deploy a fully private cluster with no public API server endpoint."
  type        = bool
  default     = true
}

variable "system_node_pool" {
  description = "System node pool configuration."
  type = object({
    vm_size         = string
    node_count      = number
    os_disk_size_gb = number
  })
  default = {
    vm_size         = "Standard_D4s_v3"
    node_count      = 2
    os_disk_size_gb = 128
  }
}

variable "additional_node_pools" {
  description = "Map of additional node pool name to config."
  type = map(object({
    vm_size         = string
    node_count      = number
    os_disk_size_gb = number
  }))
  default = {}
}

variable "network_policy" {
  description = "Network policy engine: \"azure\" or \"calico\"."
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "calico"], var.network_policy)
    error_message = "network_policy must be \"azure\" or \"calico\"."
  }
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services (must not overlap with node or VNet CIDRs)."
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for the cluster DNS service (must be within service_cidr)."
  type        = string
  default     = "172.16.0.10"
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for cluster diagnostics. Skipped when null."
  type        = string
  default     = null
}

variable "admin_group_object_ids" {
  description = "Azure AD group object IDs granted cluster-admin via Azure RBAC. Empty list enables Azure RBAC without pre-assigned admin groups."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags merged onto every resource."
  type        = map(string)
  default     = {}
}
