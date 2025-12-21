@echo off
REM Deploy CloudFormation stack for Terraform state management
REM This script uploads nested templates to S3 and deploys the main stack

setlocal EnableDelayedExpansion

REM Default values
set STACK_NAME=terraform-core-dev
set TEMPLATE_TYPE=allinone
set PROJECT_NAME=terraform-core-aws
set ORGANIZATION=faccomichele
set ENVIRONMENT=dev
set REGION=us-east-1
set S3_BUCKET=

REM Parse command line arguments
:parse_args
if "%~1"=="" goto end_parse
if /i "%~1"=="-s" set STACK_NAME=%~2& shift & shift & goto parse_args
if /i "%~1"=="--stack-name" set STACK_NAME=%~2& shift & shift & goto parse_args
if /i "%~1"=="-t" set TEMPLATE_TYPE=%~2& shift & shift & goto parse_args
if /i "%~1"=="--template-type" set TEMPLATE_TYPE=%~2& shift & shift & goto parse_args
if /i "%~1"=="-p" set PROJECT_NAME=%~2& shift & shift & goto parse_args
if /i "%~1"=="--project-name" set PROJECT_NAME=%~2& shift & shift & goto parse_args
if /i "%~1"=="-o" set ORGANIZATION=%~2& shift & shift & goto parse_args
if /i "%~1"=="--organization" set ORGANIZATION=%~2& shift & shift & goto parse_args
if /i "%~1"=="-e" set ENVIRONMENT=%~2& shift & shift & goto parse_args
if /i "%~1"=="--environment" set ENVIRONMENT=%~2& shift & shift & goto parse_args
if /i "%~1"=="-r" set REGION=%~2& shift & shift & goto parse_args
if /i "%~1"=="--region" set REGION=%~2& shift & shift & goto parse_args
if /i "%~1"=="-b" set S3_BUCKET=%~2& shift & shift & goto parse_args
if /i "%~1"=="--s3-bucket" set S3_BUCKET=%~2& shift & shift & goto parse_args
if /i "%~1"=="-h" goto usage
if /i "%~1"=="--help" goto usage
shift
goto parse_args
:end_parse

REM Get script directory
set SCRIPT_DIR=%~dp0

echo.
echo CloudFormation Deployment Configuration:
echo   Stack Name: %STACK_NAME%
echo   Template Type: %TEMPLATE_TYPE%
echo   Project Name: %PROJECT_NAME%
echo   Organization: %ORGANIZATION%
echo   Environment: %ENVIRONMENT%
echo   Region: %REGION%
if not "%S3_BUCKET%"=="" echo   S3 Bucket: %S3_BUCKET%
echo.

REM Check if AWS CLI is installed
where aws >nul 2>&1
if errorlevel 1 (
    echo [ERROR] AWS CLI is not installed. Please install it first.
    exit /b 1
)

REM Check AWS credentials
aws sts get-caller-identity >nul 2>&1
if errorlevel 1 (
    echo [ERROR] AWS credentials not configured or invalid
    exit /b 1
)

echo [INFO] AWS credentials validated
echo.

REM Deploy based on template type
if /i "%TEMPLATE_TYPE%"=="allinone" (
    echo [INFO] Validating all-in-one template...
    aws cloudformation validate-template --template-body file://%SCRIPT_DIR%terraform-core-allinone.yaml --region %REGION% >nul
    if errorlevel 1 (
        echo [ERROR] Template validation failed
        exit /b 1
    )
    
    echo [INFO] Deploying all-in-one CloudFormation stack...
    aws cloudformation create-stack ^
        --stack-name %STACK_NAME% ^
        --template-body file://%SCRIPT_DIR%terraform-core-allinone.yaml ^
        --parameters ^
            ParameterKey=ProjectName,ParameterValue=%PROJECT_NAME% ^
            ParameterKey=Organization,ParameterValue=%ORGANIZATION% ^
            ParameterKey=Environment,ParameterValue=%ENVIRONMENT% ^
        --capabilities CAPABILITY_NAMED_IAM ^
        --tags Key=ManagedBy,Value=CloudFormation Key=Environment,Value=%ENVIRONMENT% ^
        --region %REGION%
    
) else if /i "%TEMPLATE_TYPE%"=="nested" (
    if "%S3_BUCKET%"=="" (
        echo [ERROR] S3 bucket is required for nested template deployment
        echo [INFO] Use --s3-bucket option to specify the bucket
        exit /b 1
    )
    
    echo [INFO] Uploading nested templates to S3...
    
    aws s3 cp %SCRIPT_DIR%nested\s3-state-bucket.yaml s3://%S3_BUCKET%/cloudformation/nested/s3-state-bucket.yaml --region %REGION%
    aws s3 cp %SCRIPT_DIR%nested\iam-state-role.yaml s3://%S3_BUCKET%/cloudformation/nested/iam-state-role.yaml --region %REGION%
    aws s3 cp %SCRIPT_DIR%nested\ssm-backend-config.yaml s3://%S3_BUCKET%/cloudformation/nested/ssm-backend-config.yaml --region %REGION%
    
    echo [INFO] Nested templates uploaded successfully
    
    set TEMPLATE_BASE_URL=http://%S3_BUCKET%.s3.amazonaws.com/cloudformation/nested
    
    echo [INFO] Validating main template...
    aws cloudformation validate-template --template-body file://%SCRIPT_DIR%terraform-core-main.yaml --region %REGION% >nul
    if errorlevel 1 (
        echo [ERROR] Template validation failed
        exit /b 1
    )
    
    echo [INFO] Deploying nested CloudFormation stack...
    aws cloudformation create-stack ^
        --stack-name %STACK_NAME% ^
        --template-body file://%SCRIPT_DIR%terraform-core-main.yaml ^
        --parameters ^
            ParameterKey=ProjectName,ParameterValue=%PROJECT_NAME% ^
            ParameterKey=Organization,ParameterValue=%ORGANIZATION% ^
            ParameterKey=Environment,ParameterValue=%ENVIRONMENT% ^
            ParameterKey=TemplateBaseURL,ParameterValue=!TEMPLATE_BASE_URL! ^
        --capabilities CAPABILITY_NAMED_IAM ^
        --tags Key=ManagedBy,Value=CloudFormation Key=Environment,Value=%ENVIRONMENT% ^
        --region %REGION%
) else (
    echo [ERROR] Invalid template type: %TEMPLATE_TYPE%
    echo [INFO] Template type must be allinone or nested
    exit /b 1
)

if errorlevel 1 (
    echo [ERROR] Stack creation failed
    exit /b 1
)

echo [INFO] CloudFormation stack creation initiated: %STACK_NAME%
echo [INFO] Waiting for stack creation to complete (this may take a few minutes)...
echo.

aws cloudformation wait stack-create-complete --stack-name %STACK_NAME% --region %REGION%

if errorlevel 1 (
    echo [ERROR] Stack creation failed. Check CloudFormation console for details.
    exit /b 1
)

echo [INFO] Stack created successfully!
echo.
echo [INFO] Stack Outputs:
aws cloudformation describe-stacks --stack-name %STACK_NAME% --region %REGION% --query "Stacks[0].Outputs[*].[OutputKey,OutputValue]" --output table
echo.
echo [INFO] To retrieve the backend configuration:
echo   aws ssm get-parameter --name /terraform-core/backend_configuration_hcl --with-decryption --query "Parameter.Value" --output text
echo.

goto :eof

:usage
echo Usage: %~nx0 [OPTIONS]
echo.
echo Deploy CloudFormation stack for Terraform state management infrastructure.
echo.
echo OPTIONS:
echo     -s, --stack-name NAME       Stack name (default: terraform-core-dev)
echo     -t, --template-type TYPE    Template type: allinone or nested (default: allinone)
echo     -p, --project-name NAME     Project name (default: terraform-core-aws)
echo     -o, --organization NAME     Organization name (default: faccomichele)
echo     -e, --environment ENV       Environment: dev, stg, or prod (default: dev)
echo     -r, --region REGION         AWS region (default: us-east-1)
echo     -b, --s3-bucket BUCKET      S3 bucket for nested templates (required for nested type)
echo     -h, --help                  Show this help message
echo.
echo EXAMPLES:
echo     REM Deploy all-in-one template for dev environment
echo     %~nx0 --stack-name terraform-core-dev --environment dev
echo.
echo     REM Deploy nested stack template for prod environment
echo     %~nx0 --template-type nested --environment prod --s3-bucket my-cfn-templates
echo.
exit /b 0
