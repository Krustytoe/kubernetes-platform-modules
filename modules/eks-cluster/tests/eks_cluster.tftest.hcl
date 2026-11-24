# Offline unit tests: `terraform test` against a mocked provider, no AWS credentials required.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws-us-gov"
    }
  }

  mock_data "aws_eks_addon_version" {
    defaults = {
      version = "v9.9.9-eksbuild.1"
    }
  }
}

variables {
  name               = "unit-test"
  kubernetes_version = "1.35"
  subnet_ids         = ["subnet-aaaa1111", "subnet-bbbb2222"]
}

run "secrets_encryption_configured" {
  command = plan

  assert {
    condition     = length(aws_eks_cluster.this.encryption_config) == 1
    error_message = "Cluster must have secrets encryption configured."
  }

  assert {
    condition     = toset(aws_eks_cluster.this.encryption_config[0].resources) == toset(["secrets"])
    error_message = "Only the 'secrets' resource should be encrypted."
  }
}

run "creates_rotating_cmk_when_none_supplied" {
  command = plan

  assert {
    condition     = length(aws_kms_key.secrets) == 1 && aws_kms_key.secrets[0].enable_key_rotation == true
    error_message = "A rotating CMK should be created when secrets_kms_key_arn is null."
  }
}

run "uses_supplied_kms_key" {
  command = plan

  variables {
    secrets_kms_key_arn = "arn:aws-us-gov:kms:us-gov-west-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = length(aws_kms_key.secrets) == 0
    error_message = "No KMS key should be created when secrets_kms_key_arn is supplied."
  }
}

run "private_endpoint_by_default" {
  command = plan

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_private_access == true
    error_message = "Private API endpoint access must be enabled."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == false
    error_message = "Public API endpoint access must be off by default."
  }
}

run "imdsv2_enforced_on_all_nodes" {
  command = plan

  assert {
    condition     = alltrue([for lt in aws_launch_template.node : lt.metadata_options[0].http_tokens == "required"])
    error_message = "All node launch templates must enforce IMDSv2 (http_tokens = required)."
  }

  assert {
    condition     = alltrue([for lt in aws_launch_template.node : lt.metadata_options[0].http_put_response_hop_limit == 1])
    error_message = "IMDS hop limit must be 1 to prevent pod-level metadata access."
  }
}

run "all_control_plane_logs_enabled" {
  command = plan

  assert {
    condition     = toset(aws_eks_cluster.this.enabled_cluster_log_types) == toset(["api", "audit", "authenticator", "controllerManager", "scheduler"])
    error_message = "All five control-plane log types must be enabled by default."
  }
}

run "partition_aware_policy_arns" {
  command = plan

  assert {
    condition     = can(regex("^arn:aws-us-gov:", aws_iam_role_policy_attachment.cluster_policy.policy_arn))
    error_message = "Policy ARNs must use the mocked GovCloud partition."
  }
}

run "access_entries_auth_and_no_implicit_admin" {
  command = plan

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "Cluster must use EKS access entries (authentication_mode = API) by default."
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].bootstrap_cluster_creator_admin_permissions == false
    error_message = "The cluster creator must not get implicit cluster-admin by default."
  }

  assert {
    condition     = length(aws_eks_access_entry.this) == 0
    error_message = "No access entries should exist unless access_entries is set."
  }
}

run "rejects_config_map_only_auth" {
  command = plan

  variables {
    authentication_mode = "CONFIG_MAP"
  }

  expect_failures = [var.authentication_mode]
}

run "access_entries_cluster_and_namespace_scope" {
  command = plan

  variables {
    access_entries = {
      admins = {
        principal_arn = "arn:aws-us-gov:iam::111111111111:role/platform-admins"
        policy_associations = {
          AmazonEKSClusterAdminPolicy = {}
        }
      }
      payments = {
        principal_arn = "arn:aws-us-gov:iam::111111111111:role/payments-developers"
        policy_associations = {
          AmazonEKSEditPolicy = { namespaces = ["payments"] }
          AmazonEKSViewPolicy = {}
        }
      }
    }
  }

  assert {
    condition     = length(aws_eks_access_entry.this) == 2 && length(aws_eks_access_policy_association.this) == 3
    error_message = "Expected 2 access entries and 3 policy associations."
  }

  assert {
    condition     = aws_eks_access_policy_association.this["admins/AmazonEKSClusterAdminPolicy"].policy_arn == "arn:aws-us-gov:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    error_message = "Access policy ARNs must be partition-aware."
  }

  assert {
    condition     = aws_eks_access_policy_association.this["admins/AmazonEKSClusterAdminPolicy"].access_scope[0].type == "cluster"
    error_message = "A policy with no namespaces must be cluster-scoped."
  }

  assert {
    condition = (
      aws_eks_access_policy_association.this["payments/AmazonEKSEditPolicy"].access_scope[0].type == "namespace" &&
      toset(aws_eks_access_policy_association.this["payments/AmazonEKSEditPolicy"].access_scope[0].namespaces) == toset(["payments"])
    )
    error_message = "A policy with namespaces must be limited to those namespaces."
  }
}

run "ebs_csi_gets_pod_identity_role" {
  command = plan

  assert {
    condition     = contains(keys(aws_eks_addon.this), "eks-pod-identity-agent")
    error_message = "The Pod Identity agent add-on must be enabled by default."
  }

  assert {
    condition     = length(aws_iam_role.ebs_csi) == 1 && jsondecode(aws_iam_role.ebs_csi[0].assume_role_policy).Statement[0].Principal.Service == "pods.eks.amazonaws.com"
    error_message = "EBS CSI role must trust EKS Pod Identity."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.ebs_csi[0].policy_arn == "arn:aws-us-gov:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    error_message = "EBS CSI role must carry the partition-aware AmazonEBSCSIDriverPolicy."
  }

  assert {
    condition = (
      aws_eks_pod_identity_association.ebs_csi[0].namespace == "kube-system" &&
      aws_eks_pod_identity_association.ebs_csi[0].service_account == "ebs-csi-controller-sa"
    )
    error_message = "Pod Identity association must target kube-system/ebs-csi-controller-sa."
  }
}

run "no_ebs_csi_role_without_addon" {
  command = plan

  variables {
    addons = {
      vpc-cni    = {}
      coredns    = {}
      kube-proxy = {}
    }
  }

  assert {
    condition     = length(aws_iam_role.ebs_csi) == 0 && length(aws_eks_pod_identity_association.ebs_csi) == 0
    error_message = "No EBS CSI IAM should be created when the add-on is disabled."
  }
}

run "ebs_csi_requires_pod_identity_agent" {
  command = plan

  variables {
    addons = {
      vpc-cni            = {}
      aws-ebs-csi-driver = {}
    }
  }

  expect_failures = [aws_eks_addon.this]
}

run "addon_versions_explicit" {
  command = plan

  variables {
    addons = {
      vpc-cni                = { addon_version = "v1.20.0-eksbuild.1" }
      coredns                = {}
      eks-pod-identity-agent = {}
      aws-ebs-csi-driver     = {}
    }
  }

  assert {
    condition     = aws_eks_addon.this["vpc-cni"].addon_version == "v1.20.0-eksbuild.1"
    error_message = "An explicit addon_version must be used as-is."
  }

  assert {
    condition     = aws_eks_addon.this["coredns"].addon_version == "v9.9.9-eksbuild.1"
    error_message = "Unpinned add-ons must resolve the default version for the cluster's Kubernetes version."
  }

  assert {
    condition     = !contains(keys(data.aws_eks_addon_version.this), "vpc-cni")
    error_message = "Pinned add-ons should not look up a version."
  }
}
