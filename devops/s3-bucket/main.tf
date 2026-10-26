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

# Private S3 bucket. The account ID keeps the name globally unique,
# and other modules rebuild the same name from the same convention.
resource "aws_s3_bucket" "lab" {
  bucket        = "s3-${var.participant}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # lets Step 3 delete the bucket even if you put files in it
}

resource "aws_s3_bucket_public_access_block" "lab" {
  bucket = aws_s3_bucket.lab.id # reference: created after the bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_name" {
  value = aws_s3_bucket.lab.bucket
}
