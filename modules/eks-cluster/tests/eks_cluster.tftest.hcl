# Offline unit tests: `terraform test` against a mocked provider, no AWS credentials required.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws-us-gov"
    }
  }
}

variables {
  name               = "unit-test"
  kubernetes_version = "1.31"
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
