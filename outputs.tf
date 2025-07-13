output "backend_configuration_hcl" {
  description = "Backend configuration in HCL format for copy-paste into other Terraform configurations"
  value = <<-EOT
terraform {
  backend "s3" {
    bucket        = "${aws_s3_bucket.terraform_state.id}"
    key           = "CHANGE_ME/terraform.tfstate"
    region        = "${data.aws_region.current.name}"
    role_arn      = "${aws_iam_role.terraform_state_role.arn}"
    encrypt       = true
    use_lockfile  = true
  }
}
EOT
}
