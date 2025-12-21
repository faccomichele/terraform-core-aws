# Terraform to CloudFormation Conversion Reference

This document provides a detailed mapping between the original Terraform configuration and the converted CloudFormation templates.

## Resource Mapping

### S3 Bucket Resources

| Terraform Resource | CloudFormation Resource | Template File |
|-------------------|------------------------|---------------|
| `aws_s3_bucket.terraform_state` | `AWS::S3::Bucket` (TerraformStateBucket) | s3-state-bucket.yaml / allinone |
| `aws_s3_bucket_versioning.terraform_state_versioning` | Integrated into `VersioningConfiguration` property | s3-state-bucket.yaml / allinone |
| `aws_s3_bucket_server_side_encryption_configuration.terraform_state_encryption` | Integrated into `BucketEncryption` property | s3-state-bucket.yaml / allinone |
| `aws_s3_bucket_public_access_block.terraform_state_pab` | Integrated into `PublicAccessBlockConfiguration` property | s3-state-bucket.yaml / allinone |
| `aws_s3_bucket_lifecycle_configuration.terraform_state_lifecycle` | Integrated into `LifecycleConfiguration` property | s3-state-bucket.yaml / allinone |

### IAM Resources

| Terraform Resource | CloudFormation Resource | Template File |
|-------------------|------------------------|---------------|
| `aws_iam_role.terraform_state_role` | `AWS::IAM::Role` (TerraformStateRole) | iam-state-role.yaml / allinone |
| `aws_iam_role_policy.terraform_state_policy` | `AWS::IAM::Policy` (TerraformStatePolicy) | iam-state-role.yaml / allinone |

### SSM Resources

| Terraform Resource | CloudFormation Resource | Template File |
|-------------------|------------------------|---------------|
| `aws_ssm_parameter.backend_configuration_hcl` | `AWS::SSM::Parameter` (BackendConfigurationParameter) | ssm-backend-config.yaml / allinone |

### Data Sources

| Terraform Data Source | CloudFormation Equivalent | How It's Handled |
|----------------------|--------------------------|------------------|
| `data.aws_caller_identity.current` | Pseudo parameter `AWS::AccountId` | Direct reference in templates |
| `data.aws_region.current` | Pseudo parameter `AWS::Region` | Direct reference in templates |

### Variables

| Terraform Variable | CloudFormation Parameter | Default Value |
|-------------------|------------------------|---------------|
| `var.project_name` | `ProjectName` | terraform-core-aws |
| `var.organization` | `Organization` | faccomichele |
| `terraform.workspace` | `Environment` | dev |
| N/A | `TemplateBaseURL` | (Required for nested stacks only) |

### Locals

| Terraform Local | CloudFormation Equivalent | How It's Handled |
|----------------|--------------------------|------------------|
| `local.repository_url` | Computed via `!Sub` | `https://github.com/${Organization}/${ProjectName}` |
| `local.tags` | Applied directly to resources | Merged with resource-specific tags |
| `local.allowed_workspaces` | Parameter constraints | `AllowedValues: [dev, stg, prod]` |
| `local.workspace_valid` | Parameter validation | Built-in CloudFormation validation |

### Outputs

| Terraform Output | CloudFormation Output | Value Source |
|-----------------|----------------------|--------------|
| `backend_configuration_hcl_parameter_name` | `BackendConfigurationParameterName` | SSM Parameter name |
| `backend_configuration_hcl` | `BackendConfigurationHCL` | SSM Parameter value |
| N/A | `StateBucketName` | S3 bucket name |
| N/A | `StateBucketArn` | S3 bucket ARN |
| N/A | `StateRoleArn` | IAM role ARN |
| N/A | `StateRoleName` | IAM role name |

## Key Differences

### 1. Resource Naming

**Terraform:**
- Uses `name_prefix` for dynamic naming
- Generates unique suffixes automatically

**CloudFormation:**
- Uses `!Sub` function to interpolate parameters
- Bucket name: `${ProjectName}-state-files-${Environment}-${AWS::AccountId}`
- IAM role: `${ProjectName}-state-files-${Environment}`

### 2. Configuration Structure

**Terraform:**
- Separate resources for each S3 bucket configuration aspect
- Example: `aws_s3_bucket_versioning`, `aws_s3_bucket_encryption`, etc.

**CloudFormation:**
- Integrated properties within the main S3 bucket resource
- All configuration in one `AWS::S3::Bucket` resource

### 3. Workspaces vs. Environments

**Terraform:**
- Uses `terraform.workspace` for environment management
- Workspace names directly influence resource naming
- Must run `terraform workspace select` before deployment

**CloudFormation:**
- Uses `Environment` parameter
- Parameter validation ensures only valid values (dev, stg, prod)
- Separate stacks for each environment

### 4. State Management

**Terraform:**
- Needs state file for itself (bootstrap problem)
- Can use local state initially, then migrate to remote

**CloudFormation:**
- State managed by AWS automatically
- No bootstrap problem
- Stack state stored in AWS CloudFormation service

### 5. Module/Template Organization

**Terraform:**
- Single-file or multi-file configuration
- All resources in root directory

**CloudFormation:**
- Two options:
  - **All-in-one**: Single template with all resources
  - **Nested stacks**: Separate templates for S3, IAM, SSM with main orchestrator

### 6. String Interpolation

**Terraform:**
```hcl
bucket_prefix = "${var.project_name}-state-files-${terraform.workspace}-${data.aws_caller_identity.current.account_id}-"
```

**CloudFormation:**
```yaml
BucketName: !Sub '${ProjectName}-state-files-${Environment}-${AWS::AccountId}'
```

### 7. Policy Documents

**Terraform:**
```hcl
assume_role_policy = <<ASSUME_POLICY
{
  "Version": "2012-10-17",
  ...
}
ASSUME_POLICY
```

**CloudFormation:**
```yaml
AssumeRolePolicyDocument:
  Version: '2012-10-17'
  Statement:
    - Effect: Allow
      ...
```

### 8. Tags

**Terraform:**
- Uses `merge()` function to combine tag maps
- Separate `tags` block or argument

**CloudFormation:**
- Tags as list of key-value pairs
- Direct specification in `Tags` property

## Feature Comparison

| Feature | Terraform | CloudFormation |
|---------|-----------|----------------|
| **Syntax** | HCL | YAML/JSON |
| **Provider** | hashicorp/aws | Native AWS |
| **State Storage** | S3/Remote backend | AWS managed |
| **Versioning** | Module versions | Template versioning |
| **Validation** | `terraform validate` | `cfn-lint`, `aws cloudformation validate-template` |
| **Deployment** | `terraform apply` | `aws cloudformation create-stack` |
| **Updates** | `terraform apply` | `aws cloudformation update-stack` |
| **Rollback** | Manual | Automatic on failure |
| **Change Preview** | `terraform plan` | `aws cloudformation create-change-set` |
| **Drift Detection** | `terraform refresh` | Built-in drift detection |
| **Cost** | Free (OSS) | Free |
| **Learning Curve** | Medium | Medium-High |
| **AWS Integration** | Via provider | Native |

## Conversion Process

The conversion followed these steps:

1. **Analyzed Terraform resources** - Identified all resources, data sources, variables, and outputs
2. **Mapped to CloudFormation types** - Found equivalent AWS::* resource types
3. **Consolidated sub-resources** - Combined separate Terraform resources into single CloudFormation resources where applicable
4. **Created parameters** - Converted Terraform variables to CloudFormation parameters
5. **Handled data sources** - Replaced data sources with pseudo parameters
6. **Maintained functionality** - Ensured all features (encryption, versioning, lifecycle rules) were preserved
7. **Added enhancements** - Created both all-in-one and nested stack options
8. **Validated templates** - Used cfn-lint to validate syntax
9. **Created deployment tools** - Built scripts and documentation for easy deployment

## Benefits of CloudFormation Version

1. **No External Dependencies**: No need to install Terraform CLI
2. **Native AWS Integration**: Direct integration with AWS services
3. **Automatic State Management**: AWS handles state automatically
4. **Built-in Drift Detection**: CloudFormation can detect configuration drift
5. **StackSets Support**: Can deploy to multiple regions/accounts easily
6. **AWS Console Support**: Deploy and manage via AWS Console UI
7. **Automatic Rollback**: CloudFormation rolls back on failure automatically
8. **Change Sets**: Preview changes before applying them

## When to Use Which?

### Use Terraform When:
- Managing multi-cloud infrastructure
- Team already experienced with Terraform
- Need advanced state management features
- Want to use Terraform modules ecosystem
- Need complex conditional logic

### Use CloudFormation When:
- AWS-only infrastructure
- Team already experienced with CloudFormation
- Want native AWS integration
- Need StackSets for multi-region/account deployment
- Prefer AWS-managed state
- Want automatic rollback capabilities

## Migration Path

If you have existing Terraform-managed infrastructure and want to migrate to CloudFormation:

1. **Document current state**: Run `terraform show` to see current resources
2. **Export resource IDs**: Note S3 bucket names, IAM role ARNs, etc.
3. **Import to CloudFormation**: Use CloudFormation import feature
4. **Validate**: Ensure CloudFormation stack matches existing resources
5. **Remove Terraform state**: Clean up Terraform state files
6. **Update processes**: Switch deployment processes to use CloudFormation

**Note**: Importing existing resources is an advanced operation. Consider creating new resources in a different environment for testing first.

## Additional Resources

- [AWS CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
- [CloudFormation Template Reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)
- [cfn-lint Documentation](https://github.com/aws-cloudformation/cfn-lint)
- [Terraform to CloudFormation Comparison](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/infrastructure-as-code.html)
