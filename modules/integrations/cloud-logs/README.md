# AWS Cloud Logs Module

This Module creates the resources required to send CloudTrail logs to Sysdig by enabling access to the CloudTrail
associated s3 bucket through a dedicated IAM role.

The following resources will be created based on the deployment scenario:

1. For single-account deployments:
   - An IAM Role in the account with permissions to access the S3 bucket directly
   - SNS Topic and Subscription for CloudTrail notifications

2. For organizational deployments (same account):
   - An IAM Role in the management account with permissions to access the S3 bucket directly
   - SNS Topic and Subscription for CloudTrail notifications

3. For organizational cross-account deployments:
   - A CloudFormation StackSet that deploys an IAM role directly in the bucket account
   - The role in the bucket account allows Sysdig to access S3 data directly
   - SNS Topic and Subscription for CloudTrail notifications

Additional features include:
- Support for KMS-encrypted S3 buckets by granting the necessary KMS decryption permissions
- Support for AWS GovCloud deployments

## Important Notes for Cross-Account Access

When using this module with organizational cross-account access (where CloudTrail bucket is in a different AWS account), the module automatically deploys a StackSet to configure the role in the bucket account.
The StackSet deployment requires appropriate permissions in the organization. The deploying account must have permission to create and manage StackSets in the organization.

### Working with KMS-encrypted S3 buckets

For KMS-encrypted S3 buckets, this module configures the necessary decrypt permissions on the IAM role. When using KMS encryption:
1. Provide the KMS key ARN using the `kms_key_arn` variable
2. For cross-account scenarios, specify the bucket account ID using the `bucket_account_id` variable
3. Ensure the KMS key policy allows the created role to use the decrypt operation

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

| Name                                                                      | Version   |
|---------------------------------------------------------------------------|-----------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0  |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 5.60.0 |
| <a name="requirement_sysdig"></a> [sysdig](#requirement\_sysdig)          | ~>1.52    |
| <a name="requirement_random"></a> [random](#requirement\_random)          | >= 3.1    |

## Providers

| Name                                                        | Version   |
|-------------------------------------------------------------|-----------|
| <a name="provider_aws"></a> [aws](#provider\_aws)           | >= 5.60.0 |
| <a name="provider_sysdig"></a> [sysdig](#provider\_sysdig)  | ~>1.52    |
| <a name="provider_random"></a> [random](#provider\_random)  | >= 3.1    |

## Modules

No modules.

## Resources

| Name                                                                                                                                                                             | Type        |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id)                                                                            | resource    |
| [aws_iam_role.cloudlogs_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                         | resource    |
| [aws_iam_role_policy.cloudlogs_s3_access_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                                    | resource    |
| [aws_sns_topic.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic)                                                  | resource    |
| [aws_sns_topic_policy.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy)                                    | resource    |
| [aws_sns_topic_subscription.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription)                        | resource    |
| [aws_cloudformation_stack_set.cloudlogs_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set)                          | resource    |
| [aws_cloudformation_stack_set_instance.cloudlogs_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance)        | resource    |
| [aws_iam_policy_document.assume_cloudlogs_s3_access_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                    | data source |
| [aws_iam_policy_document.cloudlogs_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                                | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                                                    | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                                                                      | data source |
| [sysdig_secure_trusted_cloud_identity.trusted_identity](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_trusted_cloud_identity)        | data source |
| [sysdig_secure_tenant_external_id.external_id](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_tenant_external_id)                     | data source |
| [sysdig_secure_cloud_ingestion_assets.assets](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_cloud_ingestion_assets)                  | data source |
| [sysdig_secure_cloud_auth_account_component.aws_cloud_logs](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/resources/secure_cloud_auth_account_component) | resource    |

## Inputs

| Name                                                                                                             | Description                                                                                                                                   | Type          | Default                                                     | Required |
|------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|---------------|-------------------------------------------------------------|:--------:|
| <a name="input_sysdig_secure_account_id"></a> [sysdig\_secure\_account\_id](#input\_sysdig\_secure\_account\_id) | (Required) ID of the Sysdig Cloud Account to enable Cloud Logs integration for (in case of organization, ID of the Sysdig management account) | `string`      | n/a                                                         |   yes    |
| <a name="input_bucket_arn"></a> [bucket\_arn](#input\_bucket\_arn)                                               | (Required) The ARN of your CloudTrail Bucket                                                                                                  | `string`      | n/a                                                         |   yes    |
| <a name="input_topic_arn"></a> [topic\_arn](#input\_topic\_arn)                                                  | SNS Topic ARN that will forward CloudTrail notifications to Sysdig Secure                                                                     | `string`      | n/a                                                         |   yes    |
| <a name="input_create_topic"></a> [create\_topic](#input\_create\_topic)                                         | true/false whether terraform should create the SNS Topic                                                                                      | `bool`        | `false`                                                     |    no    |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn)                                         | (Optional) ARN of the KMS key used to encrypt the S3 bucket. If provided, the IAM role will be granted permissions to decrypt using this key. | `string`      | `null`                                                     |    no    |
| <a name="input_bucket_account_id"></a> [bucket\_account\_id](#input\_bucket\_account\_id)                        | (Optional) AWS Account ID that owns the S3 bucket, if different from the account where the module is being applied. Required for cross-account organizational deployments. | `string`      | `null`                                                     |    no    |
| <a name="input_tags"></a> [tags](#input\_tags)                                                                   | (Optional) Sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning                           | `map(string)` | <pre>{<br>  "product": "sysdig-secure-for-cloud"<br>}</pre> |    no    |
| <a name="input_name"></a> [name](#input\_name)                                                                   | (Optional) Name to be assigned to all child resources. A suffix may be added internally when required.                                        | `string`      | sysdig-secure-cloudlogs                                     |    no    |
| <a name="input_regions"></a> [regions](#input\_regions)                                                          | (Optional) The list of AWS regions we want to scrape data from                                                                                | `set(string)` | `[]`                                                        |    no    |
| <a name="input_is_gov_cloud_onboarding"></a> [is\_gov\_cloud](#input\_is\_gov\_cloud\_onboarding)                | true/false whether secure-for-cloud should be deployed in a govcloud account/org or not                                                       | `bool`        | `false`                                                     |    no    |
| <a name="input_org_units"></a> [org\_units](#input\_org\_units)                                                  | (Optional) List of AWS Organizations organizational unit (OU) IDs in which to create the StackSet instances. Required for cross-account organizational deployments. | `list(string)` | `[]`                                                        |    no    |
| <a name="input_failure_tolerance_percentage"></a> [failure\_tolerance\_percentage](#input\_failure\_tolerance\_percentage) | (Optional) The percentage of account deployments that can fail before CloudFormation stops deployment in an organizational unit. Range: 0-100  | `number`      | `0`                                                         |    no    |
| <a name="input_timeout"></a> [timeout](#input\_timeout)                                                         | (Optional) The timeout for StackSet operations                                                                                                | `string`      | `"30m"`                                                     |    no    |

## Outputs

| Name                                                                                                            | Description                                                                                |
|-----------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| <a name="output_cloud_logs_component_id"></a> [cloud\_logs\_component\_id](#output\_cloud\_logs\_component\_id) | Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion |
| <a name="output_kms_policy_instructions"></a> [kms\_policy\_instructions](#output\_kms\_policy\_instructions)     | Instructions for updating KMS key policy when KMS encryption is enabled |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Authors

Module is maintained by [Sysdig](https://sysdig.com).

## License

Apache 2 Licensed. See LICENSE for full details.
