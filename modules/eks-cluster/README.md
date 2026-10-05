# eks-cluster

## Requirements

Terraform >= 1.7, AWS provider >= 5.0. Run `terraform test` for offline validation (no AWS credentials required).

EKS cluster with managed node groups, KMS envelope encryption for Kubernetes secrets, and all five control-plane log types forwarded to CloudWatch. Works unchanged in AWS commercial and GovCloud (partition-aware policy ARNs).

## Security defaults

| Default | Why |
|---|---|
| Private API endpoint only | Reduces attack surface; enable public access only with `public_access_cidrs` locked down |
| IMDSv2 enforced on all nodes | Prevents pods from harvesting instance credentials via IMDSv1 hop |
| KMS secrets encryption | Envelope-encrypts etcd secrets at rest; a rotating CMK is created when none supplied |
| All control-plane logs on | Full audit trail for `api`, `audit`, `authenticator`, `controllerManager`, `scheduler` |

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | Cluster name |
| `kubernetes_version` | string | — | e.g. `"1.31"` |
| `subnet_ids` | list(string) | — | At least two AZs |
| `endpoint_public_access` | bool | `false` | Enable public API endpoint |
| `public_access_cidrs` | list(string) | `[]` | CIDRs for public endpoint |
| `secrets_kms_key_arn` | string | `null` | Bring your own CMK |
| `enabled_log_types` | list(string) | all five | Control-plane log types |
| `node_groups` | map(object) | `general` m6i.large | Node group configs |
| `addons` | list(string) | vpc-cni, coredns, kube-proxy, ebs-csi | Managed add-ons |
| `tags` | map(string) | `{}` | Extra tags |

## Outputs

`cluster_name`, `cluster_endpoint`, `cluster_ca_data`, `oidc_issuer_url`, `node_role_arn`, `kms_key_arn`
