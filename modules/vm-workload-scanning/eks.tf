resource "aws_eks_access_entry" "viewer" {
  for_each      = var.eks_scanning_enabled && !var.is_organizational ? var.eks_clusters : []

  cluster_name  = each.value
  principal_arn = var.cspm_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "viewer" {
  for_each      = var.eks_scanning_enabled && !var.is_organizational ? var.eks_clusters : []

  cluster_name  = each.value
  policy_arn    = local.policy_arn
  principal_arn = var.cspm_role_arn
  access_scope {
    type = "cluster"
  }
}
