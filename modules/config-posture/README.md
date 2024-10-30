# AWS Config Posture Module

This module will deploy a Config Posture trust relationship (IAM Role) into a single AWS account, or each account within an AWS Organization.

The following resources will be created in each instrumented account:
- An IAM Role and associated IAM Policies mentioned below to grant Sysdig read only permissions to secure you AWS Account:
    - `arn:aws:iam::aws:policy/SecurityAudit`
    - a custom policy (`custom_resources_policy`)
    - An Access Policy attached to this role using a Sysdig provided `ExternalId`.

If instrumenting an AWS Organization, an `aws_cloudformation_stack_set` will be created in the Management Account.

If instrumenting an AWS Gov account/organization, IAM policies and resources will be created in `aws-us-gov` region.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.60.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.60.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_role.cspm_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachments_exclusive.cspm_role_managed_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy.cspm_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [sysdig_secure_cloud_auth_account_component.config_posture_role](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/resources/secure_cloud_auth_account_component) | resource |
| [aws_cloudformation_stack_set.stackset](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set) | resource |
| [aws_cloudformation_stack_set_instance.stackset_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance) | resource |
| [sysdig_secure_trusted_cloud_identity.trusted_identity](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_trusted_cloud_identity) | data source |
| [sysdig_secure_tenant_external_id.external_id](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_tenant_external_id) | data source |
| [aws_organizations_organization.org](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_failure_tolerance_percentage"></a> [failure\_tolerance\_percentage](#input\_failure\_tolerance\_percentage) | The percentage of accounts, per Region, for which stack operations can fail before AWS CloudFormation stops the operation in that Region | `number` | `90` | no |
| <a name="input_is_organizational"></a> [is\_organizational](#input\_is\_organizational) | true/false whether secure-for-cloud should be deployed in an organizational setup (all accounts of org) or not (only on default aws provider account) | `bool` | `false` | no |
| <a name="input_org_units"></a> [org\_units](#input\_org\_units) | Org unit id to install cspm | `set(string)` | `[]` | no |
| <a name="input_region"></a> [region](#input\_region) | Default region for resource creation in organization mode | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning | `map(string)` | <pre>{<br>  "product": "sysdig-secure-for-cloud"<br>}</pre> | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Default timeout values for create, update, and delete operations | `string` | `"30m"` | no |
| <a name="input_sysdig_secure_account_id"></a> [sysdig\_secure\_account\_id](#input\_sysdig\_secure\_account\_id) | (Required) The GUID of the management project or single project per sysdig representation | `string` | n/a | yes |
| <a name="input_is_gov_cloud"></a> [is\_gov\_cloud](#input\_is\_gov\_cloud) | true/false whether secure-for-cloud should be deployed in a govcloud account/org or not | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_config_posture_component_id"></a> [config\_posture\_component\_id](#output\_config\_posture\_component\_id) | The component id of the config posture trusted identity |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Authors

Module is maintained by [Sysdig](https://sysdig.com).

## License

Apache 2 Licensed. See LICENSE for full details.
