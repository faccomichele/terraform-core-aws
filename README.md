# Terraform State Management Infrastructure

This Terraform configuration creates the foundational infrastructure for managing Terra### Import Script Options

```bash
# Direct Python execution
python imports/import_resources.py [OPTIONS]

# Windows wrapper script
imports/import_resources.bat [OPTIONS]

# Ubuntu/Linux wrapper script  
./imports/import_resources.sh [OPTIONS]

Options:
  --dry-run              Show what would be imported without doing it
  --workspace WORKSPACE  Specify workspace (default: current terraform workspace)
  --profile PROFILE      AWS profile to use (default: mfa)
  --help                Show help message
```

### Platform-Specific Notes

**Ubuntu/Linux Users:**
- Make the script executable: `chmod +x imports/import_resources.sh`
- Ensure Python virtual environment is created with: `python3 -m venv .venv`
- Activate virtual environment: `source .venv/bin/activate`

**Windows Users:**
- The batch script automatically uses the correct Python executable path
- Ensure virtual environment is created with: `python -m venv .venv`files across your project. It includes:

- **S3 Bucket**: Encrypted bucket for storing Terraform state files
- **IAM Role**: Role that can be assumed to access the state bucket with read/write permissions
- **Security**: Public access blocked, versioning enabled, lifecycle rules for cost optimization

## Features

### S3 Bucket
- **Encryption**: AES256 encryption enabled by default
- **Versioning**: Enabled to track state file changes
- **Public Access**: Completely blocked for security
- **Lifecycle Rules**: Automatically transition old versions to cheaper storage classes
- **Unique Naming**: Automatically generates unique bucket names to avoid conflicts

### IAM Role
- **Assume Role**: Supports local-only account access
- **Least Privilege**: Only permissions needed for Terraform state management

## Usage

### 1. Initial Setup

```bash
# Initialize Terraform
terraform init -upgrade

# Create or select a workspace
terraform workspace select -or-create __NAME__
```

### 2. Deploy the Infrastructure

```bash
# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 3. Configure Remote State in Other Projects

After deployment, use the `backend_configuration_hcl` output to configure remote state in your other Terraform projects.
Export the backend configuration to a local file with:

```bash
terraform output -raw backend_configuration_hcl > exports/backend-config.tf
```

Then, copy the contents of `exports/backend-config.tf` into your other project's Terraform configuration, or reference it as needed.

Example backend configuration (from output):

```hcl
terraform {
  backend "s3" {
    bucket     = "${aws_s3_bucket.terraform_state.id}"
    key        = "CHANGE_ME/terraform.tfstate"
    region     = "${data.aws_region.current.name}"
    assume_role = {
      role_arn   = "${aws_iam_role.terraform_state_role.arn}"
    }
    encrypt    = true
  }
}
```

## Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `project_name` | Name of the project | `string` | `"terraform-core"` | No |
| `repository_url` | URL for the Git repository | `string` | `"https://github.com/faccomichele/terraform-core"` | No |
| `import_existing_resources` | Whether to import existing AWS resources instead of creating new ones | `bool` | `false` | No |

## Importing Existing Resources

If you have existing infrastructure that matches the naming conventions used by this configuration, you can import it instead of creating new resources.

### Prerequisites for Import

1. **Python Environment**: Ensure Python 3.12+ is installed
2. **AWS Profile**: Configure the 'mfa' AWS profile with appropriate permissions
3. **Dependencies**: Install required Python packages

```bash
# Install Python dependencies
pip install -r imports/requirements.txt
```

### How to Import

1. **Set the import variable**:
   ```bash
   # Create a terraform.tfvars file or set the variable
   echo 'import_existing_resources = true' > terraform.tfvars
   ```

2. **Run the import script**:
   ```bash
   # Dry run to see what would be imported
   python imports/import_resources.py --dry-run
   
   # On Windows
   imports/import_resources.bat --dry-run
   
   # On Ubuntu/Linux
   ./imports/import_resources.sh --dry-run
   
   # Actual import
   python imports/import_resources.py
   
   # Or using the wrapper scripts:
   # Windows:
   imports/import_resources.bat
   
   # Ubuntu/Linux:
   ./imports/import_resources.sh
   ```

3. **Verify the import**:
   ```bash
   terraform plan
   ```

The import script will:
- Automatically discover existing S3 buckets and IAM roles that match the expected naming pattern
- Use the configured 'mfa' AWS profile to connect to AWS
- Import all related resources (versioning, encryption, policies, etc.)
- Provide detailed output of what was imported

### Import Script Options

```bash
python imports/import_resources.py [OPTIONS]

Options:
  --dry-run              Show what would be imported without doing it
  --workspace WORKSPACE  Specify workspace (default: current terraform workspace)
  --profile PROFILE      AWS profile to use (default: mfa)
  --help                Show help message
```

## Outputs

| Output | Description |
|--------|-------------|
| `backend_configuration_hcl` | Ready-to-use backend configuration |

## Security Considerations

1. **Trusted Principals**: Configured to only allow the local account
2. **Encryption**: All state files are encrypted at rest
3. **Access Logging**: Consider enabling S3 access logging for audit trails

## Cost Optimization

- **Lifecycle Rules**: Automatically expires old state versions
- **Cleanup**: Regularly review and clean up old state file versions

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Permissions to create S3 buckets and IAM roles in your AWS account
