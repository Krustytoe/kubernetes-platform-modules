data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition
}

resource "aws_iam_role" "cluster" {
  name = "${var.name}-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_kms_key" "secrets" {
  count = var.secrets_kms_key_arn == null ? 1 : 0

  description         = "EKS secrets encryption for ${var.name}"
  enable_key_rotation = true
  tags                = var.tags
}

resource "aws_kms_alias" "secrets" {
  count = var.secrets_kms_key_arn == null ? 1 : 0

  name          = "alias/eks-${var.name}-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}

locals {
  secrets_kms_key_arn = var.secrets_kms_key_arn != null ? var.secrets_kms_key_arn : aws_kms_key.secrets[0].arn
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = var.additional_security_group_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  encryption_config {
    provider {
      key_arn = local.secrets_kms_key_arn
    }
    resources = ["secrets"]
  }

  # Access entries instead of the aws-auth ConfigMap, and no implicit cluster-admin for whoever
  # ran apply: access is granted explicitly through var.access_entries.
  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  enabled_cluster_log_types = var.enabled_log_types

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

resource "aws_iam_role" "node" {
  name = "${var.name}-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Launch template enforces IMDSv2 on every node — prevents pods from harvesting instance credentials via IMDSv1.
resource "aws_launch_template" "node" {
  for_each = var.node_groups

  name_prefix = "${var.name}-${each.key}-"

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = var.tags
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = each.value.instance_types
  capacity_type   = each.value.capacity_type

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}

# ---------------------------------------------------------------------------
# Cluster access (EKS access entries)
# ---------------------------------------------------------------------------

locals {
  access_policy_associations = merge([
    for entry_key, entry in var.access_entries : {
      for policy, scope in entry.policy_associations : "${entry_key}/${policy}" => {
        entry_key  = entry_key
        policy_arn = "arn:${local.partition}:eks::aws:cluster-access-policy/${policy}"
        namespaces = scope.namespaces
      }
    }
  ]...)
}

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = each.value.principal_arn
  kubernetes_groups = each.value.kubernetes_groups
  type              = "STANDARD"
  tags              = var.tags
}

resource "aws_eks_access_policy_association" "this" {
  for_each = local.access_policy_associations

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.this[each.value.entry_key].principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = length(each.value.namespaces) > 0 ? "namespace" : "cluster"
    namespaces = length(each.value.namespaces) > 0 ? each.value.namespaces : null
  }
}

# ---------------------------------------------------------------------------
# Add-ons
# ---------------------------------------------------------------------------

locals {
  ebs_csi_enabled = contains(keys(var.addons), "aws-ebs-csi-driver")
}

# Resolve the default add-on version for this Kubernetes version so the version is explicit in the
# plan and only moves when kubernetes_version (or an explicit addon_version) changes.
data "aws_eks_addon_version" "this" {
  for_each = { for name, cfg in var.addons : name => cfg if cfg.addon_version == null }

  addon_name         = each.key
  kubernetes_version = var.kubernetes_version
  most_recent        = false
}

resource "aws_eks_addon" "this" {
  for_each = var.addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = each.value.addon_version != null ? each.value.addon_version : data.aws_eks_addon_version.this[each.key].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags

  # coredns and the EBS CSI controller schedule pods: with no nodes they sit DEGRADED until the
  # apply times out. The EBS CSI controller also needs its Pod Identity association in place.
  depends_on = [
    aws_eks_node_group.this,
    aws_eks_pod_identity_association.ebs_csi,
  ]

  lifecycle {
    precondition {
      condition     = !local.ebs_csi_enabled || contains(keys(var.addons), "eks-pod-identity-agent")
      error_message = "aws-ebs-csi-driver needs the eks-pod-identity-agent add-on to receive its IAM role."
    }
  }
}

# ---------------------------------------------------------------------------
# EBS CSI driver IAM (EKS Pod Identity)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ebs_csi" {
  count = local.ebs_csi_enabled ? 1 : 0

  name = "${var.name}-ebs-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = local.ebs_csi_enabled ? 1 : 0

  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_pod_identity_association" "ebs_csi" {
  count = local.ebs_csi_enabled ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi[0].arn
  tags            = var.tags

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]
}
