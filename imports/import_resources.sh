#!/bin/bash
# Import Resources Script for Ubuntu/Linux
# This script runs the Python import script using the configured virtual environment

# Set strict error handling
set -euo pipefail

# NOTE: Adjust the path as necessary - this assumes we're in the imports/ directory
PYTHON_EXE="../.venv/bin/python"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display help
show_help() {
    echo "Usage: ./import_resources.sh [--dry-run] [--workspace WORKSPACE] [--profile PROFILE]"
    echo ""
    echo "Arguments:"
    echo "  --dry-run              Show what would be imported without actually doing it"
    echo "  --workspace WORKSPACE  Specify the workspace (default: current terraform workspace)"
    echo "  --profile PROFILE      AWS profile to use (default: mfa)"
    echo "  --help                 Show this help message"
    echo ""
}

# Check if help is requested
if [[ "$1" == "--help" || "$1" == "-h" ]] 2>/dev/null; then
    echo "Terraform Resource Import Script"
    echo "================================="
    echo ""
    show_help
    exit 0
fi

echo "Terraform Resource Import Script"
echo "================================="
echo ""

# Check if dry-run mode is requested
if [[ "${1:-}" == "--dry-run" ]]; then
    echo -e "${YELLOW}Running in DRY RUN mode - no actual imports will be performed${NC}"
    echo ""
fi

# Check if we're in the right directory (should have terraform files in parent)
if [[ ! -f "../providers.tf" || ! -f "../variables.tf" ]]; then
    echo -e "${RED}Error: This script should be run from the imports/ directory of the terraform project${NC}"
    echo "Current directory: $(pwd)"
    echo "Expected to find ../providers.tf and ../variables.tf"
    exit 1
fi

# Check if Python virtual environment exists
if [[ ! -f "$PYTHON_EXE" ]]; then
    echo -e "${RED}Error: Python virtual environment not found at $PYTHON_EXE${NC}"
    echo "Please run the following commands from the project root:"
    echo "  python3 -m venv .venv"
    echo "  source .venv/bin/activate"
    echo "  pip install -r imports/requirements.txt"
    exit 1
fi

# Check if import_resources.py exists
if [[ ! -f "import_resources.py" ]]; then
    echo -e "${RED}Error: import_resources.py not found in current directory${NC}"
    exit 1
fi

# Check if requirements are installed
if ! $PYTHON_EXE -c "import boto3" 2>/dev/null; then
    echo -e "${YELLOW}Warning: boto3 not found in virtual environment${NC}"
    echo "Installing dependencies..."
    $PYTHON_EXE -m pip install -r requirements.txt
fi

echo -e "${GREEN}Running import script...${NC}"
echo ""

# Change to parent directory for terraform operations
cd ..

# Run the Python script with all arguments
$PYTHON_EXE imports/import_resources.py "$@"
