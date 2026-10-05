variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version, e.g. \"1.31\"."
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

variable "addons" {
  description = "EKS managed add-ons to enable."
  type        = list(string)
  default     = ["vpc-cni", "coredns", "kube-proxy", "aws-ebs-csi-driver"]
}

variable "tags" {
  description = "Tags merged onto every resource."
  type        = map(string)
  default     = {}
}
