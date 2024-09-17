# AWS Cloud Logs Module

This Module creates the resources required to send CloudTrail logs to Sysdig by enabling access to the CloudTrail associated s3 bucket through a dedicated IAM role.

The following resources will be created in each instrumented account:
- An IAM Role and associated policies that gives the ingestion component in Sysdig's account permission to list and retrieve items from it.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version   |
|------|-----------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0  |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.60.0 |
| <a name="requirement_sysdig"></a> [sysdig](#requirement\_sysdig) |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.60.0 |

## Modules

No modules.

## Resources

| Name                                                                                                                                                                             | Type |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------|
| [aws_iam_role.cloudlogs_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                         | resource |
| [aws_iam_policy_document.assume_cloudlogs_s3_access_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                    | data source |
| [aws_iam_policy_document.cloudlogs_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                                | data source |
| [sysdig_secure_cloud_auth_account_component.aws_cloud_logs](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/resources/secure_cloud_auth_account_component) | resource |

## Inputs

| Name                                                               | Description | Type | Default | Required |
|--------------------------------------------------------------------|-------------|------|---------|:--------:|
| <a name="input_folder_arn"></a> [folder\_arn](#input\_folder\_arn) | (Required) The ARN of your CloudTrail Bucket Folder | `string` | n/a | yes |
| <a name="input_bucket_arn"></a> [bucket\_arn](#input\_bucket\_arn) | (Required) The ARN of your s3 bucket associated with your Cloudtrail trail | `string` | n/a | yes |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name)    | (Required) The name of the IAM Role that will enable access to the Cloudtrail logs | `string` | `"cloudtrail-s3-bucket-read-access"` | no |
| <a name="input_tags"></a> [tags](#input\_tags)                     | (Optional) Sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning | `map(string)` | <pre>{<br>  "product": "sysdig-secure-for-cloud"<br>}</pre> | no |

## Outputs

| Name                                                                                                            | Description |
|-----------------------------------------------------------------------------------------------------------------|-------------|
| <a name="output_cloud_logs_component_id"></a> [cloud\_logs\_component\_id](#output\_cloud\_logs\_component\_id) | Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Authors

Module is maintained by [Sysdig](https://sysdig.com).

## License

Apache 2 Licensed. See LICENSE for full details.
