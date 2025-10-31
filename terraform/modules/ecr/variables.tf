variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "Image tag mutability setting (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable automatic scanning on image push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type for images (AES256 or KMS)"
  type        = string
  default     = "KMS"
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (required if encryption_type is KMS)"
  type        = string
  default     = ""
}

variable "lifecycle_policy" {
  description = "Lifecycle policy configuration"
  type = object({
    untagged_days = number
    tagged_count  = number
  })
  default = {
    untagged_days = 7
    tagged_count  = 30
  }
}

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = false
}

variable "replication_region" {
  description = "Destination region for replication"
  type        = string
  default     = "us-west-2"
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
