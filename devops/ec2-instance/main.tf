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

# Latest Amazon Linux 2023 AMI — looked up, never created.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# ---------------------------------------------------------------------------
# STEP 2: comment out the resource AND the output below, then run
#   ./terraform_run.sh plan ec2-instance
# Terraform should want to destroy exactly 1 thing.
# ---------------------------------------------------------------------------

resource "aws_instance" "lab" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  tags = {
    Name = "bundle3-${data.external.env.result["PARTICIPANT"]}"
  }
}

output "instance_id" {
  value = aws_instance.lab.id
}
