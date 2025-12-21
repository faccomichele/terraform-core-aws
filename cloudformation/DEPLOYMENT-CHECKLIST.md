# CloudFormation Deployment Checklist

Use this checklist to ensure a successful deployment of the Terraform state management infrastructure using CloudFormation.

## Pre-Deployment Checklist

### ✅ AWS Environment Setup
- [ ] AWS CLI installed and configured
- [ ] AWS credentials configured (run `aws sts get-caller-identity` to verify)
- [ ] Target AWS region identified (e.g., us-east-1)
- [ ] Required IAM permissions available:
  - [ ] CloudFormation: create/update/delete stacks
  - [ ] S3: create buckets, configure versioning/encryption
  - [ ] IAM: create roles and policies
  - [ ] SSM: create parameters

### ✅ Template Selection
Choose one of the following deployment methods:

- [ ] **Option A: All-in-One Template** (Recommended for simplicity)
  - Single template file: `terraform-core-allinone.yaml`
  - No S3 bucket needed for templates
  - Easier to manage and deploy

- [ ] **Option B: Nested Stack Template** (Recommended for modularity)
  - Main template: `terraform-core-main.yaml`
  - Nested templates: `nested/*.yaml`
  - Requires S3 bucket for hosting templates
  - Better organization for complex scenarios

### ✅ Parameter Configuration
- [ ] Review and customize parameters:
  - [ ] `ProjectName`: Your project identifier (lowercase, alphanumeric with hyphens)
  - [ ] `Organization`: Your organization identifier (lowercase, alphanumeric with hyphens)
  - [ ] `Environment`: Choose from dev, stg, or prod
  - [ ] `TemplateBaseURL`: (Only for nested stacks) HTTP URL to S3-hosted templates

- [ ] Create or modify parameter files:
  - [ ] `parameters-dev.json` for development
  - [ ] `parameters-stg.json` for staging
  - [ ] `parameters-prod.json` for production

### ✅ Template Validation (Optional but Recommended)
- [ ] Install cfn-lint: `pip install cfn-lint`
- [ ] Validate all-in-one template: `cfn-lint terraform-core-allinone.yaml`
- [ ] Validate nested templates: `cfn-lint nested/*.yaml terraform-core-main.yaml`
- [ ] Or use AWS CLI: `aws cloudformation validate-template --template-body file://terraform-core-allinone.yaml`

## Deployment Steps

### Option A: All-in-One Template Deployment

#### Using Deployment Script
```bash
# Make script executable (Linux/Mac)
chmod +x deploy.sh

# Deploy
./deploy.sh --stack-name terraform-core-dev --environment dev

# OR on Windows
deploy.bat --stack-name terraform-core-dev --environment dev
```

- [ ] Script executed successfully
- [ ] Stack creation initiated
- [ ] Monitored stack creation progress

#### Using AWS CLI
```bash
aws cloudformation create-stack \
  --stack-name terraform-core-dev \
  --template-body file://terraform-core-allinone.yaml \
  --parameters file://parameters-dev.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

- [ ] Command executed successfully
- [ ] Stack creation initiated
- [ ] Monitored stack creation progress

### Option B: Nested Stack Deployment

#### Step 1: S3 Setup for Templates
- [ ] S3 bucket created for templates
  ```bash
  aws s3 mb s3://my-cfn-templates-bucket --region us-east-1
  ```
- [ ] Nested templates uploaded
  ```bash
  aws s3 cp nested/ s3://my-cfn-templates-bucket/cloudformation/nested/ --recursive
  ```
- [ ] Templates are accessible (public-read ACL or bucket policy configured)
- [ ] HTTP URLs verified and working

#### Step 2: Deploy Main Stack
```bash
./deploy.sh --template-type nested --s3-bucket my-cfn-templates-bucket --environment dev
```

- [ ] Script executed successfully
- [ ] All nested stacks created
- [ ] Main stack creation completed

## Post-Deployment Verification

### ✅ Stack Status
- [ ] Stack creation completed successfully (status: CREATE_COMPLETE)
  ```bash
  aws cloudformation describe-stacks --stack-name terraform-core-dev --query 'Stacks[0].StackStatus'
  ```
- [ ] No errors in stack events
  ```bash
  aws cloudformation describe-stack-events --stack-name terraform-core-dev --max-items 20
  ```

### ✅ Resources Created
Verify all resources were created:

- [ ] S3 bucket exists with correct name pattern: `{project}-state-files-{env}-{account-id}`
  ```bash
  aws cloudformation describe-stacks --stack-name terraform-core-dev \
    --query 'Stacks[0].Outputs[?OutputKey==`StateBucketName`].OutputValue' --output text
  ```
- [ ] S3 bucket has versioning enabled
- [ ] S3 bucket has encryption enabled
- [ ] S3 bucket has public access blocked
- [ ] S3 bucket has lifecycle rules configured

- [ ] IAM role created with correct name pattern: `{project}-state-files-{env}`
  ```bash
  aws cloudformation describe-stacks --stack-name terraform-core-dev \
    --query 'Stacks[0].Outputs[?OutputKey==`StateRoleName`].OutputValue' --output text
  ```
- [ ] IAM role has correct assume role policy
- [ ] IAM role has policy attached with S3 permissions

- [ ] SSM parameter created: `/terraform-core/backend_configuration_hcl`
  ```bash
  aws ssm get-parameter --name /terraform-core/backend_configuration_hcl
  ```

### ✅ Stack Outputs
Retrieve and save stack outputs:

- [ ] StateBucketName
- [ ] StateBucketArn
- [ ] StateRoleArn
- [ ] StateRoleName
- [ ] BackendConfigurationParameterName
- [ ] BackendConfigurationHCL

```bash
aws cloudformation describe-stacks --stack-name terraform-core-dev \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' --output table
```

### ✅ Backend Configuration
- [ ] Backend configuration retrieved from SSM
  ```bash
  aws ssm get-parameter \
    --name /terraform-core/backend_configuration_hcl \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text
  ```
- [ ] Backend configuration saved for use in other Terraform projects
- [ ] Backend configuration tested (optional: create a test Terraform project)

## Testing (Optional)

### ✅ Integration Test
Create a test Terraform project to verify the backend works:

1. [ ] Create test directory: `mkdir test-terraform-backend && cd test-terraform-backend`
2. [ ] Create `main.tf` with backend configuration from SSM parameter
3. [ ] Update the `key` parameter in backend config to `test/terraform.tfstate`
4. [ ] Run `terraform init` to initialize with remote backend
5. [ ] Create a simple resource: `resource "null_resource" "test" {}`
6. [ ] Run `terraform apply`
7. [ ] Verify state file exists in S3 bucket
8. [ ] Run `terraform destroy`
9. [ ] Clean up test directory

### ✅ Permission Test
Verify IAM role can be assumed:

```bash
aws sts assume-role \
  --role-arn $(aws cloudformation describe-stacks --stack-name terraform-core-dev \
    --query 'Stacks[0].Outputs[?OutputKey==`StateRoleArn`].OutputValue' --output text) \
  --role-session-name test-session
```

- [ ] Role assumption successful
- [ ] Temporary credentials received

## Documentation

- [ ] Document the following for your team:
  - [ ] Stack name(s) used
  - [ ] Environment parameter values
  - [ ] S3 bucket name for state files
  - [ ] IAM role ARN for state access
  - [ ] SSM parameter name for backend config
  - [ ] How to retrieve backend configuration
  - [ ] How to update the stack
  - [ ] Emergency contacts for issues

- [ ] Update project documentation with CloudFormation stack information
- [ ] Add backend configuration to Terraform projects
- [ ] Share deployment guide with team

## Multi-Environment Deployment

If deploying to multiple environments, repeat the process for each:

### Development Environment
- [ ] Stack name: terraform-core-dev
- [ ] Environment parameter: dev
- [ ] Stack deployed and verified

### Staging Environment
- [ ] Stack name: terraform-core-stg
- [ ] Environment parameter: stg
- [ ] Stack deployed and verified

### Production Environment
- [ ] Stack name: terraform-core-prod
- [ ] Environment parameter: prod
- [ ] Stack deployed and verified

## Troubleshooting

If deployment fails:

- [ ] Check CloudFormation events for error messages
  ```bash
  aws cloudformation describe-stack-events --stack-name terraform-core-dev
  ```
- [ ] Verify IAM permissions are sufficient
- [ ] Check if bucket name conflicts exist
- [ ] For nested stacks, verify template URLs are accessible
- [ ] Review parameter values for correctness
- [ ] Check AWS service quotas and limits

Common issues:
- [ ] `AccessDenied`: Check IAM permissions
- [ ] `AlreadyExists`: Bucket or IAM role name conflict
- [ ] `ValidationError`: Template syntax or parameter issue
- [ ] `TemplateURL not found`: Nested template not accessible via HTTP

## Maintenance

### Regular Tasks
- [ ] Monitor S3 bucket size and costs
- [ ] Review lifecycle rules effectiveness
- [ ] Audit IAM role usage
- [ ] Review and update parameters as needed
- [ ] Keep templates in sync with requirements

### Updates
When updating the stack:
- [ ] Review changes in template
- [ ] Create change set to preview changes
  ```bash
  aws cloudformation create-change-set \
    --stack-name terraform-core-dev \
    --template-body file://terraform-core-allinone.yaml \
    --parameters file://parameters-dev.json \
    --change-set-name update-$(date +%Y%m%d-%H%M%S) \
    --capabilities CAPABILITY_NAMED_IAM
  ```
- [ ] Review change set
- [ ] Execute change set if acceptable
- [ ] Verify updated resources

## Cleanup

If you need to delete the stack:

⚠️ **Warning**: This will attempt to delete all resources, but S3 buckets with objects will not be deleted by default.

- [ ] Backup any important state files from S3 bucket
- [ ] Delete stack:
  ```bash
  aws cloudformation delete-stack --stack-name terraform-core-dev
  ```
- [ ] Wait for deletion to complete:
  ```bash
  aws cloudformation wait stack-delete-complete --stack-name terraform-core-dev
  ```
- [ ] If S3 bucket remains, manually empty and delete it:
  ```bash
  aws s3 rm s3://bucket-name --recursive
  aws s3 rb s3://bucket-name
  ```
- [ ] Verify all resources are deleted

## Sign-Off

- [ ] Deployment completed successfully
- [ ] All verification checks passed
- [ ] Documentation updated
- [ ] Team notified
- [ ] Deployment date: _______________
- [ ] Deployed by: _______________
- [ ] Reviewed by: _______________

---

**Next Steps**: Configure your Terraform projects to use the newly deployed backend!
