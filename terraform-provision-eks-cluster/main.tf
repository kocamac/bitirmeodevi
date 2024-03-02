# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "cetin-eks-cluster"
}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "cetin-eks-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)


  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
 


  single_nat_gateway   = true
  enable_dns_hostnames = true
  map_public_ip_on_launch = true
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 2
  }

}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.public_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    key_name = "Cetin_EKS_Key"  # Specify your keypair name here
  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t2.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2

      additional_security_group_rules = [
        {
          description              = "Allow SSH access"
          from_port                = 22
          to_port                  = 22
          protocol                 = "tcp"
          source_security_group_id = module.vpc.default_security_group_id
        },
        {
          description              = "Allow HTTP access"
          from_port                = 80
          to_port                  = 80
          protocol                 = "tcp"
          source_security_group_id = module.vpc.default_security_group_id
        },
      ]
    }


   }
}


data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}
