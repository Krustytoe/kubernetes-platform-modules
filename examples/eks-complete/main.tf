terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-gov-west-1"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

module "eks" {
  source = "../../modules/eks-cluster"

  name               = "platform-prod"
  kubernetes_version = "1.35"
  subnet_ids         = ["subnet-aaaa1111", "subnet-bbbb2222"]

  node_groups = {
    general = {
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      min_size       = 1
      max_size       = 10
    }
    spot = {
      instance_types = ["m6i.large", "m6a.large", "m5.large"]
      capacity_type  = "SPOT"
      desired_size   = 3
      min_size       = 0
      max_size       = 20
    }
  }

  # Explicit access instead of implicit creator-admin: platform team gets cluster-admin,
  # an app team gets edit rights in its own namespace only.
  access_entries = {
    platform-admins = {
      principal_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/platform-admins"
      policy_associations = {
        AmazonEKSClusterAdminPolicy = {}
      }
    }
    payments-team = {
      principal_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/payments-developers"
      policy_associations = {
        AmazonEKSEditPolicy = { namespaces = ["payments"] }
      }
    }
  }

  tags = { env = "prod", managed-by = "terraform" }
}
