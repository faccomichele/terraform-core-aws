# Using the CloudFormation-Deployed Backend with Terraform

After deploying the CloudFormation stack, you can use the created infrastructure as a backend for your Terraform projects.

## Step 1: Retrieve Backend Configuration

Get the backend configuration from AWS SSM Parameter Store:

```bash
aws ssm get-parameter \
  --name /terraform-core/backend_configuration_hcl \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```

This will output something like:

```hcl
terraform {
  backend "s3" {
    bucket        = "terraform-core-aws-state-files-dev-123456789012"
    key           = "CHANGE_ME/terraform.tfstate"
    region        = "us-east-1"
    assume_role = {
      role_arn      = "arn:aws:iam::123456789012:role/terraform-core-aws-state-files-dev"
    }
    encrypt       = true
    use_lockfile  = true
  }
}
```

## Step 2: Configure Your Terraform Project

Create or update your Terraform project's backend configuration:

### Option A: In main.tf

```hcl
terraform {
  required_version = ">= 1.0"
  
  # Backend configuration for remote state
  backend "s3" {
    bucket        = "terraform-core-aws-state-files-dev-123456789012"
    key           = "my-project/terraform.tfstate"  # <- CHANGE THIS for each project
    region        = "us-east-1"
    assume_role = {
      role_arn      = "arn:aws:iam::123456789012:role/terraform-core-aws-state-files-dev"
    }
    encrypt       = true
    use_lockfile  = true
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Option B: In backend.tf (Separate File)

Create a file named `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket        = "terraform-core-aws-state-files-dev-123456789012"
    key           = "my-project/terraform.tfstate"
    region        = "us-east-1"
    assume_role = {
      role_arn      = "arn:aws:iam::123456789012:role/terraform-core-aws-state-files-dev"
    }
    encrypt       = true
    use_lockfile  = true
  }
}
```

### Option C: Using Backend Config File

Create a file named `backend-config.tfbackend`:

```hcl
bucket  = "terraform-core-aws-state-files-dev-123456789012"
key     = "my-project/terraform.tfstate"
region  = "us-east-1"

assume_role = {
  role_arn = "arn:aws:iam::123456789012:role/terraform-core-aws-state-files-dev"
}

encrypt      = true
use_lockfile = true
```

Then initialize with:

```bash
terraform init -backend-config=backend-config.tfbackend
```

### Attaching the SSM Read Policy

- This CloudFormation stack creates a standalone managed policy named `${ProjectName}-ssm-read-${Environment}` (resource `SSMParameterReadPolicy`) which grants `ssm:GetParameter` and `ssm:GetParameters` for the parameter `/terraform-core/backend_configuration_hcl`.

- To allow a deployment role (for example the role used by your CI or by a peer Terraform repo) to retrieve the backend configuration from SSM, attach this managed policy to that role. Example using the AWS CLI (replace placeholders):

```bash
aws iam attach-role-policy \
  --role-name <deployment-role-name> \
  --policy-arn arn:aws:iam::<account-id>:policy/${ProjectName}-ssm-read-<env>
```

- In Terraform you can attach it using a `data` lookup and `aws_iam_role_policy_attachment`:

```hcl
data "aws_iam_policy" "ssm_read" {
  name = "${ProjectName}-ssm-read-${Environment}"
}

resource "aws_iam_role_policy_attachment" "attach_ssm_read" {
  role       = aws_iam_role.deployment_role.name
  policy_arn = data.aws_iam_policy.ssm_read.arn
}
```

- Attaching this policy (or granting equivalent SSM read permissions) ensures peer repositories can always pull the updated backend configuration from SSM.

## Step 3: Initialize Terraform

```bash
terraform init
```

You should see output similar to:

```
Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
...
Terraform has been successfully initialized!
```

## Step 4: Verify State Storage

After running `terraform apply`, verify the state file is stored in S3:

```bash
# List objects in the state bucket
aws s3 ls s3://terraform-core-aws-state-files-dev-123456789012/my-project/

# Should show: terraform.tfstate
```

## Important Notes

### 🔑 Key Parameter

**IMPORTANT**: Change the `key` parameter for each Terraform project!

- Use a unique key for each project to avoid state conflicts
- Recommended format: `<project-name>/terraform.tfstate`
- Examples:
  - `web-app/terraform.tfstate`
  - `database/terraform.tfstate`
  - `networking/terraform.tfstate`
  - `team-a/project-x/terraform.tfstate`

### 🔐 IAM Role Assumption

The backend configuration uses IAM role assumption for authentication:

- Ensure your AWS credentials have permission to assume the role
- The role ARN is: `arn:aws:iam::<account-id>:role/terraform-core-aws-state-files-<env>`
- The assume role policy allows principals from the same AWS account

To assume the role manually (for testing):

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/terraform-core-aws-state-files-dev \
  --role-session-name test-session
```

### 🔒 Encryption

- All state files are encrypted at rest using AES256
- The `encrypt = true` setting ensures encryption is enforced
- Use `use_lockfile = true` for state file locking (Terraform 1.1+)

### 🌍 Multiple Environments

For multiple environments, use different stacks:

```hcl
# Development
terraform {
  backend "s3" {
    bucket = "terraform-core-aws-state-files-dev-123456789012"
    key    = "my-project/terraform.tfstate"
    region = "us-east-1"
    assume_role = {
      role_arn = "arn:aws:iam::123456789012:role/terraform-core-aws-state-files-dev"
    }
    encrypt      = true
    use_lockfile = true
  }
}

# Production
terraform {
  backend "s3" {
    bucket = "terraform-core-aws-state-files-prod-123456789012"
    key    = "my-project/terraform.tfstate"
    region = "us-east-1"
    assume_role = {
      role_arn = "arn:aws:iam::123456789012:role/terraform-core-aws-state-files-prod"
    }
    encrypt      = true
    use_lockfile = true
  }
}
```

## Complete Example Project

Here's a complete example Terraform project using the remote backend:

### Directory Structure
```
my-terraform-project/
├── backend.tf
├── main.tf
├── variables.tf
└── outputs.tf
```

### backend.tf
```hcl
terraform {
  backend "s3" {
    bucket        = "terraform-core-aws-state-files-dev-123456789012"
    key           = "example-project/terraform.tfstate"
    region        = "us-east-1"
    assume_role = {
      role_arn      = "arn:aws:iam::123456789012:role/terraform-core-aws-state-files-dev"
    }
    encrypt       = true
    use_lockfile  = true
  }
}
```

### main.tf
```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Example resource
resource "aws_s3_bucket" "example" {
  bucket_prefix = "example-bucket-"
  
  tags = {
    Name        = "Example Bucket"
    Environment = var.environment
  }
}
```

### variables.tf
```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
```

### outputs.tf
```hcl
output "bucket_name" {
  description = "Name of the created bucket"
  value       = aws_s3_bucket.example.id
}
```

### Deploy the Example Project

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Verify state in S3
aws s3 ls s3://terraform-core-aws-state-files-dev-123456789012/example-project/

# Clean up
terraform destroy
```

## Migrating Existing Local State

If you have an existing Terraform project with local state and want to migrate to the remote backend:

1. **Backup your local state**:
   ```bash
   cp terraform.tfstate terraform.tfstate.backup
   ```

2. **Add backend configuration** to your Terraform files (as shown above)

3. **Initialize with migration**:
   ```bash
   terraform init -migrate-state
   ```

4. **Confirm migration** when prompted:
   ```
   Do you want to copy existing state to the new backend?
   Enter a value: yes
   ```

5. **Verify state was migrated**:
   ```bash
   terraform state list
   aws s3 ls s3://terraform-core-aws-state-files-dev-123456789012/my-project/
   ```

6. **Remove local state files** (after verification):
   ```bash
   rm terraform.tfstate terraform.tfstate.backup
   ```

## Troubleshooting

### Error: "Error loading state: AccessDenied"

**Solution**: Ensure your AWS credentials have permission to assume the IAM role:

```bash
# Test role assumption
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/terraform-core-aws-state-files-dev \
  --role-session-name test
```

### Error: "Error acquiring the state lock"

**Solution**: Another Terraform operation is in progress or a previous operation failed to release the lock. Wait for the other operation to complete or manually release the lock:

```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

### Error: "S3 bucket does not exist"

**Solution**: Verify the CloudFormation stack was deployed successfully and the bucket exists:

```bash
aws cloudformation describe-stacks --stack-name terraform-core-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`StateBucketName`].OutputValue' --output text
```

### Error: "Error loading backend config"

**Solution**: Check your backend configuration syntax. Ensure all required parameters are present:
- `bucket`
- `key`
- `region`

## Best Practices

1. **Unique Keys**: Always use unique state file keys for each project
2. **Environment Separation**: Use separate stacks for dev, staging, and production
3. **State Locking**: Enable state locking with `use_lockfile = true` (Terraform 1.1+)
4. **Version Control**: Do NOT commit state files to version control
5. **Access Control**: Limit who can assume the IAM role for production environments
6. **Backup**: S3 versioning is enabled, allowing you to recover previous state versions
7. **Encryption**: Always use `encrypt = true` in backend configuration
8. **Documentation**: Document which projects use which state file keys

## Additional Resources

- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [Terraform State Documentation](https://www.terraform.io/docs/language/state/index.html)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
