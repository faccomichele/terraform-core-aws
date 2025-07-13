#!/usr/bin/env python3
"""
Terraform Resource Import Script

This script automatically discovers and imports existing AWS resources
based on the configured project name and workspace. It uses the 'mfa'
AWS profile to connect to AWS and discover resources that match the
expected naming pattern.

Usage:
    python imports/import_resources.py [--dry-run] [--workspace WORKSPACE]
    
Arguments:
    --dry-run: Show what would be imported without actually doing it
    --workspace: Specify the workspace (default: current terraform workspace)
"""

import argparse
import boto3
import subprocess
import sys
from typing import List, Optional, Tuple


class TerraformImporter:
    def __init__(self, profile: str = "mfa", workspace: Optional[str] = None):
        """Initialize the importer with AWS profile and workspace."""
        self.profile = profile
        self.workspace = workspace or self._get_current_workspace()
        self.session = boto3.Session(profile_name=profile)
        self.s3_client = self.session.client('s3')
        self.iam_client = self.session.client('iam')
        
        # Read project configuration
        self.project_name = self._get_project_name()
        self.resource_prefix = f"{self.project_name}-state-files-{self.workspace}"
        
    def _get_current_workspace(self) -> str:
        """Get the current Terraform workspace."""
        try:
            result = subprocess.run(
                ["terraform", "workspace", "show"],
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            print("Error: Could not get current Terraform workspace")
            sys.exit(1)
    
    def _get_project_name(self) -> str:
        """Extract project name from variables.tf or use default."""
        try:
            # Try to extract from terraform configuration
            result = subprocess.run(
                ["terraform", "console"],
                input="var.project_name\n",
                capture_output=True,
                text=True,
                check=True
            )
            project_name = result.stdout.strip().strip('"')
            return project_name if project_name else "terraform-core"
        except:
            return "terraform-core"
    
    def discover_s3_bucket(self) -> Optional[str]:
        """Discover S3 bucket that matches the expected prefix."""
        try:
            response = self.s3_client.list_buckets()
            for bucket in response['Buckets']:
                bucket_name = bucket['Name']
                if bucket_name.startswith(self.resource_prefix):
                    print(f"Found S3 bucket: {bucket_name}")
                    return bucket_name
            return None
        except Exception as e:
            print(f"Error discovering S3 bucket: {e}")
            return None
    
    def discover_iam_role(self) -> Optional[str]:
        """Discover IAM role that matches the expected prefix."""
        try:
            paginator = self.iam_client.get_paginator('list_roles')
            for page in paginator.paginate():
                for role in page['Roles']:
                    role_name = role['RoleName']
                    if role_name.startswith(self.resource_prefix):
                        print(f"Found IAM role: {role_name}")
                        return role_name
            return None
        except Exception as e:
            print(f"Error discovering IAM role: {e}")
            return None
    
    def get_import_commands(self) -> List[Tuple[str, str]]:
        """Generate list of terraform import commands."""
        commands = []
        
        # Discover resources
        s3_bucket = self.discover_s3_bucket()
        iam_role = self.discover_iam_role()
        
        if not s3_bucket:
            print("Warning: No S3 bucket found matching the expected prefix")
            return commands
            
        if not iam_role:
            print("Warning: No IAM role found matching the expected prefix")
            return commands
        
        # S3 bucket and related resources
        commands.extend([
            ("aws_s3_bucket.terraform_state", s3_bucket),
            ("aws_s3_bucket_versioning.terraform_state_versioning", s3_bucket),
            ("aws_s3_bucket_server_side_encryption_configuration.terraform_state_encryption", s3_bucket),
            ("aws_s3_bucket_public_access_block.terraform_state_pab", s3_bucket),
            ("aws_s3_bucket_lifecycle_configuration.terraform_state_lifecycle", s3_bucket),
        ])
        
        # IAM role and policy
        commands.extend([
            ("aws_iam_role.terraform_state_role", iam_role),
            ("aws_iam_role_policy.terraform_state_policy", f"{iam_role}:terraform-state-files-policy"),
        ])
        
        return commands
    
    def check_import_needed(self) -> bool:
        """Check if import_existing_resources variable is set to true."""
        try:
            result = subprocess.run(
                ["terraform", "console"],
                input="var.import_existing_resources\n",
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip().lower() == "true"
        except:
            return False
    
    def run_import(self, dry_run: bool = False) -> None:
        """Run the import process."""
        if not self.check_import_needed():
            print("Import not needed: var.import_existing_resources is not set to true")
            return
        
        print(f"Starting import process for workspace: {self.workspace}")
        print(f"Using AWS profile: {self.profile}")
        print(f"Resource prefix: {self.resource_prefix}")
        print()
        
        commands = self.get_import_commands()
        
        if not commands:
            print("No resources found to import")
            return
        
        print(f"Found {len(commands)} resources to import:")
        print()
        
        for resource_address, resource_id in commands:
            command = ["terraform", "import", resource_address, resource_id]
            command_str = " ".join(command)
            
            if dry_run:
                print(f"[DRY RUN] Would run: {command_str}")
            else:
                print(f"Running: {command_str}")
                try:
                    result = subprocess.run(
                        command,
                        capture_output=True,
                        text=True,
                        check=True
                    )
                    print(f"✓ Successfully imported {resource_address}")
                except subprocess.CalledProcessError as e:
                    print(f"✗ Failed to import {resource_address}: {e.stderr}")
                print()


def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description="Import existing AWS resources into Terraform state"
    )
    parser.add_argument(
        "--dry-run", 
        action="store_true", 
        help="Show what would be imported without actually doing it"
    )
    parser.add_argument(
        "--workspace",
        type=str,
        help="Specify the workspace (default: current terraform workspace)"
    )
    parser.add_argument(
        "--profile",
        type=str,
        default="mfa",
        help="AWS profile to use (default: mfa)"
    )
    
    args = parser.parse_args()
    
    try:
        importer = TerraformImporter(
            profile=args.profile,
            workspace=args.workspace
        )
        importer.run_import(dry_run=args.dry_run)
    except KeyboardInterrupt:
        print("\nImport process interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
