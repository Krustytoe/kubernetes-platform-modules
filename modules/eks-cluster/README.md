# eks-cluster

## Requirements

Terraform >= 1.7, AWS provider >= 5.40. Run `terraform test` for offline validation (no AWS credentials required).

EKS cluster with managed node groups, KMS envelope encryption for Kubernetes secrets, EKS access entries, EKS Pod Identity, and all five control-plane log types forwarded to CloudWatch. Works unchanged in AWS commercial and GovCloud (partition-aware policy ARNs).

## Security defaults

| Default | Why |
|---|---|
| Private API endpoint only | Reduces attack surface; enable public access only with `public_access_cidrs` locked down |
| Access entries only (`authentication_mode = "API"`) | Cluster access is IAM-managed and auditable; no hand-edited aws-auth ConfigMap |
| No implicit creator-admin | The identity that runs `apply` (often a CI role) doesn't silently become cluster-admin; grant access through `access_entries` |
| IMDSv2 enforced on all nodes | Prevents pods from harvesting instance credentials via IMDSv1 hop |
| EBS CSI via Pod Identity | The CSI controller gets its own role (`AmazonEBSCSIDriverPolicy`); the node role carries no storage permissions |
| KMS secrets encryption | Envelope-encrypts etcd secrets at rest; a rotating CMK is created when none supplied |
| All control-plane logs on | Full audit trail for `api`, `audit`, `authenticator`, `controllerManager`, `scheduler` |

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | Cluster name |
| `kubernetes_version` | string | — | e.g. `"1.35"` |
| `subnet_ids` | list(string) | — | At least two AZs |
| `endpoint_public_access` | bool | `false` | Enable public API endpoint |
| `public_access_cidrs` | list(string) | `[]` | CIDRs for public endpoint |
| `secrets_kms_key_arn` | string | `null` | Bring your own CMK |
| `enabled_log_types` | list(string) | all five | Control-plane log types |
| `node_groups` | map(object) | `general` m6i.large | Node group configs |
| `authentication_mode` | string | `"API"` | `API` or `API_AND_CONFIG_MAP` (migration step) |
| `bootstrap_cluster_creator_admin_permissions` | bool | `false` | Give the creating identity cluster-admin. **Changing it forces cluster replacement.** |
| `access_entries` | map(object) | `{}` | `principal_arn`, optional `kubernetes_groups`, and `policy_associations` (access policy name → optional `namespaces`) |
| `addons` | map(object) | vpc-cni, coredns, kube-proxy, eks-pod-identity-agent, aws-ebs-csi-driver | Managed add-ons keyed by name; optional `addon_version` pins, otherwise the default for `kubernetes_version` |
| `tags` | map(string) | `{}` | Extra tags |

### Access entries example

```hcl
access_entries = {
  platform-admins = {
    principal_arn       = "arn:aws-us-gov:iam::111111111111:role/platform-admins"
    policy_associations = { AmazonEKSClusterAdminPolicy = {} }
  }
  payments-team = {
    principal_arn       = "arn:aws-us-gov:iam::111111111111:role/payments-developers"
    policy_associations = { AmazonEKSEditPolicy = { namespaces = ["payments"] } }
  }
}
```

### Workload IAM

Use EKS Pod Identity for your own workloads: create a role trusting `pods.eks.amazonaws.com` (`sts:AssumeRole` + `sts:TagSession`) and an `aws_eks_pod_identity_association` for the namespace/service account. `oidc_issuer_url` is still exported if you need IRSA.

## Outputs

`cluster_name`, `cluster_endpoint`, `cluster_ca_data`, `oidc_issuer_url`, `node_role_arn`, `kms_key_arn`, `ebs_csi_role_arn`, `access_entry_principal_arns`

## Upgrading from 0.1.x

This release changes defaults on existing clusters. Run `terraform plan` and read it before applying.

1. **`addons` is now a map.** Convert `["vpc-cni", "coredns"]` to `{ vpc-cni = {}, coredns = {} }`. The default adds `eks-pod-identity-agent`, which `aws-ebs-csi-driver` requires.
2. **Creator-admin.** Clusters created by 0.1.x have creator-admin enabled. Leaving the new `false` default **replaces the cluster**. For existing clusters, set `bootstrap_cluster_creator_admin_permissions = true`, add `access_entries` for your admins, and move to a new cluster later if you want it off.
3. **Authentication mode.** Clusters on `CONFIG_MAP` can't jump straight to `API`. Set `authentication_mode = "API_AND_CONFIG_MAP"`, apply, recreate the aws-auth mappings as `access_entries`, then switch to `"API"`. This change is one-way.
4. **EBS CSI.** The add-on now gets its IAM role through Pod Identity. If you attached `AmazonEBSCSIDriverPolicy` to `node_role_arn` yourself, remove it after the apply.
