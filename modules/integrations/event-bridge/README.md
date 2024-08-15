# AWS Event Bridge Module

This Module creates the resources required to send CloudTrail logs to Sysdig via AWS EventBridge for Log Ingestion. These resources enable Threat Detection in the given single account, or AWS Organization.

The following resources will be created in each instrumented account through CloudFormation StackSet in provided regions:
- An `EventBridge Rule` that captures all CloudTrail events from the defaul EventBridge Bus
- An `EventBridge Target` that sends these events to an EventBridge Bus is Sysdig's AWS Account
- An `IAM Role` and associated policies that gives the EventBridge Bus in the source account permission to call PutEvent on the EventBridge Bus in Sysdig's Account.

When run in Organizational mode, the CloudFormation StackSet should be applied to the management account. This will create the above resources in each account in the organization, and automatically in any member accounts that are later added to the organization.

This module will also deploy an Event Bridge Component in Sysdig Backend for onboarded Sysdig Cloud Account.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.60.0 |
| <a name="requirement_sysdig"></a> [sysdig](#requirement\_sysdig) |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |


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
| [aws_iam_role.event_bus_invoke_remote_event_bus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.event_bus_stackset_admin_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.event_bus_stackset_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_cloudformation_stack_set.single-acc-stackset](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set) | resource |
| [aws_cloudformation_stack_set_instance.single_acc_stackset_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance) | resource |
| [sysdig_secure_cloud_auth_account_component.aws_event_bridge](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/resources/secure_cloud_auth_account_component) | resource |
| [aws_iam_policy_document.cloud_trail_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [sysdig_secure_cloud_ingestion_assets.assets](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_cloud_ingestion_assets) | data source |
| [sysdig_secure_trusted_cloud_identity.trusted_identity](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_trusted_cloud_identity) | data source |
| [sysdig_secure_tenant_external_id.external_id](https://registry.terraform.io/providers/sysdiglabs/sysdig/latest/docs/data-sources/secure_tenant_external_id) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_event_pattern"></a> [event\_pattern](#input\_event\_pattern) | Event pattern for CloudWatch Event Rule | `string` | `"{\n  \"detail-type\": [\n    \"AWS API Call via CloudTrail\",\n    \"AWS Console Sign In via CloudTrail\",\n    \"AWS Service Event via CloudTrail\",\n    \"Object Access Tier Changed\",\n    \"Object ACL Updated\",\n    \"Object Created\",\n    \"Object Deleted\",\n    \"Object Restore Completed\",\n    \"Object Restore Expired\",\n    \"Object Restore Initiated\",\n    \"Object Storage Class Changed\",\n    \"Object Tags Added\",\n    \"Object Tags Deleted\",\n    \"GuardDuty Finding\"\n  ]\n}\n"` | no |
| <a name="input_failure_tolerance_percentage"></a> [failure\_tolerance\_percentage](#input\_failure\_tolerance\_percentage) | The percentage of accounts, per Region, for which stack operations can fail before AWS CloudFormation stops the operation in that Region | `number` | `90` | no |
| <a name="input_is_organizational"></a> [is\_organizational](#input\_is\_organizational) | (Optional) Set this field to 'true' to deploy EventBridge to an AWS Organization (Or specific OUs) | `bool` | `false` | no |
| <a name="input_mgt_stackset"></a> [mgt\_stackset](#input\_mgt\_stackset) | (Optional) Indicates if the management stackset should be deployed | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | (Optional) Name to be assigned to all child resources. A suffix may be added internally when required. Use default value unless you need to install multiple instances | `string` | `"sysdig-secure-events"` | no |
| <a name="input_org_units"></a> [org\_units](#input\_org\_units) | (Optional) List of Organization Unit IDs in which to setup EventBridge. By default, EventBridge will be setup in all accounts within the Organization. This field is ignored if `is_organizational = false` | `set(string)` | `[]` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | (Optional) List of regions in which to setup EventBridge. By default, current region is selected | `set(string)` | `[]` | no |
| <a name="input_rule_state"></a> [rule\_state](#input\_rule\_state) | State of the rule. When state is ENABLED, the rule is enabled for all events except those delivered by CloudTrail. To also enable the rule for events delivered by CloudTrail, set state to ENABLED\_WITH\_ALL\_CLOUDTRAIL\_MANAGEMENT\_EVENTS. | `string` | `"ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS"` | no |
| <a name="input_stackset_admin_role_arn"></a> [stackset\_admin\_role\_arn](#input\_stackset\_admin\_role\_arn) | (Optional) stackset admin role to run SELF\_MANAGED stackset | `string` | `""` | no |
| <a name="input_stackset_execution_role_name"></a> [stackset\_execution\_role\_name](#input\_stackset\_execution\_role\_name) | (Optional) stackset execution role name to run SELF\_MANAGED stackset | `string` | `""` | no |
| <a name="auto_create_stackset_roles"></a> [auto\_create\_stackset\_roles](#input\_auto\_create\_stackset\_roles) | Whether to auto create the custom stackset roles to run SELF_MANAGED stackset | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | (Optional) Tags to be attached to all Sysdig resources. | `map(string)` | <pre>{<br>  "product": "sysdig-secure-for-cloud"<br>}</pre> | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Default timeout values for create, update, and delete operations | `string` | `"30m"` | no |
| <a name="delegated_admin"></a> [delegated_admin](#input\_delegated\_admin) | Whether to create the resources using an delegated admin account | `bool` | `false` | no |
| <a name="input_sysdig_secure_account_id"></a> [sysdig\_secure\_account\_id](#input\_sysdig\_secure\_account\_id) | ID of the Sysdig Cloud Account to enable Event Bridge integration for (incase of organization, ID of the Sysdig management account) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_event_bridge_component_id"></a> [event\_bridge\_component\_id](#output\_event\_bridge\_component\_id) | Component identifier of Event Bridge integration created in Sysdig Backend for Log Ingestion |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Authors

Module is maintained by [Sysdig](https://sysdig.com).

## License

Apache 2 Licensed. See LICENSE for full details.
