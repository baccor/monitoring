
terraform {
  required_providers {
    
    kubectl = {
      source = "alekc/kubectl"
    }

     helm = {
      source = "hashicorp/helm"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
      api_version = "client.authentication.k8s.io/v1"
      command = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", "eu-central-1",
      ]
    }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", "eu-central-1",
      ]}
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
      api_version = "client.authentication.k8s.io/v1"
      command = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", "eu-central-1",
      ]
    }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "ps1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "ps2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
}

resource "aws_route_table" "p_rt" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.p_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "ta1" {
  subnet_id      = aws_subnet.ps1.id
  route_table_id = aws_route_table.p_rt.id
}
resource "aws_route_table_association" "ta2" {
  subnet_id      = aws_subnet.ps2.id
  route_table_id = aws_route_table.p_rt.id
}
