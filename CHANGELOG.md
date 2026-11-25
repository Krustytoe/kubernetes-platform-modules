# Changelog

## [0.3.0](https://github.com/Krustytoe/kubernetes-platform-modules/compare/v0.2.0...v0.3.0) (2026-11-25)


### Features

* add Azure Policy add-on and customer-managed-key disk encryption to aks-cluster ([#17](https://github.com/Krustytoe/kubernetes-platform-modules/issues/17)) ([5964b49](https://github.com/Krustytoe/kubernetes-platform-modules/commit/5964b494a66715b89d07f54eb1e2f18c63751b6b))

## [0.2.0](https://github.com/Krustytoe/kubernetes-platform-modules/compare/v0.1.2...v0.2.0) (2026-11-25)


### ⚠ BREAKING CHANGES

* **eks-cluster:** addons is now map(object({ addon_version = optional(string) })) instead of list(string). New default bootstrap_cluster_creator_admin_permissions = false forces replacement of clusters created by 0.1.x; set it to true for existing clusters. CONFIG_MAP clusters must step through API_AND_CONFIG_MAP. See modules/eks-cluster/README.md "Upgrading from 0.1.x".

### Features

* **eks-cluster:** access entries, Pod Identity for EBS CSI, explicit add-on versions ([#13](https://github.com/Krustytoe/kubernetes-platform-modules/issues/13)) ([ca19635](https://github.com/Krustytoe/kubernetes-platform-modules/commit/ca19635fe4b13a64c8b8a75d4be3f4c855e32647))

## [0.1.2](https://github.com/Krustytoe/kubernetes-platform-modules/compare/v0.1.1...v0.1.2) (2026-10-30)


### Bug Fixes

* move examples and tests from Kubernetes 1.31 to 1.35 ([#10](https://github.com/Krustytoe/kubernetes-platform-modules/issues/10)) ([5ad3b2d](https://github.com/Krustytoe/kubernetes-platform-modules/commit/5ad3b2d6a4660cb42057fc5fb91643617f0fbe4e))

## [0.1.1](https://github.com/Krustytoe/kubernetes-platform-modules/compare/v0.1.0...v0.1.1) (2026-10-06)


### Bug Fixes

* add admin_group_object_ids to AKS AAD RBAC block for azurerm 4.x ([45f108c](https://github.com/Krustytoe/kubernetes-platform-modules/commit/45f108ca4d71a41dfae3fc2554fb681b2ca16497))
* add managed=true to AAD RBAC block in aks-cluster ([4df8055](https://github.com/Krustytoe/kubernetes-platform-modules/commit/4df805540c7b1b290edbf6ab80123413cd9cf267))
* add required_version/required_providers to examples, remove unused data source ([4473ae0](https://github.com/Krustytoe/kubernetes-platform-modules/commit/4473ae013d3ab6e72c755ed29b62c78ec3fdc9f4))
