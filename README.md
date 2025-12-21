# CloudFormation Templates for Terraform State Management

This directory contains CloudFormation templates converted from the original Terraform configuration. These templates create the foundational infrastructure for managing Terraform state files in AWS.

## 📚 Documentation

- **[USAGE-WITH-TERRAFORM.md](./USAGE-WITH-TERRAFORM.md)** - Detailed Terraform to CloudFormation conversion reference
- **[GITHUB-ROLE-TEMPLATE-USAGE.md](./GITHUB-ROLE-TEMPLATE-USAGE.md)** - Complete guide for using the GitHub Actions IAM role template
- **README.md** (this file) - Comprehensive guide

## Overview

The repository contains two CloudFormation templates:

### 1. Core Infrastructure (`terraform-core-allinone.yaml`)
Creates the foundational Terraform state management resources:
- **S3 Bucket**: Encrypted bucket with versioning for storing Terraform state files
- **IAM Role**: Role for accessing the state bucket with appropriate permissions
- **SSM Parameter**: Stores the backend configuration for easy reference

### 2. GitHub Actions Integration (`github-identity-provider.yaml`)
Creates resources for GitHub Actions OIDC authentication:
- **IAM OIDC Provider**: GitHub Actions identity provider for secure, keyless authentication
- Can be deployed independently to avoid duplication across multiple stacks

## ⚠️ Important: Stack Naming Convention

**Recommended Stack Name**: `terraform-core-aws`

While CloudFormation doesn't allow defining a default stack name within the template, it's **strongly recommended** to use `terraform-core-aws` as your stack name when deploying this template. This naming convention:

- Provides consistency across deployments
- Makes it easier to reference outputs from other stacks using `!ImportValue` or stack exports
- Simplifies automation and scripting
- Aligns with the project name

**Example for different environments:**
- Development: `terraform-core-aws-dev`
- Staging: `terraform-core-aws-stg`
- Production: `terraform-core-aws`

This consistent naming allows other CloudFormation stacks to reliably import values like:
```yaml
!ImportValue terraform-core-aws-StateRoleArn
!ImportValue github-oidc-provider-GitHubOIDCProviderArn
```

## Important Usage Notes

- **Console upload supported**: This CloudFormation template does not require the AWS CLI. You can upload the `terraform-core-allinone.yaml` file directly from the CloudFormation page in the AWS Console. This is convenient for brand new AWS accounts because it avoids creating additional IAM users, roles, or CLI configuration before deploying the stack.

- **Terraform uses the created IAM role**: Terraform projects that use this backend should assume the IAM role created by this stack (the role ARN is exported as `StateRoleArn`). The role provides the permissions required to read, write and manage state files in the S3 bucket.

- **SSM read access is a standalone managed policy**: A standalone managed policy named `${ProjectName}-ssm-read-${Environment}` (resource `SSMParameterReadPolicy`) grants `ssm:GetParameter` / `ssm:GetParameters` only for the backend parameter `/${ProjectName}/${Environment}/backend_configuration_hcl` (for example, `/terraform-core-aws/dev/backend_configuration_hcl`). Peer repositories (the Terraform-based repos that deploy your applications or infrastructure) must attach this managed policy to the IAM role they use for deployments (or otherwise grant the equivalent SSM read permissions) so they can always retrieve the current backend configuration from SSM.

## Template Options

### 1. Core Infrastructure Template (Recommended)

**File**: `terraform-core-allinone.yaml`

Contains the core Terraform state management resources: S3 bucket, IAM role, and SSM parameter.

**Deployment**:
```bash
aws cloudformation create-stack \
  --stack-name terraform-core-aws \
  --template-body file://terraform-core-allinone.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=terraform-core-aws \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=Environment,ParameterValue=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

> **Note**: Using `terraform-core-aws` as the stack name is recommended for consistency and to enable easy cross-stack references.

### 2. GitHub Actions OIDC Provider (Optional, Separate Stack)

**File**: `github-identity-provider.yaml`

Creates the GitHub Actions OIDC identity provider. Deploy this as a **separate stack** to:
- Share the OIDC provider across multiple projects/stacks
- Avoid creating duplicate OIDC providers (AWS accounts have a limit)
- Manage GitHub Actions authentication independently from state management

**Recommended Stack Name**: `github-oidc-provider`

**Deployment**:
```bash
aws cloudformation create-stack \
  --stack-name github-oidc-provider \
  --template-body file://github-identity-provider.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=terraform-core-aws \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=Environment,ParameterValue=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

Once deployed, other stacks can reference the OIDC provider:
```yaml
# In another CloudFormation template
GitHubActionsRole:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Statement:
        - Effect: Allow
          Principal:
            Federated: !ImportValue github-oidc-provider-GitHubOIDCProviderArn
          Action: sts:AssumeRoleWithWebIdentity
          Condition:
            StringLike:
              token.actions.githubusercontent.com:sub: 'repo:your-org/*:*'
```

### 3. GitHub Actions Role Template (Reusable)

**File**: `github-iam-role-template.yaml`

A reusable template for creating repository-specific GitHub Actions IAM roles. This template:
- References the shared OIDC provider deployed in step 2
- **Always includes** the SSM parameter read policy for Terraform backend configuration access
- Can be copied to other repositories and customized with additional permissions
- Uses auto-generated role names for uniqueness

**Usage**:
1. Copy `github-iam-role-template.yaml` to your target repository
2. Update the `RepositoryName` parameter default to match your repository
3. Add any application-specific managed policies or inline policies
4. Deploy the stack

**Deployment Example**:
```bash
aws cloudformation create-stack \
  --stack-name my-app-github-role \
  --template-body file://github-iam-role-template.yaml \
  --parameters \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=RepositoryName,ParameterValue=my-app-repository \
    ParameterKey=Environment,ParameterValue=dev \
    ParameterKey=SSMParameterReadPolicyName,ParameterValue=terraform-core-aws-ssm-read-dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

The role will automatically:
- Allow the specified repository to assume it via OIDC
- Include read access to Terraform backend configuration in SSM
- Use an auto-generated role name based on the stack name

### 4. Nested Stack Template (Advanced Use Case)

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
   - **Stack name**: **`terraform-core-aws`** (recommended for consistency)
   - **ProjectName**: e.g., `terraform-core-aws`
   - **Organization**: e.g., `faccomichele`
   - **Environment**: Select from `dev`, `stg`, or `prod`
   - **TemplateBaseURL** (nested only): HTTP URL to your S3-hosted templates
7. Review and create the stack

## Outputs

After deployment, the stacks provide the following outputs:

### Core Infrastructure Stack (`terraform-core-aws`)

| Output | Description |
|--------|-------------|
| `StateBucketName` | Name of the S3 bucket for Terraform state files |
| `StateBucketArn` | ARN of the S3 bucket |
| `StateRoleArn` | ARN of the IAM role for state access |
| `StateRoleName` | Name of the IAM role |
| `BackendConfigurationParameterName` | SSM parameter name with backend config |
| `BackendConfigurationHCL` | Backend configuration in HCL format |

Note: `StateRoleName` may be auto-generated by CloudFormation if no explicit `RoleName` is specified in the template. The intrinsic `Ref` on the role resource will return the generated role name and can be used to reference the role from other stacks or tooling.

### GitHub OIDC Provider Stack (`github-oidc-provider`)

| Output | Description |
|--------|-------------|
| `GitHubOIDCProviderArn` | ARN of the GitHub Actions OIDC provider (use to create roles in other stacks) |

### Retrieving Outputs

```bash
# Get all outputs from core infrastructure
aws cloudformation describe-stacks \
  --stack-name terraform-core-aws \
  --query 'Stacks[0].Outputs'

# Get OIDC provider ARN from GitHub stack
aws cloudformation describe-stacks \
  --stack-name github-oidc-provider \
  --query 'Stacks[0].Outputs[?OutputKey==`GitHubOIDCProviderArn`].OutputValue' \
  --output text

# Get state bucket name
aws cloudformation describe-stacks \
  --stack-name terraform-core-aws \
  --query 'Stacks[0].Outputs[?OutputKey==`StateBucketName`].OutputValue' \
  --output text
```

## Using the Backend Configuration

After deployment, retrieve the backend configuration from SSM:

```bash
# Retrieve the backend configuration
# Replace {ProjectName} and {Environment} with your stack's parameter values
# For example: /terraform-core-aws/dev/backend_configuration_hcl
aws ssm get-parameter \
  --name /{ProjectName}/{Environment}/backend_configuration_hcl \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```

Copy the output into your Terraform project's backend configuration file.

## Using GitHub Actions OIDC

If you deployed the `github-identity-provider.yaml` stack, you can create IAM roles for your repositories that use the OIDC provider for secure authentication.

### Quick Start: Use the Template

The easiest way is to use the provided `github-iam-role-template.yaml`:

1. Copy the template to your repository
2. Update the `RepositoryName` parameter
3. Add any additional policies your application needs
4. Deploy the stack

The template automatically includes the SSM parameter read policy and properly references the OIDC provider.

See **Template Options → Section 3** above for deployment instructions.

### Manual Role Creation (Advanced)

If you prefer to create roles manually or integrate into existing templates, reference the OIDC provider ARN from the `github-oidc-provider` stack:

```yaml
# In your application's CloudFormation template
Resources:
  MyAppGitHubActionsRole:
    Type: AWS::IAM::Role
    Properties:
      # Let CloudFormation auto-generate the role name
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: !Sub 'arn:aws:iam::${AWS::AccountId}:oidc-provider/token.actions.githubusercontent.com'
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringLike:
                token.actions.githubusercontent.com:sub: 'repo:your-org/your-repo:*'
              StringEquals:
                token.actions.githubusercontent.com:aud: sts.amazonaws.com
      ManagedPolicyArns:
        # REQUIRED: SSM parameter read policy for Terraform backend config
        # Replace {ProjectName} with the ProjectName parameter from your terraform-core-allinone.yaml stack
        - !Sub 'arn:aws:iam::${AWS::AccountId}:policy/{ProjectName}-ssm-read-${Environment}'
        # Add your application-specific policies here
        - arn:aws:iam::aws:policy/ReadOnlyAccess  # Example

Outputs:
  GitHubActionsRoleArn:
    Value: !GetAtt MyAppGitHubActionsRole.Arn
```

### Using in GitHub Actions Workflows

```yaml
# .github/workflows/deploy.yml
name: Deploy
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::YOUR_ACCOUNT_ID:role/my-app-github-actions
          aws-region: us-east-1
      
      - name: Run Terraform
        run: |
          terraform init
          terraform plan
```

### Getting the OIDC Provider ARN

```bash
# Retrieve the OIDC provider ARN
aws cloudformation describe-stacks \
  --stack-name github-oidc-provider \
  --query 'Stacks[0].Outputs[?OutputKey==`GitHubOIDCProviderArn`].OutputValue' \
  --output text
```

## Template Validation

Before deploying, validate the templates:

```bash
# Validate core infrastructure template
aws cloudformation validate-template \
  --template-body file://terraform-core-allinone.yaml

# Validate GitHub OIDC provider template
aws cloudformation validate-template \
  --template-body file://github-identity-provider.yaml
```

## Multiple Environments

Deploy separate stacks for different environments:

```bash
# Deploy core infrastructure for each environment
# Development
aws cloudformation create-stack \
  --stack-name terraform-core-aws-dev \
  --template-body file://terraform-core-allinone.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=terraform-core-aws \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=Environment,ParameterValue=dev \
  --capabilities CAPABILITY_NAMED_IAM

# Staging
aws cloudformation create-stack \
  --stack-name terraform-core-aws-stg \
  --template-body file://terraform-core-allinone.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=terraform-core-aws \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=Environment,ParameterValue=stg \
  --capabilities CAPABILITY_NAMED_IAM

# Production
aws cloudformation create-stack \
  --stack-name terraform-core-aws \
  --template-body file://terraform-core-allinone.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=terraform-core-aws \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=Environment,ParameterValue=prod \
  --capabilities CAPABILITY_NAMED_IAM

# Deploy GitHub OIDC provider once (shared across environments)
aws cloudformation create-stack \
  --stack-name github-oidc-provider \
  --template-body file://github-identity-provider.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=terraform-core-aws \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=Environment,ParameterValue=prod \
  --capabilities CAPABILITY_NAMED_IAM
```

> **Note**: Deploy the GitHub OIDC provider only once per account, as it's shared across all environments and projects.

## Security Considerations

1. **IAM Permissions**: The deployment requires `CAPABILITY_NAMED_IAM` because it creates IAM roles
2. **Encryption**: All state files are encrypted at rest with AES256
3. **Public Access**: S3 bucket blocks all public access
4. **Assume Role**: IAM role can only be assumed by the same AWS account
5. **SSM Parameter**: Backend configuration is stored as a String parameter
6. **GitHub OIDC**: 
   - Only repositories under your specified organization can assume roles
   - Uses short-lived credentials (no static access keys)
   - Condition policies restrict which repositories can assume roles
   - Keep thumbprints updated (check [GitHub's documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services))

## Troubleshooting

### Stack Creation Fails

1. Check CloudFormation events:
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name terraform-core-aws \
     --max-items 20
   ```

2. Common issues:
   - Missing IAM permissions (`CAPABILITY_NAMED_IAM` required)
   - Bucket name conflicts (includes account ID to avoid this)
   - Invalid parameter values
   - OIDC provider already exists (deploy `github-identity-provider.yaml` only once per account)

### OIDC Provider Already Exists Error

If you get an error that the OIDC provider already exists:
- The GitHub OIDC provider can only be created once per account
- Check if it already exists: `aws iam list-open-id-connect-providers`
- Either use the existing provider ARN or delete the old one (if safe to do so)
- This is why we recommend deploying `github-identity-provider.yaml` as a separate, shared stack

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

After deploying the CloudFormation stacks:

### For Terraform State Management
1. Retrieve the backend configuration from SSM or CloudFormation outputs
2. Configure your Terraform projects to use the created S3 bucket and IAM role
3. Update the `key` parameter in the backend configuration for each project
4. Test the configuration with `terraform init`

### For GitHub Actions Integration
1. Deploy the `github-identity-provider.yaml` stack (once per account)
2. Create IAM roles in your application stacks that reference the OIDC provider
3. Configure your GitHub Actions workflows to use `aws-actions/configure-aws-credentials@v4`
4. Grant appropriate permissions to each role based on your application needs

## Architecture Overview

```
┌─────────────────────────────────────┐
│  GitHub OIDC Provider Stack         │
│  (github-oidc-provider)             │
│  - Shared across all projects       │
└─────────────────┬───────────────────┘
                  │
                  │ Referenced by
                  │
    ┌─────────────┴─────────────┬─────────────────────┐
    │                           │                     │
┌───▼──────────────┐  ┌─────────▼────────┐  ┌───────▼────────┐
│ Core Infra Stack │  │ App Stack 1      │  │ App Stack 2    │
│ (terraform-core) │  │ - GitHub Role    │  │ - GitHub Role  │
│ - S3 Bucket      │  │ - App Resources  │  │ - App Resources│
│ - IAM Role       │  └──────────────────┘  └────────────────┘
│ - SSM Parameter  │
└──────────────────┘
```

## Support

For issues or questions, please refer to the main repository README or open an issue on GitHub.
