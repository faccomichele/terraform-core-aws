# CloudFormation Templates for Terraform State Management

This directory contains CloudFormation templates converted from the original Terraform configuration. These templates create the foundational infrastructure for managing Terraform state files in AWS.

## Overview

The templates create:
- **S3 Bucket**: Encrypted bucket with versioning for storing Terraform state files
- **IAM Role**: Role for accessing the state bucket with appropriate permissions
- **SSM Parameter**: Stores the backend configuration for easy reference

## Template Options

### 1. All-in-One Template (Recommended for Simple Deployments)

**File**: `terraform-core-allinone.yaml`

Single template containing all resources. Easiest to deploy and manage.

**Deployment**:
```bash
aws cloudformation create-stack \
  --stack-name terraform-core-dev \
  --template-body file://terraform-core-allinone.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=terraform-core-aws \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=Environment,ParameterValue=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### 2. Nested Stack Template (Recommended for Complex Deployments)

**Main File**: `terraform-core-main.yaml`
**Nested Templates**: `nested/*.yaml`

Uses nested stacks for better organization and modularity. Requires uploading nested templates to S3 first.

**Prerequisites**:
1. Create an S3 bucket to host the templates
2. Upload nested templates to the bucket
3. Ensure the templates are accessible via HTTP URLs

**Steps**:

#### Step 1: Upload Nested Templates to S3

```bash
# Create a bucket for CloudFormation templates (if not exists)
aws s3 mb s3://your-cfn-templates-bucket

# Upload nested templates
aws s3 cp nested/s3-state-bucket.yaml s3://your-cfn-templates-bucket/cloudformation/nested/
aws s3 cp nested/iam-state-role.yaml s3://your-cfn-templates-bucket/cloudformation/nested/
aws s3 cp nested/ssm-backend-config.yaml s3://your-cfn-templates-bucket/cloudformation/nested/

# Make them publicly readable (or use appropriate bucket policy)
aws s3api put-object-acl --bucket your-cfn-templates-bucket --key cloudformation/nested/s3-state-bucket.yaml --acl public-read
aws s3api put-object-acl --bucket your-cfn-templates-bucket --key cloudformation/nested/iam-state-role.yaml --acl public-read
aws s3api put-object-acl --bucket your-cfn-templates-bucket --key cloudformation/nested/ssm-backend-config.yaml --acl public-read
```

#### Step 2: Deploy Main Stack

```bash
aws cloudformation create-stack \
  --stack-name terraform-core-dev \
  --template-body file://terraform-core-main.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=terraform-core-aws \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=Environment,ParameterValue=dev \
    ParameterKey=TemplateBaseURL,ParameterValue=http://your-cfn-templates-bucket.s3.amazonaws.com/cloudformation/nested \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## Parameters

All templates accept the following parameters:

| Parameter | Type | Description | Default | Required |
|-----------|------|-------------|---------|----------|
| `ProjectName` | String | Name of the project | `terraform-core-aws` | Yes |
| `Organization` | String | Name of the organization | `faccomichele` | Yes |
| `Environment` | String | Environment/Workspace (dev, stg, prod) | `dev` | Yes |
| `TemplateBaseURL` | String | HTTP URL base for nested templates | - | Only for nested stack |

## Deployment Examples

### Using AWS CLI

#### Create Stack
```bash
aws cloudformation create-stack \
  --stack-name terraform-core-prod \
  --template-body file://terraform-core-allinone.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=terraform-core-aws \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=Environment,ParameterValue=prod \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags Key=ManagedBy,Value=CloudFormation
```

#### Update Stack
```bash
aws cloudformation update-stack \
  --stack-name terraform-core-prod \
  --template-body file://terraform-core-allinone.yaml \
  --parameters \
    ParameterKey=ProjectName,UsePreviousValue=true \
    ParameterKey=Organization,UsePreviousValue=true \
    ParameterKey=Environment,UsePreviousValue=true \
  --capabilities CAPABILITY_NAMED_IAM
```

#### Delete Stack
```bash
aws cloudformation delete-stack \
  --stack-name terraform-core-prod
```

### Using AWS Console

1. Navigate to CloudFormation in AWS Console
2. Click "Create stack" → "With new resources (standard)"
3. Choose "Upload a template file"
4. Select `terraform-core-allinone.yaml` (or `terraform-core-main.yaml`)
5. For nested stacks, ensure you've uploaded nested templates to S3 first
6. Fill in the parameters:
   - **Stack name**: e.g., `terraform-core-dev`
   - **ProjectName**: e.g., `terraform-core-aws`
   - **Organization**: e.g., `faccomichele`
   - **Environment**: Select from `dev`, `stg`, or `prod`
   - **TemplateBaseURL** (nested only): HTTP URL to your S3-hosted templates
7. Review and create the stack

## Outputs

After deployment, the stack provides the following outputs:

| Output | Description |
|--------|-------------|
| `StateBucketName` | Name of the S3 bucket for Terraform state files |
| `StateBucketArn` | ARN of the S3 bucket |
| `StateRoleArn` | ARN of the IAM role for state access |
| `StateRoleName` | Name of the IAM role |
| `BackendConfigurationParameterName` | SSM parameter name with backend config |
| `BackendConfigurationHCL` | Backend configuration in HCL format |

### Retrieving Outputs

```bash
# Get all outputs
aws cloudformation describe-stacks \
  --stack-name terraform-core-dev \
  --query 'Stacks[0].Outputs'

# Get specific output
aws cloudformation describe-stacks \
  --stack-name terraform-core-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`StateBucketName`].OutputValue' \
  --output text
```

## Using the Backend Configuration

After deployment, retrieve the backend configuration from SSM:

```bash
# Retrieve the backend configuration
aws ssm get-parameter \
  --name /terraform-core/backend_configuration_hcl \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```

Copy the output into your Terraform project's backend configuration file.

## Template Validation

Before deploying, validate the templates:

```bash
# Validate all-in-one template
aws cloudformation validate-template \
  --template-body file://terraform-core-allinone.yaml

# Validate main template
aws cloudformation validate-template \
  --template-body file://terraform-core-main.yaml

# Validate nested templates
aws cloudformation validate-template \
  --template-body file://nested/s3-state-bucket.yaml

aws cloudformation validate-template \
  --template-body file://nested/iam-state-role.yaml

aws cloudformation validate-template \
  --template-body file://nested/ssm-backend-config.yaml
```

## Multiple Environments

Deploy separate stacks for different environments:

```bash
# Development
aws cloudformation create-stack \
  --stack-name terraform-core-dev \
  --template-body file://terraform-core-allinone.yaml \
  --parameters \
    ParameterKey=Environment,ParameterValue=dev \
  --capabilities CAPABILITY_NAMED_IAM

# Staging
aws cloudformation create-stack \
  --stack-name terraform-core-stg \
  --template-body file://terraform-core-allinone.yaml \
  --parameters \
    ParameterKey=Environment,ParameterValue=stg \
  --capabilities CAPABILITY_NAMED_IAM

# Production
aws cloudformation create-stack \
  --stack-name terraform-core-prod \
  --template-body file://terraform-core-allinone.yaml \
  --parameters \
    ParameterKey=Environment,ParameterValue=prod \
  --capabilities CAPABILITY_NAMED_IAM
```

## Security Considerations

1. **IAM Permissions**: The deployment requires `CAPABILITY_NAMED_IAM` because it creates IAM roles
2. **Encryption**: All state files are encrypted at rest with AES256
3. **Public Access**: S3 bucket blocks all public access
4. **Assume Role**: IAM role can only be assumed by the same AWS account
5. **SSM Parameter**: Backend configuration is stored as a SecureString

## Troubleshooting

### Stack Creation Fails

1. Check CloudFormation events:
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name terraform-core-dev \
     --max-items 20
   ```

2. Common issues:
   - Missing IAM permissions
   - Bucket name conflicts (includes account ID to avoid this)
   - Invalid parameter values

### Nested Stack Template Not Found

1. Verify templates are uploaded to S3:
   ```bash
   aws s3 ls s3://your-cfn-templates-bucket/cloudformation/nested/
   ```

2. Verify HTTP URL is correct and accessible:
   ```bash
   curl -I http://your-cfn-templates-bucket.s3.amazonaws.com/cloudformation/nested/s3-state-bucket.yaml
   ```

3. Check bucket policy allows CloudFormation to read templates

## Cost Optimization

The templates include lifecycle rules to automatically expire old state file versions after 30 days, reducing storage costs.

## Comparison with Terraform

| Feature | Terraform | CloudFormation |
|---------|-----------|----------------|
| Syntax | HCL | YAML/JSON |
| State Management | Required | Managed by AWS |
| Modularity | Modules | Nested Stacks |
| Variable Resolution | Native | Parameters |
| Workspace Support | Built-in | Stack per environment |
| Resource Naming | Name prefix | Fixed names with parameters |

## Next Steps

After deploying the CloudFormation stack:

1. Retrieve the backend configuration from SSM or CloudFormation outputs
2. Configure your Terraform projects to use the created S3 bucket and IAM role
3. Update the `key` parameter in the backend configuration for each project
4. Test the configuration with `terraform init`

## Support

For issues or questions, please refer to the main repository README or open an issue on GitHub.
