# AWS Cloud Logs Module

This Module creates the resources required to send CloudTrail logs to Sysdig by enabling access to the CloudTrail
associated s3 bucket through a dedicated IAM role.

The following resources will be created in each instrumented account:

- An IAM Role and associated policies that gives the ingestion component in Sysdig's account permission to list and
  retrieve items from it.

If instrumenting an AWS Gov account/organization, resources will be created in `aws-us-gov` region.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.60.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |
| <a name="requirement_sysdig"></a> [sysdig](#requirement\_sysdig) | ~> 1.44 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.60.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1 |
| <a name="provider_sysdig"></a> [sysdig](#provider\_sysdig) | ~> 1.44 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.cloudlogs_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudlogs_s3_access_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_sns_topic.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [sysdig_secure_cloud_auth_account_component.aws_cloud_logs](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/resources/secure_cloud_auth_account_component) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_cloudlogs_s3_access_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cloudlogs_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [sysdig_secure_cloud_ingestion_assets.assets](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_cloud_ingestion_assets) | data source |
| [sysdig_secure_tenant_external_id.external_id](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_tenant_external_id) | data source |
| [sysdig_secure_trusted_cloud_identity.trusted_identity](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_trusted_cloud_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_arn"></a> [bucket\_arn](#input\_bucket\_arn) | (Required) The ARN of your CloudTrail Bucket | `string` | n/a | yes |
| <a name="input_create_topic"></a> [create\_topic](#input\_create\_topic) | true/false whether terraform should create the SNS Topic | `bool` | `false` | no |
| <a name="input_is_gov_cloud_onboarding"></a> [is\_gov\_cloud\_onboarding](#input\_is\_gov\_cloud\_onboarding) | true/false whether secure-for-cloud should be deployed in a govcloud account/org or not | `bool` | `false` | no |
| <a name="input_is_log_file_kms_encryption_enabled"></a> [is\_log\_file\_kms\_encryption\_enabled](#input\_is\_log\_file\_kms\_encryption\_enabled) | needed only if cloudtrail s3 bucket is located in different account. true/false whether log file encryption is enabled | `bool` | `false` | no |
| <a name="input_is_s3_bucket_in_different_account"></a> [is\_s3\_bucket\_in\_different\_account](#input\_is\_s3\_bucket\_in\_different\_account) | true/false whether cloudtrail s3 bucket is located in different account | `bool` | `false` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | KMS key ARN that is used to encrypt log files in s3 bucket | `string` | `""` | no |
| <a name="input_name"></a> [name](#input\_name) | (Optional) Name to be assigned to all child resources. A suffix may be added internally when required. Use default value unless you need to install multiple instances | `string` | `"sysdig-secure-cloudlogs"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | (Optional) The list of AWS regions we want to scrape data from | `set(string)` | `[]` | no |
| <a name="input_sysdig_secure_account_id"></a> [sysdig\_secure\_account\_id](#input\_sysdig\_secure\_account\_id) | ID of the Sysdig Cloud Account to enable Cloud Logs integration for (in case of organization, ID of the Sysdig management account) | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | (Optional) Sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning | `map(string)` | <pre>{<br>  "product": "sysdig-secure-for-cloud"<br>}</pre> | no |
| <a name="input_topic_arn"></a> [topic\_arn](#input\_topic\_arn) | SNS Topic ARN that will forward CloudTrail notifications to Sysdig Secure | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_logs_component_id"></a> [cloud\_logs\_component\_id](#output\_cloud\_logs\_component\_id) | Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion |
| <a name="output_extra_permissions_kms_key"></a> [extra\_permissions\_kms\_key](#output\_extra\_permissions\_kms\_key) | Extra permissions to add to KMS key policy |
| <a name="output_extra_permissions_s3_bucket"></a> [extra\_permissions\_s3\_bucket](#output\_extra\_permissions\_s3\_bucket) | Extra permissions to add to s3 bucket |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Authors

Module is maintained by [Sysdig](https://sysdig.com).

## License

Apache 2 Licensed. See LICENSE for full details.
