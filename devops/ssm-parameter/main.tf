terraform {
  backend "s3" {
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      project     = "bundle-3-hands-on"
      participant = var.participant
      managed_by  = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

# Stores the bucket name from the s3-bucket module. Modules cannot reference
# each other's resources, so the name is rebuilt from the same convention.
resource "aws_ssm_parameter" "bucket_name" {
  name  = "/bundle3/${var.participant}/bucket-name"
  type  = "String"
  value = "bundle3-${var.participant}-${data.aws_caller_identity.current.account_id}"
}

output "parameter_name" {
  value = aws_ssm_parameter.bucket_name.name
}
