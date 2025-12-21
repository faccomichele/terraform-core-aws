locals {
  repository_url      = "https://github.com/${var.organization}/${var.project_name}"
  tags                = {
    Project           = var.project_name
    Organization      = var.organization
    Environment       = terraform.workspace
    RepositoryURL     = local.repository_url
    Automation        = "Terraform"
    RepositoryPath    = "."
  }
  allowed_workspaces  = ["dev", "stg", "prod"]
  workspace_valid     = contains(local.allowed_workspaces, terraform.workspace)
}
