resource "aws_ssm_parameter" "backend_configuration_hcl" {
	name        = "/terraform-core/backend_configuration_hcl"
	description = "Backend configuration in HCL format for copy-paste into other Terraform configurations"
	type        = "SecureString"
	value       = <<-EOT
terraform {
	backend "s3" {
		bucket        = "${aws_s3_bucket.terraform_state.id}"
		key           = "CHANGE_ME/terraform.tfstate"
		region        = "${data.aws_region.current.name}"
    assume_role = {
		  role_arn      = "${aws_iam_role.terraform_state_role.arn}"
		}
    encrypt       = true
		use_lockfile  = true
	}
}
EOT
	overwrite   = true
  tags = merge(
    local.tags,
    {
      RepositoryFile = "ssm.tf"
      Name           = "/terraform-core/backend_configuration_hcl"
      Description    = "Backend configuration in HCL format for copy-paste into other Terraform configurations"
    }
  )
}
