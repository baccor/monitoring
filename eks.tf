
data "http" "ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  ipc = chomp(data.http.ip.response_body)
  ip = "${local.ipc}/32"
}

resource "aws_iam_role" "cni_irsa" {
  name = "cni_irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"

      Principal = {
        Federated = module.eks.oidc_provider_arn
      }

      Action = "sts:AssumeRoleWithWebIdentity"

      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com",
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-node"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cnia" {
  role = aws_iam_role.cni_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_addon" "vpc_cni" {
  addon_name = "vpc-cni"
  cluster_name = module.eks.cluster_name
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn = aws_iam_role.cni_irsa.arn
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.8.0"
  kubernetes_version = "1.33"
  

  addons = {
    coredns = {}
    kube-proxy = {}
    }

  eks_managed_node_groups = {
    eks_nodes = {
      subnet_ids = [aws_subnet.ps1.id]
      desired_size = 5
      max_size = 5
      min_size = 5
      instance_types = ["t2.micro"]
      ami_type = "AL2023_x86_64_STANDARD"
      capacity_type = "ON_DEMAND"
      disk_size = 20
      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        AmazonEC2ContainerRegistryReadOnly ="arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }

    prometheus = {
      name = "prometheus"
      labels = { role = "prometheus" }
      taints = { 
        dedicated = { 
          key = "dedicated"
          value = "prometheus"
          effect = "NO_SCHEDULE"
        }
      }
    

      subnet_ids = [aws_subnet.ps1.id]
      desired_size = 1
      max_size = 1
      min_size = 1
      instance_types = ["t2.micro"]
      ami_type = "AL2023_x86_64_STANDARD"
      capacity_type = "ON_DEMAND"
      disk_size = 20
      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        AmazonEC2ContainerRegistryReadOnly ="arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }



  name = "eksc"
  subnet_ids = [aws_subnet.ps1.id, aws_subnet.ps2.id]
  vpc_id = aws_vpc.vpc.id
  endpoint_private_access = true
  endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true
  enable_irsa = true
  endpoint_public_access_cidrs = [local.ip]
  create_iam_role = true
  create_node_iam_role = true
}

