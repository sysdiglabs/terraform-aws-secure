# AWS Cloud Logs Module

This Module creates the resources required to send CloudTrail logs to Sysdig by enabling access to the CloudTrail
associated s3 bucket through a dedicated IAM role.

The following resources will be created in each instrumented account:

- An IAM Role and associated policies that gives the ingestion component in Sysdig's account permission to list and
  retrieve items from it.
- Support for KMS-encrypted S3 buckets by granting the necessary KMS decryption permissions.
- Support for cross-account S3 bucket access, allowing CloudTrail logs to be read from buckets in different AWS accounts.

If instrumenting an AWS Gov account/organization, resources will be created in `aws-us-gov` region.

## Important Notes for Cross-Account Access

When using this module to access CloudTrail logs from a bucket in a different AWS account, you need to configure permissions in both accounts:

1. In the account where this module is applied:
   - The module creates an IAM role with the necessary permissions
   - The role ARN is provided in the `cloudlogs_role_arn` output

2. In the account that owns the S3 bucket:
   - Add a bucket policy statement allowing access from the IAM role
   - If the bucket is encrypted with KMS, also modify the KMS key policy to allow decryption

Example bucket policy statement (to be added to the bucket policy in the bucket owner account):
```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "<cloudlogs_role_arn>"
  },
  "Action": [
    "s3:GetObject",
    "s3:ListBucket"
  ],
  "Resource": [
    "arn:aws:s3:::<BUCKET_NAME>",
    "arn:aws:s3:::<BUCKET_NAME>/*"
  ]
}
```

Example KMS key policy statement (to be added to the key policy in the key owner account):
```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "<cloudlogs_role_arn>"
  },
  "Action": [
    "kms:Decrypt"
  ],
  "Resource": "*"
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

| Name                                                                      | Version   |
|---------------------------------------------------------------------------|-----------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0  |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 5.60.0 |
| <a name="requirement_sysdig"></a> [sysdig](#requirement\_sysdig)          | ~>1.39    |
| <a name="requirement_random"></a> [random](#requirement\_random)          | >= 3.1    |

## Providers

| Name                                                        | Version   |
|-------------------------------------------------------------|-----------|
| <a name="provider_aws"></a> [aws](#provider\_aws)           | >= 5.60.0 |
| <a name="provider_sysdig"></a> [sysdig](#provider\_sysdig)  | ~>1.39    |
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
| [aws_iam_policy_document.assume_cloudlogs_s3_access_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                    | data source |
| [aws_iam_policy_document.cloudlogs_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                                | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                                                    | data source |
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
| <a name="input_kms_key_arns"></a> [kms\_key\_arns](#input\_kms\_key\_arns)                                       | (Optional) List of KMS Key ARNs used to encrypt the S3 bucket. If provided, the IAM role will be granted permissions to decrypt using these keys. | `list(string)` | `null`                                                     |    no    |
| <a name="input_bucket_account_id"></a> [bucket\_account\_id](#input\_bucket\_account\_id)                        | (Optional) AWS Account ID that owns the S3 bucket, if different from the account where the module is being applied. If not specified, the current account is assumed to be the bucket owner. | `string`      | `null`                                                     |    no    |
| <a name="input_tags"></a> [tags](#input\_tags)                                                                   | (Optional) Sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning                           | `map(string)` | <pre>{<br>  "product": "sysdig-secure-for-cloud"<br>}</pre> |    no    |
| <a name="input_name"></a> [name](#input\_name)                                                                   | (Optional) Name to be assigned to all child resources. A suffix may be added internally when required.                                        | `string`      | sysdig-secure-cloudlogs                                     |    no    |
| <a name="input_regions"></a> [regions](#input\_regions)                                                          | (Optional) The list of AWS regions we want to scrape data from                                                                                | `set(string)` | `[]`                                                        |    no    |
| <a name="input_is_gov_cloud_onboarding"></a> [is\_gov\_cloud](#input\_is\_gov\_cloud\_onboarding)                | true/false whether secure-for-cloud should be deployed in a govcloud account/org or not                                                       | `bool`        | `false`                                                     |    no    |

## Outputs

| Name                                                                                                            | Description                                                                                |
|-----------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| <a name="output_cloud_logs_component_id"></a> [cloud\_logs\_component\_id](#output\_cloud\_logs\_component\_id) | Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion |
| <a name="output_cloudlogs_role_arn"></a> [cloudlogs\_role\_arn](#output\_cloudlogs\_role\_arn)                  | ARN of the IAM role created for accessing CloudTrail logs. Use this ARN in the bucket policy when configuring cross-account access. |
| <a name="output_cross_account_setup_instructions"></a> [cross\_account\_setup\_instructions](#output\_cross\_account\_setup\_instructions) | Instructions for completing the cross-account setup in the bucket owner account. Includes examples of the required bucket and KMS policies. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Authors

Module is maintained by [Sysdig](https://sysdig.com).

## License

Apache 2 Licensed. See LICENSE for full details.
