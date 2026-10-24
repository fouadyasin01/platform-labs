data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

# --------------------------------------------------
# EKS control-plane IAM role
# --------------------------------------------------

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --------------------------------------------------
# Worker-node IAM role
# --------------------------------------------------

resource "aws_iam_role" "nodes" {
  name = "${var.cluster_name}-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "worker_cni" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "worker_ecr" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

# --------------------------------------------------
# Cluster security group
# --------------------------------------------------

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS control-plane security group"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow outbound cluster communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

# --------------------------------------------------
# Worker security group
# --------------------------------------------------

resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "EKS worker-node security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Kubelet API from cluster security group"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  ingress {
    description = "Node-to-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Outbound access through NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-nodes-sg"
  }
}

resource "aws_security_group_rule" "cluster_from_nodes" {
  description              = "Worker nodes to EKS control plane"
  type                     = "ingress"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
}

# --------------------------------------------------
# EKS cluster
# --------------------------------------------------

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs

    security_group_ids = [aws_security_group.cluster.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_security_group_rule.cluster_from_nodes
  ]

  tags = {
    Name = var.cluster_name
  }
}

# --------------------------------------------------
# Cluster add-ons
# --------------------------------------------------

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  depends_on = [
    aws_iam_role_policy_attachment.worker_cni
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"

  depends_on = [
    aws_eks_node_group.this
  ]
}

# --------------------------------------------------
# Launch template
# --------------------------------------------------

resource "aws_launch_template" "nodes" {
  name_prefix            = "${var.cluster_name}-workers-"
  description            = "Launch template for EKS worker nodes"
  update_default_version = true

  vpc_security_group_ids = [aws_security_group.nodes.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.cluster_name}-worker"
    }
  }

  tags = {
    Name = "${var.cluster_name}-workers-launch-template"
  }
}

# --------------------------------------------------
# Managed node group
# --------------------------------------------------

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-workers"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.worker_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.desired_nodes
    min_size     = var.min_nodes
    max_size     = var.max_nodes
  }

  launch_template {
    id      = aws_launch_template.nodes.id
    version = tostring(aws_launch_template.nodes.latest_version)
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node,
    aws_iam_role_policy_attachment.worker_cni,
    aws_iam_role_policy_attachment.worker_ecr
  ]

  tags = {
    Name = "${var.project_name}-workers"
  }
}

# --------------------------------------------------
# Grant the Terraform caller cluster-admin access
# --------------------------------------------------

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

resource "aws_eks_access_entry" "terraform_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = data.aws_iam_session_context.current.issuer_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.terraform_admin.principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
