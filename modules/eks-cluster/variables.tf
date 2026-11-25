variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version, e.g. \"1.35\"."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the control plane and node groups (at least two AZs required)."
  type        = list(string)
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs attached to the cluster control plane."
  type        = list(string)
  default     = []
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API server endpoint publicly. Disabled by default; enable only with public_access_cidrs locked down."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDRs permitted to reach the public API endpoint. Only used when endpoint_public_access = true."
  type        = list(string)
  default     = []
}

variable "secrets_kms_key_arn" {
  description = "Existing CMK ARN for Kubernetes secrets envelope encryption. A dedicated rotating key is created when null."
  type        = string
  default     = null
}

variable "enabled_log_types" {
  description = "Control-plane log types forwarded to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "node_groups" {
  description = "Managed node groups. Each entry creates a node group and a launch template with IMDSv2 enforced."
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    desired_size   = number
    min_size       = number
    max_size       = number
  }))
  default = {
    general = {
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      min_size       = 1
      max_size       = 10
    }
  }
}

variable "authentication_mode" {
  description = "Cluster authentication mode. \"API\" uses EKS access entries only; \"API_AND_CONFIG_MAP\" is the migration step for clusters still using the aws-auth ConfigMap."
  type        = string
  default     = "API"

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be \"API\" or \"API_AND_CONFIG_MAP\"; CONFIG_MAP alone is not supported by this module."
  }
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Grant the identity that creates the cluster cluster-admin. Off by default: grant access explicitly with access_entries. Changing this forces cluster replacement."
  type        = bool
  default     = false
}

variable "access_entries" {
  description = <<-EOT
    EKS access entries keyed by a stable name. policy_associations maps an EKS access policy name
    (AmazonEKSClusterAdminPolicy, AmazonEKSAdminPolicy, AmazonEKSEditPolicy, AmazonEKSViewPolicy, ...)
    to its scope: no namespaces = cluster-wide, otherwise limited to the listed namespaces.
  EOT
  type = map(object({
    principal_arn     = string
    kubernetes_groups = optional(list(string))
    policy_associations = optional(map(object({
      namespaces = optional(list(string), [])
    })), {})
  }))
  default = {}
}

variable "addons" {
  description = "EKS managed add-ons keyed by add-on name. addon_version = null uses the default version for kubernetes_version; set it to pin. aws-ebs-csi-driver requires eks-pod-identity-agent."
  type = map(object({
    addon_version = optional(string)
  }))
  default = {
    vpc-cni                = {}
    coredns                = {}
    kube-proxy             = {}
    eks-pod-identity-agent = {}
    aws-ebs-csi-driver     = {}
  }
}

variable "tags" {
  description = "Tags merged onto every resource."
  type        = map(string)
  default     = {}
}
