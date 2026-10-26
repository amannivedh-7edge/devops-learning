# Bundle 3 — Terraform hands-on

**Time:** about 20 minutes. **Work:** on your own or in pairs.

You will build a few small AWS resources with Terraform, remove one of them, and then delete everything. The folder is laid out like `easyid-admin-backend-apis/devops`: one folder per module, each with its own state file in S3 and its own lock, all run by `terraform_run.sh`.

| Step | What you do | What the plans should say |
|---|---|---|
| 1 | Create everything | s3-bucket `2 to add`, ssm-parameter `1 to add`, ec2-instance `1 to add` |
| 2 | Remove only the EC2 instance by commenting it out | ec2-instance `1 to destroy`, the others `No changes` |
| 3 | Delete everything | ec2-instance nothing left, ssm-parameter `1 to destroy`, s3-bucket `2 to destroy` |

---

## What is in this folder

```
devops-learning/
  instructions.md
  terraform_run.sh            init each module with -backend-config, then plan / apply / destroy
  devops/
    envs.sh                   hands PARTICIPANT, REGION, PROFILE to Terraform as JSON
    s3-bucket/main.tf         private S3 bucket + public access block
    ssm-parameter/main.tf     SSM parameter that stores the bucket name
    ec2-instance/main.tf      t3.micro EC2 instance            <- Step 2 happens here
```

Every `main.tf` starts the same way as the modules in admin-backend:

```hcl
data "external" "env" {
  program = ["../envs.sh"]          # reads PARTICIPANT, REGION, PROFILE from your shell
}

terraform {
  backend "s3" {                    # no bucket, no key — terraform_run.sh adds them
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

And `terraform_run.sh` loops over the modules exactly like the pipeline does:

```bash
terraform -chdir=devops/$module init -reconfigure \
    -backend-config="bucket=${STATE_BUCKET}" \
    -backend-config="key=training/bundle-3/${PARTICIPANT}/${module}/terraform.tfstate" \
    -backend-config="profile=${PROFILE}" \
    -backend-config="region=${REGION}"
```

Each participant and each module gets its own `key`, so there are **three state files per person**, and nobody touches anyone else's.

---

## Before you start

You need Terraform 1.10 or newer (`terraform version`), the AWS CLI, and an AWS profile for the training account.

Set these in your terminal. Use your own name in lowercase with no spaces. The trainer will give you the bucket name.

```bash
cd ~/learning/devops-learning

export PARTICIPANT=yourname
export STATE_BUCKET=<bucket-from-trainer>
export PROFILE=<training-profile>       # optional, defaults to "default"
```

Check that you are in the right account:

```bash
aws sts get-caller-identity --profile $PROFILE
```

The script can run every module, or just one:

```bash
./terraform_run.sh plan                    # all modules, in order
./terraform_run.sh plan ec2-instance       # only devops/ec2-instance
```

---

## Step 1 — Create the resources

**1. Plan first.**

```bash
./terraform_run.sh plan
```

There is one plan per module, one after the other. Read each from the bottom up:
- **s3-bucket:** `Plan: 2 to add`. These are `aws_s3_bucket.lab` and `aws_s3_bucket_public_access_block.lab`.
- **ssm-parameter:** `Plan: 1 to add`. This is `aws_ssm_parameter.bucket_name`.
- **ec2-instance:** `Plan: 1 to add`. This is `aws_instance.lab`.

Look at the bucket name in the s3-bucket plan, then at the parameter value in the ssm-parameter plan. They match, but the two modules never reference each other. How?

**2. Apply.**

```bash
./terraform_run.sh apply
```

For each module, the script saves the plan to a file and applies exactly that file. Watch the `==== apply: <module> ====` headers go by.

**3. Check it worked.**

```bash
terraform -chdir=devops/s3-bucket state list       # 2 resources (+ data sources)
terraform -chdir=devops/ec2-instance output        # instance_id
aws ssm get-parameter --name /bundle3/$PARTICIPANT/bucket-name \
    --query Parameter.Value --profile $PROFILE
```

In the S3 console, open the state bucket and go to `training/bundle-3/<yourname>/`. There is one folder per module, each with its own `terraform.tfstate`.

> **Checkpoint:** run `./terraform_run.sh plan` again. Every module should say **No changes**.

---

## Step 2 — Remove one resource (the EC2 instance)

There is no "delete" command for a single resource. You remove it from the code, and Terraform works out that it must be destroyed. This is the same thing you will see in admin-backend's `devops/ecr-new/main.tf`, where a repository is commented out.

**1. Open `devops/ec2-instance/main.tf`** and comment out the `resource "aws_instance" "lab"` block **and** the `output "instance_id"` block. In VS Code, select them and press `Ctrl + /`. Leave the `data`, `terraform` and `provider` blocks alone.

The output has to go too. If you leave it in, Terraform fails with `Reference to undeclared resource`, which is one of the errors from the slides.

**2. Plan only that module.**

```bash
./terraform_run.sh plan ec2-instance
```

Expected: `Plan: 0 to add, 0 to change, 1 to destroy.`
- Is the resource being destroyed `aws_instance.lab`, and nothing else?
- Why can this plan never touch the bucket, whatever you do in this folder? Hint: think about the state file it reads.

**3. Apply, then check the whole project.**

```bash
./terraform_run.sh apply ec2-instance
./terraform_run.sh plan                   # s3-bucket and ssm-parameter: No changes
```

> **Think about it:** what if, instead of commenting out the resource, you deleted `"ec2-instance"` from the `modules=( ... )` list in `terraform_run.sh`? Try a plan and see. The instance stays running. The script would just stop looking at it, and that is how forgotten resources happen.

> **Optional, to see locking:** open a second terminal, export the same `PARTICIPANT` and `STATE_BUCKET`, and run `./terraform_run.sh apply s3-bucket` in both terminals at the same moment. One of them stops with `Error acquiring the state lock`. While the first run is going, look in the state bucket for `s3-bucket/terraform.tfstate.tflock`.

---

## Step 3 — Delete everything

```bash
./terraform_run.sh destroy
```

The script destroys the modules in **reverse order**: the last one created is the first removed.
- **ec2-instance:** `No changes. No objects need to be destroyed.` You already removed it in Step 2.
- **ssm-parameter:** `Plan: 0 to add, 0 to change, 1 to destroy.`
- **s3-bucket:** `Plan: 0 to add, 0 to change, 2 to destroy.`

Check that it is all gone:

```bash
for m in s3-bucket ssm-parameter ec2-instance; do terraform -chdir=devops/$m state list; done   # no resources
aws s3 ls --profile $PROFILE | grep bundle3-$PARTICIPANT                                         # nothing
```

The state files still exist in S3, but they are now empty: Terraform owns nothing. Uncomment `ec2-instance/main.tf` again so the folder is clean for the next person.

---

## If something goes wrong

| You see | What it means | What to do |
|---|---|---|
| `Set PARTICIPANT ...` / `Set STATE_BUCKET ...` | An environment variable is missing | Run the `export` lines again in this terminal |
| `PARTICIPANT must be 2-20 characters` | Your name has capitals, spaces or symbols | Use lowercase letters, digits or `-` only |
| `Invalid index` on `data.external.env.result["..."]` | `envs.sh` did not see a variable | Run through `./terraform_run.sh`, not plain `terraform plan`. The script exports `PROFILE` and `REGION` for you |
| `permission denied: ../envs.sh` | The script lost its execute bit | `chmod +x devops/envs.sh` |
| `Error acquiring the state lock` | Another run is using that module's state, maybe your second terminal | Wait for it to finish. Tell the trainer if it does not clear |
| `Reference to undeclared resource "aws_instance" "lab"` | You commented out the instance but not the output | Comment out `output "instance_id"` as well |
| `No valid credential sources found` / `ExpiredToken` | The AWS profile is wrong or has expired | Check `PROFILE`, then log in again |
| `BucketAlreadyOwnedByYou` / `BucketAlreadyExists` | A bucket with your name is still there from an earlier run | Ask the trainer. It needs a `terraform import` or a manual delete |
| `VPCIdNotSpecified` / `No default VPC` | The region has no default VPC | Tell the trainer |

**Before you leave:** make sure Step 3 is done. A forgotten EC2 instance keeps costing money.

---

## Trainer setup (do this once before the session)

Create the shared state bucket in the training account with versioning on. Choose a globally unique name:

```bash
aws s3api create-bucket --bucket <state-bucket> --region us-east-1
aws s3api put-bucket-versioning --bucket <state-bucket> \
    --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket <state-bucket> \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Participants need permissions for S3 (their own bucket plus the state bucket), EC2 (`RunInstances`, `TerminateInstances`, `Describe*`), SSM parameters under `/bundle3/*`, and `sts:GetCallerIdentity`. The region also needs a default VPC.

After the session, check for leftovers:

```bash
aws ec2 describe-instances --filters Name=tag:project,Values=bundle-3-hands-on \
    Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId'
aws s3 ls | grep bundle3-
```
