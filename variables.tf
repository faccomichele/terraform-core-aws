variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-core"
}

variable "repository_url" {
  description = "URL of the Git repository"
  type        = string
  default     = "https://github.com/faccomichele/terraform-core"
  validation {
    condition     = can(regex("^https://.*${var.project_name}.*", var.repository_url))
    error_message = "The repository_url must start with 'https://' and contain the project name ('${var.project_name}')."
  }
}

variable "import_existing_resources" {
  description = "Whether to import existing AWS resources instead of creating new ones"
  type        = bool
  default     = false
}
