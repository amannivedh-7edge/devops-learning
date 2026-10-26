data "external" "env" {
  program = ["../envs.sh"]
}

terraform {
  backend "s3" {
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region  = data.external.env.result["REGION"]
  profile = data.external.env.result["PROFILE"]

  default_tags {
    tags = {
      project     = "bundle-3-hands-on"
      participant = data.external.env.result["PARTICIPANT"]
      managed_by  = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

# Stores the bucket name from the s3-bucket module. Modules cannot reference
# each other's resources, so the name is rebuilt from the same convention.
resource "aws_ssm_parameter" "bucket_name" {
  name  = "/bundle3/${data.external.env.result["PARTICIPANT"]}/bucket-name"
  type  = "String"
  value = "bundle3-${data.external.env.result["PARTICIPANT"]}-${data.aws_caller_identity.current.account_id}"
}

output "parameter_name" {
  value = aws_ssm_parameter.bucket_name.name
}
