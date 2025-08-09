output "backend_configuration_hcl_parameter_name" {
  description = "The name of the SSM parameter storing the backend configuration HCL."
  value       = aws_ssm_parameter.backend_configuration_hcl.name
}

output "backend_configuration_hcl" {
  description = "Backend configuration in HCL format for copy-paste into other Terraform configurations"
  value       = aws_ssm_parameter.backend_configuration_hcl.value
  sensitive   = true
}
