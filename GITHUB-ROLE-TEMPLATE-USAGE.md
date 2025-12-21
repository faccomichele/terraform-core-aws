# GitHub Actions IAM Role Template - Usage Guide

This template (`github-iam-role-template.yaml`) creates a repository-specific IAM role for GitHub Actions workflows. It's designed to be copied to other repositories and customized as needed.

## Prerequisites

Before using this template, ensure you have deployed:

1. **Core Infrastructure** (`terraform-core-allinone.yaml`) - Creates the S3 bucket, IAM role, and SSM parameter for Terraform state
2. **GitHub OIDC Provider** (`github-identity-provider.yaml`) - Creates the shared OIDC provider for GitHub Actions

## Quick Start

### Step 1: Copy the Template

Copy `github-iam-role-template.yaml` to your target repository.

### Step 2: Update Parameters

Open the file and update the default values in the Parameters section:

```yaml
Parameters:
  Organization:
    Default: faccomichele  # Your GitHub organization
  
  RepositoryName:
    Default: my-app-repository  # ⚠️ CHANGE THIS to your repository name
  
  Environment:
    Default: dev  # Change if deploying to stg/prod
  
  SSMParameterReadPolicyName:
    Default: terraform-core-aws-ssm-read-dev  # Match your environment
```

### Step 3: Add Application-Specific Permissions (Optional)

Add any managed policies or inline policies your application needs:

```yaml
Resources:
  GitHubActionsRole:
    Type: AWS::IAM::Role
    Properties:
      ManagedPolicyArns:
        - !Sub 'arn:aws:iam::${AWS::AccountId}:policy/${SSMParameterReadPolicyName}'
        # ADD YOUR POLICIES HERE:
        - arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess  # Example
        - arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess  # Example
      Policies:
        - PolicyName: custom-permissions
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: '*'
```

### Step 4: Deploy the Stack

```bash
aws cloudformation create-stack \
  --stack-name my-app-github-role \
  --template-body file://github-iam-role-template.yaml \
  --parameters \
    ParameterKey=Organization,ParameterValue=faccomichele \
    ParameterKey=RepositoryName,ParameterValue=my-app-repository \
    ParameterKey=Environment,ParameterValue=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### Step 5: Get the Role ARN

After deployment, retrieve the role ARN:

```bash
aws cloudformation describe-stacks \
  --stack-name my-app-github-role \
  --query 'Stacks[0].Outputs[?OutputKey==`GitHubActionsRoleArn`].OutputValue' \
  --output text
```

### Step 6: Use in GitHub Actions Workflow

Create or update `.github/workflows/deploy.yml` in your repository:

```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # Required for OIDC
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/stack-name-GitHubActionsRole-ABC123  # Use the ARN from step 5
          aws-region: us-east-1
      
      - name: Verify AWS Identity
        run: |
          aws sts get-caller-identity
          
      - name: Get Terraform Backend Config
        run: |
          # Replace {ProjectName} and {Environment} with your stack's parameter values
          # For example: /terraform-core-aws/dev/backend_configuration_hcl
          aws ssm get-parameter \
            --name /{ProjectName}/{Environment}/backend_configuration_hcl \
            --query 'Parameter.Value' \
            --output text
```

## What This Template Provides

### Always Included

✅ **SSM Parameter Read Access** - The role always includes the managed policy to read Terraform backend configuration from SSM  
✅ **Repository-Specific Access** - Only your specified repository can assume this role  
✅ **Auto-Generated Role Name** - CloudFormation generates a unique role name to avoid conflicts  
✅ **Proper OIDC Configuration** - Correctly references the shared GitHub OIDC provider  

### You Need to Add

- Application-specific managed policies (S3, EC2, Lambda, etc.)
- Custom inline policies for fine-grained permissions
- Any other AWS resources your application needs

## Parameters Explained

| Parameter | Description | When to Change |
|-----------|-------------|----------------|
| `Organization` | Your GitHub organization | Only if different from default |
| `RepositoryName` | Your repository name | **Always** - set to your repo |
| `Environment` | Environment (dev/stg/prod) | When deploying to different environments |
| `OIDCProviderStackName` | Name of OIDC provider stack | Only if you used a different stack name |
| `SSMParameterReadPolicyName` | SSM policy name | Must match your environment (dev/stg/prod) |

## Best Practices

1. **One role per repository** - Deploy a separate role for each repository that needs AWS access
2. **Least privilege** - Only add the permissions your application actually needs
3. **Environment separation** - Deploy separate roles for dev/stg/prod environments
4. **Stack naming** - Use a consistent naming pattern like `<repo-name>-github-role-<env>`
5. **Document permissions** - Comment your added policies to explain why they're needed

## Troubleshooting

### Role ARN Not Found in Workflow

Make sure you're using the complete ARN from the CloudFormation output, not just the role name.

### Access Denied to SSM Parameter

Verify the `SSMParameterReadPolicyName` parameter matches the policy created by your `terraform-core-aws` stack.

### OIDC Provider Not Found

Ensure the `github-identity-provider.yaml` stack has been deployed first and the OIDC provider exists:

```bash
aws iam list-open-id-connect-providers
```

### Repository Cannot Assume Role

Check that:
1. The `RepositoryName` parameter exactly matches your GitHub repository name
2. The `Organization` parameter matches your GitHub organization
3. The workflow has `permissions: id-token: write` set

## Examples

### Example 1: S3 Bucket Access

```yaml
ManagedPolicyArns:
  - !Sub 'arn:aws:iam::${AWS::AccountId}:policy/${SSMParameterReadPolicyName}'
Policies:
  - PolicyName: s3-access
    PolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Action:
            - s3:GetObject
            - s3:PutObject
          Resource: 'arn:aws:s3:::my-app-bucket/*'
```

### Example 2: Lambda Deployment

```yaml
ManagedPolicyArns:
  - !Sub 'arn:aws:iam::${AWS::AccountId}:policy/${SSMParameterReadPolicyName}'
  - arn:aws:iam::aws:policy/AWSLambda_FullAccess
```

### Example 3: Full Terraform Permissions

```yaml
ManagedPolicyArns:
  - !Sub 'arn:aws:iam::${AWS::AccountId}:policy/${SSMParameterReadPolicyName}'
  - arn:aws:iam::aws:policy/PowerUserAccess
```

## Support

For issues or questions:
- Check the main [README.md](./README.md) for infrastructure setup
- Review the [USAGE-WITH-TERRAFORM.md](./USAGE-WITH-TERRAFORM.md) for Terraform-specific guidance
- Open an issue on the repository
