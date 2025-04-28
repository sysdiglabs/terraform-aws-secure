# AWS Agentless Scanning Module

This module is used for Volume Access integration in AWS. It creates the resources required to perform agentless EC2 host scanning.

The following resources will be created in each instrumented account through CloudFormation StackSet in provided regions:
- An `IAM Role` and associated `policies` that allows Sysdig to perform tasks necessary for agentless scanning.
- A `KMS key` used to transcript volume snapshots in the each region. `Alias` for this key in each region.

When run in Organizational mode, this module will be deployed via CloudFormation StackSets that should be created in the management account. They will create the above resources in each account in the organization, and automatically in any member accounts that are later added to the organization.

This module will also deploy a Trusted Role Component and a Crypto Key Component in Sysdig Backend for onboarded Sysdig Cloud Account.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.60.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.60.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1 |
| <a name="provider_sysdig"></a> [sysdig](#provider\_sysdig) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudformation_stack_set.ou_resources_stackset](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set) | resource |
| [aws_cloudformation_stack_set.primary_acc_stackset](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set) | resource |
| [aws_cloudformation_stack_set_instance.ou_stackset_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance) | resource |
| [aws_cloudformation_stack_set_instance.primary_acc_stackset_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance) | resource |
| [aws_iam_role.scanning_stackset_admin_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scanning_stackset_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachments_exclusive.scanning_stackset_execution_role_managed_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [sysdig_secure_cloud_auth_account_component.aws_crypto_key](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/resources/secure_cloud_auth_account_component) | resource |
| [sysdig_secure_cloud_auth_account_component.aws_scanning_role](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/resources/secure_cloud_auth_account_component) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_session_context.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_session_context) | data source |
| [aws_organizations_organization.org](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |
| [sysdig_secure_agentless_scanning_assets.assets](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_agentless_scanning_assets) | data source |
| [sysdig_secure_tenant_external_id.external_id](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_tenant_external_id) | data source |
| [sysdig_secure_trusted_cloud_identity.trusted_identity](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_trusted_cloud_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_auto_create_stackset_roles"></a> [auto\_create\_stackset\_roles](#input\_auto\_create\_stackset\_roles) | Whether to auto create the custom stackset roles to run SELF\_MANAGED stackset. Default is true | `bool` | `true` | no |
| <a name="input_failure_tolerance_percentage"></a> [failure\_tolerance\_percentage](#input\_failure\_tolerance\_percentage) | The percentage of accounts, per Region, for which stack operations can fail before AWS CloudFormation stops the operation in that Region | `number` | `90` | no |
| <a name="input_is_organizational"></a> [is\_organizational](#input\_is\_organizational) | (Optional) Set this field to 'true' to deploy Agentless Scanning to an AWS Organization (Or specific OUs) | `bool` | `false` | no |
| <a name="input_kms_key_deletion_window"></a> [kms\_key\_deletion\_window](#input\_kms\_key\_deletion\_window) | Deletion window for shared KMS key | `number` | `7` | no |
| <a name="input_mgt_stackset"></a> [mgt\_stackset](#input\_mgt\_stackset) | (Optional) Indicates if the management stackset should be deployed | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the installation. Assigned to most child resource(s) | `string` | `"sysdig-secure-scanning"` | no |
| <a name="input_org_units"></a> [org\_units](#input\_org\_units) | TO BE DEPRECATED on 30th November, 2025: Please work with Sysdig to migrate to using `include_ouids` instead.<br>(Optional) List of Organization Unit IDs in which to setup Agentless Scanning. By default, Agentless Scanning will be setup in all accounts within the Organization. This field is ignored if `is_organizational = false` | `set(string)` | `[]` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | (Optional) List of regions in which to install Agentless Scanning | `set(string)` | `[]` | no |
| <a name="input_scanning_account_id"></a> [scanning\_account\_id](#input\_scanning\_account\_id) | The identifier of the account that will receive volume snapshots | `string` | `"878070807337"` | no |
| <a name="input_stackset_admin_role_arn"></a> [stackset\_admin\_role\_arn](#input\_stackset\_admin\_role\_arn) | (Optional) stackset admin role to run SELF\_MANAGED stackset | `string` | `""` | no |
| <a name="input_stackset_execution_role_name"></a> [stackset\_execution\_role\_name](#input\_stackset\_execution\_role\_name) | (Optional) stackset execution role name to run SELF\_MANAGED stackset | `string` | `""` | no |
| <a name="input_sysdig_secure_account_id"></a> [sysdig\_secure\_account\_id](#input\_sysdig\_secure\_account\_id) | ID of the Sysdig Cloud Account to enable Agentless Scanning for (incase of organization, ID of the Sysdig management account) | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning | `map(string)` | <pre>{<br>  "product": "sysdig-secure-for-cloud"<br>}</pre> | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Default timeout values for create, update, and delete operations | `string` | `"30m"` | no |
| <a name="input_include_ouids"></a> [include\_ouids](#input\_include\_ouids)                                                | ouids to include for organization                                                                                                                     | `set(string)` | `[]`                                                        |    no    |
| <a name="input_exclude_ouids"></a> [exclude\_ouids](#input\_exclude\_ouids)                                                | ouids to exclude for organization                                                                                                                     | `set(string)` | `[]`                                                        |    no    |
| <a name="input_include_accounts"></a> [include\_accounts](#input\_include\_accounts)                                       | accounts to include for organization                                                                                                                  | `set(string)` | `[]`                                                        |    no    |
| <a name="input_exclude_accounts"></a> [exclude\_accounts](#input\_exclude\_accounts)                                       | accounts to exclude for organization                                                                                                                  | `set(string)` | `[]`                                                        |    no    |


## Outputs

| Name | Description |
|------|-------------|
| <a name="output_crypto_key_component_id"></a> [crypto\_key\_component\_id](#output\_crypto\_key\_component\_id) | Component identifier of KMS crypto key created in Sysdig Backend for Agentless Scanning |
| <a name="output_scanning_role_component_id"></a> [scanning\_role\_component\_id](#output\_scanning\_role\_component\_id) | Component identifier of scanning role created in Sysdig Backend for Agentless Scanning |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Authors

Module is maintained by [Sysdig](https://sysdig.com).

## License

Apache 2 Licensed. See LICENSE for full details.
