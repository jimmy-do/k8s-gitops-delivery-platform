# =============================================================================
# modules/eks — EKS cluster + managed node group + IRSA OIDC provider
#
# What this module creates:
#   1. Cluster IAM role         — control plane uses this to manage AWS resources
#   2. EKS cluster (control plane only, AWS-managed)
#   3. Node IAM role            — workers use this to join, pull from ECR, etc.
#   4. Managed node group       — the actual EC2 instances
#   5. OIDC identity provider   — IRSA: pods assume IAM roles via service accounts
#
# What this module does NOT create (handled outside Terraform):
#   - aws-auth ConfigMap → EKS Access Entries (modern API) replaces it.
#   - Cluster Autoscaler / Karpenter → installed via Helm into the cluster.
#   - AWS Load Balancer Controller   → installed via Helm.
# =============================================================================

# -----------------------------------------------------------------------------
# Cluster IAM role
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -----------------------------------------------------------------------------
# Cluster security group
#
# EKS auto-creates one as well, but managing it explicitly lets us add
# ingress rules (e.g. allowing CI to reach the API server from a specific
# IP range, if you ever disable public endpoint access).
# -----------------------------------------------------------------------------

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster control plane security group."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

# -----------------------------------------------------------------------------
# EKS cluster (control plane)
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    # Control plane ENIs placed in both public and private subnets — gives
    # the AWS-managed control plane AZ redundancy.
    subnet_ids = concat(var.private_subnet_ids, var.public_subnet_ids)

    # Public endpoint: API server reachable from the internet.
    # For stricter security: set false and access via VPN / bastion / SSM
    # port forwarding. Public + restricted CIDR is a middle ground.
    endpoint_public_access  = true
    endpoint_private_access = true

    security_group_ids = [aws_security_group.cluster.id]
  }

  # The modern Access Entries API for granting kubectl access to IAM
  # principals. Replaces the legacy aws-auth ConfigMap — which was a
  # footgun: a typo in that ConfigMap could lock everyone out of the cluster.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = [
    "api",           # K8s API server requests
    "audit",         # who did what
    "authenticator", # IAM-to-K8s identity mapping
  ]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
}

# -----------------------------------------------------------------------------
# IRSA OIDC provider
#
# This is what makes "pod assumes IAM role" work. The EKS cluster issues OIDC
# tokens for service accounts; AWS trusts those tokens via this provider.
# -----------------------------------------------------------------------------

data "tls_certificate" "cluster_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster_oidc.certificates[0].sha1_fingerprint]
}

# -----------------------------------------------------------------------------
# Node group IAM role
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

# Worker node managed policies. for_each over a set so removing a policy
# later doesn't shift attachment indices for the others.
resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",          # join the cluster
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",               # VPC CNI ENI management
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", # ECR pull
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",       # SSM Session Manager for debug
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# -----------------------------------------------------------------------------
# Node security group
#
# EKS auto-creates one too, but exposing ours lets the RDS module reference
# it as an ingress source. Pod-to-pod across nodes uses this SG.
# -----------------------------------------------------------------------------

resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "EKS worker node security group. Egress all; ingress restricted by other SGs."
  vpc_id      = var.vpc_id

  egress {
    # Egress all by default — outbound to ECR, NAT, other VPC resources.
    # NetworkPolicy at the K8s layer further restricts per-pod egress.
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-node-sg"
    # Tells the VPC CNI which SG to attach to pod ENIs when using the
    # "security groups for pods" feature.
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Node-to-node communication: pods on Node A reaching pods on Node B.
resource "aws_security_group_rule" "node_to_node" {
  description              = "Allow nodes to communicate with each other."
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
  type                     = "ingress"
}

# -----------------------------------------------------------------------------
# Managed node group
# -----------------------------------------------------------------------------

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-default"
  node_role_arn   = aws_iam_role.node.arn

  # Nodes ONLY in private subnets. Public-subnet workers would have public
  # IPs, which is a footgun (direct internet attack surface).
  subnet_ids = var.private_subnet_ids

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND" # SPOT is cheaper but unsuitable for stateful workloads

  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  update_config {
    # Allow up to 1 node unavailable during cluster upgrades / AMI updates.
    # For larger node groups, switch to max_unavailable_percentage.
    max_unavailable = 1
  }

  # Without this, Terraform fights the Cluster Autoscaler / Karpenter: every
  # plan would show "desired_size: 3 -> 2" if autoscaling scaled out at
  # runtime. We manage min/max; the autoscaler manages desired.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node,
  ]

  tags = {
    Name = "${var.cluster_name}-node"
  }
}
