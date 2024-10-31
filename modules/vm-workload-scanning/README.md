# AWS VM Workload Scanning Module

This Module creates the resources required to perform agentless workload scanning operations.
By default, it will create a role with permissions necessary to access and pull ECR images in the account where it is deployed. 
Combined with the base onboarding, this allows for scanning ECS Services and Tasks pointing to ECR images.
Also public docker images and private repos are supported, as long as private repository permissions are granted to Sysdig using the Registry Credentials UI.

Optionally, if EKS scanning is enabled, the base onboarding module will have visibility on a set of EKS clusters in the account and be able to scan its resources.
Optional, if AWS Lambda is enabled, we will have visibility on a set of Lambda functions in the account and be able to scan its resources.

The following resources will be created in each instrumented account:
- An IAM Role and associated policies that allows Sysdig to perform tasks necessary for vm agentless workload scanning, i.e.
pull images from ECR, optionally obtain lambda function code and details, optionally allow base onboarding to have visibility on a set of EKS clusters.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name                                                                      | Version   |
|---------------------------------------------------------------------------|-----------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.7    |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 5.60.0 |
| <a name="requirement_sysdig"></a> [sysdig](#requirement\_sysdig)          | ~> 1.37   |

## Providers

| Name                                                       | Version  |
|------------------------------------------------------------|----------|
| <a name="provider_aws"></a> [aws](#provider\_aws)          | >= 5.60.0 |
| <a name="provider_sysdig"></a> [sysdig](#provider\_sysdig) | ~> 1.37  |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_access_entry.viewer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.viewer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [sysdig_secure_tenant_external_id.external_id](https://registry.terraform.io/providers/sysdig/sysdig/latest/docs/data-sources/tenant_external_id) | data source |
| [aws_iam_policy.ecr_scanning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.scanning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_policy_attachment.scanning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [sysdig_secure_cloud_auth_account_component.vm_workload_scanning_account_component](https://registry.terraform.io/providers/sysdig/sysdig/latest/docs/resources/cloud_auth_account_component) | resource |
| [aws_cloudformation_stack_set.scanning_role_stackset](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set) | resource |
| [aws_cloudformation_stack_set_instance.scanning_role_stackset_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance) | resource |
| [aws_organizations_organization.org](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |


## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cspm_role_arn"></a> [cspm_role_arn](#input_cspm_role_arn) | The Full ARN of the Sysdig CSPM role which will be used to access Kubernetes clusters | `string` | n/a | yes |
| <a name="input_trusted_identity"></a> [trusted_identity](#input_trusted_identity) | This value should be provided by Sysdig. The field refers to Sysdig's IAM role that will be authorized to pull ECR images | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input_tags) | sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning | `map(string)` | <pre>{<br>"product": "sysdig-secure-for-cloud"<br>}</pre> | no |
| <a name="input_is_organizational"></a> [is_organizational](#input_is_organizational) | Set this field to 'true' to deploy Agentless Workload Scanning to an AWS Organization (Or specific OUs) | `bool` | `false` | no |
| <a name="input_org_units"></a> [org_units](#input_org_units) | List of Organization Unit IDs in which to setup Agentless Workload Scanning. By default, Agentless Workload Scanning will be setup in all accounts within the Organization. This field is ignored if `is_organizational = false` | `set(string)` | `[]` | no |
| <a name="input_timeout"></a> [timeout](#input_timeout) | Default timeout values for create, update, and delete operations | `string` | `"30m"` | no |
| <a name="input_failure_tolerance_percentage"></a> [failure_tolerance_percentage](#input_failure_tolerance_percentage) | The percentage of accounts, per Region, for which stack operations can fail before AWS CloudFormation stops the operation in that Region | `number` | `90` | no |
| <a name="input_eks_scanning_enabled"></a> [eks_scanning_enabled](#input_eks_scanning_enabled) | Set this field to 'true' to deploy Agentless Workload Scanning for EKS clusters | `bool` | `false` | no |
| <a name="input_eks_clusters"></a> [eks_clusters](#input_eks_clusters) | List the clusters that Sysdig will scan. Please note that only clusters with authentication mode set to API or API_AND_CONFIG_MAP will be onboarded. | `set(string)` | `[]` | no |
| <a name="input_lambda_scanning_enabled"></a> [lambda_scanning_enabled](#input_lambda_scanning_enabled) | Set this field to 'true' to deploy Agentless Workload Scanning for Lambda functions | `bool` | `false` | no |
| <a name="input_sysdig_secure_account_id"></a> [sysdig_secure_account_id](#input_sysdig_secure_account_id) | ID of the Sysdig Cloud Account to enable Config Posture for (in case of organization, ID of the Sysdig management account) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_arn"></a> [role_arn](#output_role_arn) | Role used by Sysdig Platform for Agentless Workload Scanning |
| <a name="output_vm_workload_scanning_component_id"></a> [vm_workload_scanning_component_id](#output_vm_workload_scanning_component_id) | Component identifier of trusted identity created in Sysdig Backend for VM Workload Scanning |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Authors

Module is maintained by [Sysdig](https://sysdig.com).

## License

Apache 2 Licensed. See LICENSE for full details.
