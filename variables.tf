variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-core-aws"
}

variable "organization" {
  description = "Name of the organization"
  type        = string
  default     = "faccomichele"
}

variable "import_existing_resources" {
  description = "Whether to import existing AWS resources instead of creating new ones"
  type        = bool
  default     = false
}
