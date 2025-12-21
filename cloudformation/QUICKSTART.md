# Quick Start Guide - CloudFormation Deployment

This guide provides quick commands to deploy the Terraform state management infrastructure using CloudFormation.

## 🚀 Quick Deploy (All-in-One Template)

The simplest way to deploy using a single template:

```bash
# Navigate to cloudformation directory
cd cloudformation

# Deploy using the helper script (Linux/Mac)
./deploy.sh --stack-name terraform-core-dev --environment dev

# OR deploy using the helper script (Windows)
deploy.bat --stack-name terraform-core-dev --environment dev

# OR deploy directly with AWS CLI
aws cloudformation create-stack \
  --stack-name terraform-core-dev \
  --template-body file://terraform-core-allinone.yaml \
  --parameters file://parameters-dev.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## 🔗 Deploy with Nested Stacks

For better organization using nested stacks:

### Step 1: Upload nested templates to S3

```bash
# Create S3 bucket for templates (one-time setup)
aws s3 mb s3://my-cfn-templates-bucket --region us-east-1

# Upload nested templates
aws s3 cp nested/ s3://my-cfn-templates-bucket/cloudformation/nested/ --recursive

# Make templates publicly readable
aws s3api put-bucket-acl --bucket my-cfn-templates-bucket --acl public-read
```

### Step 2: Deploy the main stack

```bash
# Using the deployment script
./deploy.sh --template-type nested --s3-bucket my-cfn-templates-bucket --environment dev

# OR using AWS CLI with parameter file
# First, edit parameters-nested-example.json with your S3 bucket URL
aws cloudformation create-stack \
  --stack-name terraform-core-dev \
  --template-body file://terraform-core-main.yaml \
  --parameters file://parameters-nested-example.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## 📊 Monitor Deployment

```bash
# Watch stack creation progress
aws cloudformation wait stack-create-complete --stack-name terraform-core-dev

# View stack events
aws cloudformation describe-stack-events --stack-name terraform-core-dev

# Get stack outputs
aws cloudformation describe-stacks \
  --stack-name terraform-core-dev \
  --query 'Stacks[0].Outputs'
```

## 🔍 Retrieve Backend Configuration

After deployment, get the Terraform backend configuration:

```bash
# From SSM Parameter Store
aws ssm get-parameter \
  --name /terraform-core/backend_configuration_hcl \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text

# OR from CloudFormation outputs
aws cloudformation describe-stacks \
  --stack-name terraform-core-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`BackendConfigurationHCL`].OutputValue' \
  --output text
```

## 🔄 Update Stack

```bash
# Update with AWS CLI
aws cloudformation update-stack \
  --stack-name terraform-core-dev \
  --template-body file://terraform-core-allinone.yaml \
  --parameters file://parameters-dev.json \
  --capabilities CAPABILITY_NAMED_IAM
```

## 🗑️ Delete Stack

```bash
# Delete the stack (will NOT delete S3 bucket if it contains objects)
aws cloudformation delete-stack --stack-name terraform-core-dev

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete --stack-name terraform-core-dev
```

## 📝 Deploy Multiple Environments

```bash
# Development
./deploy.sh --stack-name terraform-core-dev --environment dev

# Staging
./deploy.sh --stack-name terraform-core-stg --environment stg

# Production
./deploy.sh --stack-name terraform-core-prod --environment prod
```

## 🛠️ Customize Parameters

Edit the parameter files to customize your deployment:

- `parameters-dev.json` - Development environment
- `parameters-stg.json` - Staging environment
- `parameters-prod.json` - Production environment

Example customization:
```json
[
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "my-custom-project"
  },
  {
    "ParameterKey": "Organization",
    "ParameterValue": "my-org"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "dev"
  }
]
```

## 🔐 IAM Permissions Required

To deploy these stacks, you need the following AWS permissions:

- `cloudformation:*` - Create/update/delete stacks
- `s3:*` - Create and manage S3 buckets
- `iam:*` - Create roles and policies
- `ssm:*` - Create SSM parameters

Or use the AWS managed policy: `AdministratorAccess` or `PowerUserAccess`

## ❓ Troubleshooting

### Stack creation fails with "Bucket name already exists"
The bucket name includes the account ID to avoid conflicts. Check if a bucket with that name already exists in your account.

### Nested stack templates not found
Ensure the templates are uploaded to S3 and accessible via HTTP URLs. Check the `TemplateBaseURL` parameter.

### Permission denied errors
Verify you have the required IAM permissions listed above.

## 📚 More Information

For detailed documentation, see [README.md](./README.md)
