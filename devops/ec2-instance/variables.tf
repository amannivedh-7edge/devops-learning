variable "participant" {
  description = "Your name, lowercase, no spaces (e.g. aman). Keeps your resources apart from everyone else's."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.participant))
    error_message = "participant must be 2-20 characters: lowercase letters, digits or hyphens."
  }
}

variable "region" {
  description = "AWS region to create the lab resources in"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}
