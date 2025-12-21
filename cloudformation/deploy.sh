#!/bin/bash
# Deploy CloudFormation stack for Terraform state management
# This script uploads nested templates to S3 and deploys the main stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
STACK_NAME="terraform-core-dev"
TEMPLATE_TYPE="allinone"
PROJECT_NAME="terraform-core-aws"
ORGANIZATION="faccomichele"
ENVIRONMENT="dev"
REGION="us-east-1"
S3_BUCKET=""

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy CloudFormation stack for Terraform state management infrastructure.

OPTIONS:
    -s, --stack-name NAME       Stack name (default: terraform-core-dev)
    -t, --template-type TYPE    Template type: allinone or nested (default: allinone)
    -p, --project-name NAME     Project name (default: terraform-core-aws)
    -o, --organization NAME     Organization name (default: faccomichele)
    -e, --environment ENV       Environment: dev, stg, or prod (default: dev)
    -r, --region REGION         AWS region (default: us-east-1)
    -b, --s3-bucket BUCKET      S3 bucket for nested templates (required for nested type)
    -h, --help                  Show this help message

EXAMPLES:
    # Deploy all-in-one template for dev environment
    $0 --stack-name terraform-core-dev --environment dev

    # Deploy nested stack template for prod environment
    $0 --template-type nested --environment prod --s3-bucket my-cfn-templates

    # Deploy with custom project name
    $0 --project-name my-project --organization myorg --environment stg

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        -t|--template-type)
            TEMPLATE_TYPE="$2"
            shift 2
            ;;
        -p|--project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -o|--organization)
            ORGANIZATION="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -b|--s3-bucket)
            S3_BUCKET="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|stg|prod)$ ]]; then
    print_error "Environment must be dev, stg, or prod"
    exit 1
fi

# Validate template type
if [[ ! "$TEMPLATE_TYPE" =~ ^(allinone|nested)$ ]]; then
    print_error "Template type must be allinone or nested"
    exit 1
fi

# Check if S3 bucket is provided for nested templates
if [[ "$TEMPLATE_TYPE" == "nested" && -z "$S3_BUCKET" ]]; then
    print_error "S3 bucket is required for nested template deployment"
    print_info "Use --s3-bucket option to specify the bucket"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

print_info "CloudFormation Deployment Configuration:"
echo "  Stack Name: $STACK_NAME"
echo "  Template Type: $TEMPLATE_TYPE"
echo "  Project Name: $PROJECT_NAME"
echo "  Organization: $ORGANIZATION"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $REGION"
if [[ "$TEMPLATE_TYPE" == "nested" ]]; then
    echo "  S3 Bucket: $S3_BUCKET"
fi
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured or invalid"
    exit 1
fi

print_info "AWS credentials validated"

# Deploy based on template type
if [[ "$TEMPLATE_TYPE" == "allinone" ]]; then
    print_info "Validating all-in-one template..."
    aws cloudformation validate-template \
        --template-body file://${SCRIPT_DIR}/terraform-core-allinone.yaml \
        --region $REGION > /dev/null
    
    print_info "Deploying all-in-one CloudFormation stack..."
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://${SCRIPT_DIR}/terraform-core-allinone.yaml \
        --parameters \
            ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
            ParameterKey=Organization,ParameterValue=$ORGANIZATION \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
        --capabilities CAPABILITY_NAMED_IAM \
        --tags Key=ManagedBy,Value=CloudFormation Key=Environment,Value=$ENVIRONMENT \
        --region $REGION
    
else
    print_info "Uploading nested templates to S3..."
    
    # Upload nested templates
    aws s3 cp ${SCRIPT_DIR}/nested/s3-state-bucket.yaml \
        s3://${S3_BUCKET}/cloudformation/nested/s3-state-bucket.yaml \
        --region $REGION
    
    aws s3 cp ${SCRIPT_DIR}/nested/iam-state-role.yaml \
        s3://${S3_BUCKET}/cloudformation/nested/iam-state-role.yaml \
        --region $REGION
    
    aws s3 cp ${SCRIPT_DIR}/nested/ssm-backend-config.yaml \
        s3://${S3_BUCKET}/cloudformation/nested/ssm-backend-config.yaml \
        --region $REGION
    
    print_info "Nested templates uploaded successfully"
    
    # Construct template base URL
    TEMPLATE_BASE_URL="http://${S3_BUCKET}.s3.amazonaws.com/cloudformation/nested"
    
    print_info "Validating main template..."
    aws cloudformation validate-template \
        --template-body file://${SCRIPT_DIR}/terraform-core-main.yaml \
        --region $REGION > /dev/null
    
    print_info "Deploying nested CloudFormation stack..."
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://${SCRIPT_DIR}/terraform-core-main.yaml \
        --parameters \
            ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
            ParameterKey=Organization,ParameterValue=$ORGANIZATION \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=TemplateBaseURL,ParameterValue=$TEMPLATE_BASE_URL \
        --capabilities CAPABILITY_NAMED_IAM \
        --tags Key=ManagedBy,Value=CloudFormation Key=Environment,Value=$ENVIRONMENT \
        --region $REGION
fi

print_info "CloudFormation stack creation initiated: $STACK_NAME"
print_info "Waiting for stack creation to complete (this may take a few minutes)..."

# Wait for stack creation
aws cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME \
    --region $REGION

if [ $? -eq 0 ]; then
    print_info "Stack created successfully!"
    echo ""
    print_info "Stack Outputs:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
    
    echo ""
    print_info "To retrieve the backend configuration:"
    echo "  aws ssm get-parameter --name /terraform-core/backend_configuration_hcl --with-decryption --query 'Parameter.Value' --output text"
else
    print_error "Stack creation failed. Check CloudFormation console for details."
    exit 1
fi
