data "aws_partition" "current" {}

locals {
  # AWS Partner Revenue Measurement attributes the spend of tagged resources to Sysdig; it only covers the commercial partition.
  aws_partner_tag = var.enable_aws_partner_tag && data.aws_partition.current.partition == "aws" ? { "aws-apn-id-900918371795" = "pc:60xgt35ue7dm4pb1j44e9emhc" } : {}
  tags            = merge(var.tags, local.aws_partner_tag)
}
