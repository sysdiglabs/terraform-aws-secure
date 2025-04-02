# AWS Onboarding Module

This module will deploy an Onboarding Trust Relationship (IAM Role) into a single AWS account, or each account within an
AWS Organization.

The following resources will be created in each instrumented account:

- An IAM Role and associated IAM Policies mentioned below to grant Sysdig read only permissions to secure you AWS
  Account:
    - `arn:aws:iam::aws:policy/AWSAccountManagementReadOnlyAccess`
    - `arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess` (for organizational setup)
    - An Access Policy attached to this role using a Sysdig provided `ExternalId`.

If instrumenting an AWS Organization, an `aws_cloudformation_stack_set` will be created in the Management Account.

If instrumenting an AWS Gov account/organization, IAM policies and resources will be created in `aws-us-gov` region.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

| Name                                                                      | Version   |
|---------------------------------------------------------------------------|-----------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0  |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 5.60.0 |
| <a name="requirement_random"></a> [random](#requirement\_random)          | >= 3.1    |
| <a name="requirement_sysdig"></a> [sysdig](#requirement\_sysdig)          | ~>1.51    |

## Providers

| Name                                              | Version   |
|---------------------------------------------------|-----------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.60.0 |

## Modules

No modules.

## Resources

| Name                                                                                                                                                                                          | Type        |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id)                                                                                         | resource    |
| [aws_iam_role.onboarding_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                                          | resource    |
| [aws_iam_role_policy.onboarding_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                                                     | resource    |
| [aws_iam_role_policy_attachments_exclusive.onboarding_role_managed_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource    |
| [sysdig_secure_cloud_auth_account.cloud_auth_account](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/resources/secure_cloud_auth_account)                              | resource    |
| [aws_cloudformation_stack_set.stackset](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set)                                                 | resource    |
| [aws_cloudformation_stack_set_instance.stackset_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance)                      | resource    |
| [sysdig_secure_organization.aws_organization](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/resources/secure_organization)                                            | resource    |
| [sysdig_secure_trusted_cloud_identity.trusted_identity](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_trusted_cloud_identity)                     | data source |
| [sysdig_secure_tenant_external_id.external_id](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_tenant_external_id)                                  | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                                                                 | data source |
| [aws_organizations_organization.org](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization)                                               | data source |

## Inputs

| Name                                                                                                                       | Description                                                                                                                                                                                  | Type          | Default                                                     | Required |
|----------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------|-------------------------------------------------------------|:--------:|
| <a name="input_failure_tolerance_percentage"></a> [failure\_tolerance\_percentage](#input\_failure\_tolerance\_percentage) | The percentage of accounts, per Region, for which stack operations can fail before AWS CloudFormation stops the operation in that Region                                                     | `number`      | `90`                                                        |    no    |
| <a name="input_is_organizational"></a> [is\_organizational](#input\_is\_organizational)                                    | true/false whether secure-for-cloud should be deployed in an organizational setup (all accounts of org) or not (only on default aws provider account)                                        | `bool`        | `false`                                                     |    no    |
| <a name="input_organizational_unit_ids"></a> [organizational\_unit\_ids](#input\_organizational\_unit\_ids)                | DEPRECATED: Defaults to `[]`, use `include_ouids` instead. Restrict onboarding to a set of organizational unit identifiers whose child accounts and organizational units are to be onboarded | `set(string)` | `[]`                                                        |    no    |
| <a name="input_region"></a> [region](#input\_region)                                                                       | Default region for resource creation in organization mode                                                                                                                                    | `string`      | `""`                                                        |    no    |
| <a name="input_tags"></a> [tags](#input\_tags)                                                                             | sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning                                                                                     | `map(string)` | <pre>{<br>  "product": "sysdig-secure-for-cloud"<br>}</pre> |    no    |
| <a name="input_timeout"></a> [timeout](#input\_timeout)                                                                    | Default timeout values for create, update, and delete operations                                                                                                                             | `string`      | `"30m"`                                                     |    no    |
| <a name="input_account_alias"></a> [account_alias](#input\_account\_alias)                                                 | Alias name of the AWS account                                                                                                                                                                | `string`      | `""`                                                        |    no    |
| <a name="input_is_gov_cloud_onboarding"></a> [is\_gov\_cloud\_onboarding](#input\_is\_gov\_cloud\_onboarding)              | true/false whether secure-for-cloud should be deployed in a govcloud account/org or not                                                                                                      | `bool`        | `false`                                                     |    no    |
| <a name="input_include_ouids"></a> [include\_ouids](#input\_include\_ouids)                                                | ouids to include for organization                                                                                                                                                            | `set(string)` | `[]`                                                        |    no    |
| <a name="input_exclude_ouids"></a> [exclude\_ouids](#input\_exclude\_ouids)                                                | ouids to exclude for organization                                                                                                                                                            | `set(string)` | `[]`                                                        |    no    |
| <a name="input_include_accounts"></a> [include\_accounts](#input\_include\_accounts)                                       | accounts to include for organization                                                                                                                                                         | `set(string)` | `[]`                                                        |    no    |
| <a name="input_exclude_accounts"></a> [exclude\_accounts](#input\_exclude\_accounts)                                       | accounts to exclude for organization                                                                                                                                                         | `set(string)` | `[]`                                                        |    no    |

## Outputs

| Name                                                                                                               | Description                                                                                    |
|--------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| <a name="output_sysdig_secure_account_id"></a> [sysdig\_secure\_account\_id](#output\_sysdig\_secure\_account\_id) | ID of the Sysdig Cloud Account created                                                         |
| <a name="output_is_organizational"></a> [is\_organizational](#output\_is\_organizational)                          | Boolean value to indicate if secure-for-cloud is deployed to an entire AWS organization or not |
| <a name="output_organizational_unit_ids"></a> [organizational\_unit\_ids](#output\_organizational\_unit\_ids)      | organizational unit ids onboarded                                                              |
| <a name="output_is_gov_cloud_onboarding"></a> [is\_gov\_cloud\_onboarding](#output\_is\_gov\_cloud\_onboarding)    | Boolean value to indicate if a govcloud account/organization is being onboarded                |
| <a name="output_include_ouids"></a> [include\_ouids](#output\_include\_ouids)                                      | ouids to include for organization                                                              |
| <a name="output_exclude_ouids"></a> [exclude\_ouids](#output\_exclude\_ouids)                                      | ouids to exclude for organization                                                              |
| <a name="output_include_accounts"></a> [organizational\_include\_accounts](#output\_include\_accounts)             | accounts to include for organization                                                           |
| <a name="output_exclude_accounts"></a> [organizational\_exclude\_accounts](#output\_exclude\_accounts)             | accounts to exclude for organization                                                           |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Authors

Module is maintained by [Sysdig](https://sysdig.com).

## License

Apache 2 Licensed. See LICENSE for full details.

