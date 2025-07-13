locals {
  allowed_workspaces = ["dev", "stg", "prod"]
  workspace_valid    = contains(local.allowed_workspaces, terraform.workspace)
}

resource "null_resource" "workspace_guard" {
  count = local.workspace_valid ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'ERROR: Invalid workspace. Allowed: dev, stg, prod.' && exit 1"
  }
}
