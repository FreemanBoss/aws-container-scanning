variable "enable_inspector" {
  description = "Enable Amazon Inspector v2"
  type        = bool
  default     = true
}

variable "resource_types" {
  description = "Resource types to enable for scanning"
  type        = list(string)
  default     = ["ECR"]
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
