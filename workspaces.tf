resource "null_resource" "workspace_guard" {
  count = local.workspace_valid ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'ERROR: Invalid workspace. Allowed: dev, stg, prod.' && exit 1"
  }
}
