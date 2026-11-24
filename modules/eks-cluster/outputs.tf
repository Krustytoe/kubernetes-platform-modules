output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  description = "Base64-encoded cluster CA certificate."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL — use for IRSA role trust policies."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_role_arn" {
  description = "IAM role ARN for node groups — use for additional policy attachments."
  value       = aws_iam_role.node.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for secrets encryption."
  value       = local.secrets_kms_key_arn
}

output "ebs_csi_role_arn" {
  description = "IAM role assumed by the EBS CSI controller through EKS Pod Identity (null when the add-on is disabled)."
  value       = try(aws_iam_role.ebs_csi[0].arn, null)
}

output "access_entry_principal_arns" {
  description = "Principal ARNs granted cluster access, keyed like var.access_entries."
  value       = { for k, v in aws_eks_access_entry.this : k => v.principal_arn }
}
