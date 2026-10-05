provider "aws" {
  region = "us-gov-west-1"
}

module "eks" {
  source = "../../modules/eks-cluster"

  name               = "platform-prod"
  kubernetes_version = "1.31"
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

  tags = { env = "prod", managed-by = "terraform" }
}
