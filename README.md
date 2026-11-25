# kubernetes-platform-modules

[![CI](https://github.com/Krustytoe/kubernetes-platform-modules/actions/workflows/terraform.yml/badge.svg)](https://github.com/Krustytoe/kubernetes-platform-modules/actions/workflows/terraform.yml) [![Release](https://img.shields.io/github/v/release/Krustytoe/kubernetes-platform-modules)](https://github.com/Krustytoe/kubernetes-platform-modules/releases/latest) [![License](https://img.shields.io/github/license/Krustytoe/kubernetes-platform-modules)](LICENSE)

Opinionated Terraform modules for production-grade Kubernetes clusters on AWS and Azure. Both modules work unchanged in GovCloud / Azure Government environments.

| Module | What it does | Key defaults |
|---|---|---|
| [`eks-cluster`](modules/eks-cluster) | EKS cluster with managed node groups, KMS secrets encryption, access entries, Pod Identity, and core add-ons | Private API endpoint; access entries only, no implicit creator-admin; IMDSv2 enforced; EBS CSI via Pod Identity; all control-plane logs on; rotating CMK for secrets |
| [`aks-cluster`](modules/aks-cluster) | AKS cluster with workload identity, Azure RBAC, and network policy | Private cluster; OIDC issuer + workload identity enabled; Azure network policy; user-assigned identity |

## Architecture

```mermaid
flowchart TB
  subgraph eks["eks-cluster: AWS / GovCloud"]
    eapi["EKS control plane<br/>private endpoint; public off by default"]
    ekms["KMS CMK, rotating<br/>envelope-encrypts Secrets"]
    elog["Control-plane logs<br/>api, audit, authenticator,<br/>controllerManager, scheduler"]
    eng["Managed node groups<br/>IMDSv2 required, hop limit 1<br/>max 33% unavailable on update"]
    eacc["Access entries<br/>authentication_mode API<br/>no implicit creator-admin"]
    eadd["Managed add-ons, versions resolved in plan<br/>vpc-cni, coredns, kube-proxy,<br/>eks-pod-identity-agent, aws-ebs-csi-driver"]
    epi["Pod Identity<br/>EBS CSI controller role"]
    ekms -. "encrypts" .-> eapi
    eacc --> eapi
    eapi --> elog
    eapi --> eng
    eng --> eadd
    epi --> eadd
  end

  subgraph aks["aks-cluster: Azure / Azure Government"]
    aapi["AKS control plane<br/>private cluster by default"]
    aid["User-assigned identity"]
    arbac["Entra ID + Azure RBAC<br/>admin groups"]
    awi["OIDC issuer + workload identity<br/>pods get Azure tokens, no stored secrets"]
    anp["System + user node pools<br/>Azure CNI, network policy azure or calico<br/>max surge 33%"]
    ala["Container Insights<br/>optional Log Analytics"]
    aid --> aapi
    arbac --> aapi
    aapi --> awi
    aapi --> anp
    aapi -.-> ala
  end
```

## Usage

**EKS**
```hcl
provider "aws" {
  region = "us-gov-west-1"
}

module "eks" {
  source = "git::https://github.com/Krustytoe/kubernetes-platform-modules.git//modules/eks-cluster?ref=v0.2.0" # x-release-please-version

  name               = "platform-prod"
  kubernetes_version = "1.35"
  subnet_ids         = module.vpc.private_subnet_ids

  access_entries = {
    platform-admins = {
      principal_arn       = "arn:aws-us-gov:iam::111111111111:role/platform-admins"
      policy_associations = { AmazonEKSClusterAdminPolicy = {} }
    }
  }

  tags = { env = "prod" }
}
```

**AKS**
```hcl
provider "azurerm" {
  features {}
  # For Azure Government: environment = "usgovernment"
}

module "aks" {
  source = "git::https://github.com/Krustytoe/kubernetes-platform-modules.git//modules/aks-cluster?ref=v0.2.0" # x-release-please-version

  name                = "platform-prod"
  location            = "usgovvirginia"
  resource_group_name = "platform-rg"
  kubernetes_version  = "1.35"
  subnet_id           = module.vnet.subnet_ids["app"]
  tags                = { env = "prod" }
}
```

See [`examples/eks-complete`](examples/eks-complete) and [`examples/aks-complete`](examples/aks-complete) for full working examples.

## Design decisions

- **Private API by default.** EKS keeps the public endpoint off unless you opt in *and* supply `public_access_cidrs`; AKS defaults to a private cluster. Exposure is a deliberate decision, not a default.
- **IMDSv2 with hop limit 1 on every EKS node.** A compromised pod can't reach the node's instance metadata and borrow its IAM credentials, a common container-escape path.
- **Secrets are envelope-encrypted with a customer-managed key.** The module creates a rotating CMK, or you bring your own for centralized key management.
- **Identity over secrets.** AKS enables the OIDC issuer and workload identity so pods authenticate to Azure without mounted credentials; cluster access is governed by Entra ID groups through Azure RBAC. EKS runs the Pod Identity agent and gives the EBS CSI controller its own IAM role through it, so the node role never carries storage permissions.
- **Cluster access is explicit on EKS.** `authentication_mode = "API"` (access entries, no aws-auth ConfigMap) and the identity that runs `apply` gets no implicit cluster-admin. Grant access through `access_entries`, cluster-wide or per namespace.
- **Add-on versions show up in the plan.** Unpinned add-ons resolve the default version for the cluster's Kubernetes version at plan time, so versions only move when you change `kubernetes_version` or pin one. Add-ons install after node groups so coredns and the EBS CSI controller don't time out in DEGRADED.
- **Full control-plane logging on EKS.** `audit` and `authenticator` logs are on by default because they're the first thing an incident responder or assessor asks for.
- **Upgrades trade speed for capacity at 33%.** Node groups roll at most a third of capacity at a time: fast enough for routine patching, conservative enough that a bad image doesn't take the whole pool.
- **Partition-aware.** Managed-policy ARNs are built from `aws_partition`, so the EKS module plans unchanged in `aws` and `aws-us-gov`.

## Requirements

Terraform >= 1.7. EKS: AWS provider >= 5.40. AKS: Azure provider >= 3.100. Run `terraform test` inside any module directory for offline validation — no cloud credentials required.

## Testing

```bash
cd modules/<module>
terraform test
```

All tests use `mock_provider` — no credentials needed.

## License

MIT
