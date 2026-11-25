# aks-cluster

## Requirements

Terraform >= 1.7, Azure provider >= 3.100. Run `terraform test` for offline validation (no Azure credentials required).

AKS cluster with workload identity, Azure RBAC, network policy, and optional Log Analytics integration. Works in Azure commercial and Azure Government — set `environment = "usgovernment"` in the provider block.

## Security defaults

| Default | Why |
|---|---|
| Private cluster | No public API server endpoint |
| Workload identity + OIDC issuer | Pods authenticate to Azure without mounted secrets |
| Azure RBAC | Kubernetes RBAC backed by Entra ID — no local cluster-admin credentials |
| Azure network policy | Pod-to-pod traffic controlled at the network layer |
| User-assigned managed identity | Explicit identity lifecycle separate from cluster lifecycle |
| Azure Policy add-on | Azure Policy assignments (e.g. pod security baselines) are enforced in-cluster. Needs the `Microsoft.PolicyInsights` resource provider registered |

## Customer-managed-key disk encryption

Set `disk_encryption_set_id` to encrypt node OS and data disks with your own key. It's off by default because it needs a disk encryption set and Key Vault that you provide:

- The disk encryption set's own identity must already have key access in its Key Vault.
- The module grants the cluster identity **Reader** on the set before creating the cluster, so whoever runs `apply` needs permission to create role assignments on it (e.g. User Access Administrator).
- Adding, changing or removing it on an existing cluster **forces cluster replacement**. Decide before the first apply.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | Cluster name |
| `location` | string | — | Azure region |
| `resource_group_name` | string | — | Must already exist |
| `kubernetes_version` | string | — | e.g. `"1.35"` |
| `subnet_id` | string | — | Subnet for all node pools |
| `private_cluster` | bool | `true` | Disable public API endpoint |
| `system_node_pool` | object | Standard_D4s_v3 ×2 | System pool config |
| `additional_node_pools` | map(object) | `{}` | Extra node pools |
| `network_policy` | string | `"azure"` | `"azure"` or `"calico"` |
| `service_cidr` | string | `172.16.0.0/16` | Kubernetes service CIDR |
| `dns_service_ip` | string | `172.16.0.10` | Cluster DNS IP |
| `log_analytics_workspace_id` | string | `null` | OMS agent workspace |
| `azure_policy_enabled` | bool | `true` | Azure Policy add-on |
| `disk_encryption_set_id` | string | `null` | Disk encryption set for customer-managed-key disk encryption; `null` uses platform-managed keys |
| `tags` | map(string) | `{}` | Extra tags |

## Outputs

`cluster_id`, `cluster_name`, `oidc_issuer_url`, `kube_config`, `identity_principal_id`
