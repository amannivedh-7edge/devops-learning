#!/bin/bash
# Bundle 3 hands-on — same pattern as easyid-admin-backend-apis/devops/terraform_run.sh:
# every module folder under devops/ has a partial "s3" backend, and init fills in
# bucket / key / profile / region. Each module gets its own state file.
#
# Usage:
#   ./terraform_run.sh plan    [module]   # show what would change
#   ./terraform_run.sh apply   [module]   # plan to a file, then apply exactly that file
#   ./terraform_run.sh destroy [module]   # plan a destroy, then apply it
# Leave out [module] to run every module in the list below.
#
# Required environment variables:
#   PARTICIPANT   your name, lowercase, no spaces (e.g. aman)
#   STATE_BUCKET  the shared state bucket the trainer gives you
# Optional:
#   PROFILE       AWS CLI profile (default: default)
#   REGION        AWS region      (default: us-east-1)

action=${1:-plan}
only_module=${2:-}

case "$action" in
    plan | apply | destroy) ;;
    *)
        echo "Unknown action: $action (use plan, apply or destroy)"
        exit 1
        ;;
esac

if [ -n "$only_module" ] && [ ! -d "$(dirname "$0")/devops/$only_module" ]; then
    echo "No module folder devops/$only_module"
    exit 1
fi

: "${PARTICIPANT:?Set PARTICIPANT, e.g. export PARTICIPANT=aman}"
: "${STATE_BUCKET:?Set STATE_BUCKET to the bucket name the trainer shared}"
if ! [[ "$PARTICIPANT" =~ ^[a-z0-9-]{2,20}$ ]]; then
    echo "PARTICIPANT must be 2-20 characters: lowercase letters, digits or hyphens."
    exit 1
fi

# envs.sh passes these to the modules through data "external" "env"
export PROFILE=${PROFILE:-default}
export REGION=${REGION:-us-east-1}

overall_status=0
run_command() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        overall_status=$status
        echo "Command failed: $*"
    fi
    return $status
}

cd "$(dirname "$0")" || exit 1

aws sts get-caller-identity --profile "$PROFILE" || exit 1

terraform_init() {
    local module=$1

    # -reconfigure so switching PARTICIPANT or bucket never prompts to migrate state
    run_command terraform -chdir=devops/$module init -reconfigure \
        -backend-config="bucket=${STATE_BUCKET}" \
        -backend-config="key=training/bundle-3/${PARTICIPANT}/${module}/terraform.tfstate" \
        -backend-config="profile=${PROFILE}" \
        -backend-config="region=${REGION}"
}

terraform_module() {
    local module=$1

    echo
    echo "==================== $action: $module ===================="
    terraform_init "$module" || return

    case "$action" in
        plan)
            run_command terraform -chdir=devops/$module plan
            ;;
        apply)
            run_command terraform -chdir=devops/$module plan -out=tfplan &&
                run_command terraform -chdir=devops/$module apply tfplan
            ;;
        destroy)
            run_command terraform -chdir=devops/$module plan -destroy -out=tfplan &&
                run_command terraform -chdir=devops/$module apply tfplan
            ;;
    esac
    rm -f devops/$module/tfplan
}

modules=(
    "s3-bucket"
    "ssm-parameter"
    "ec2-instance"
)

if [ -n "$only_module" ]; then
    terraform_module "$only_module"
elif [ "$action" == "destroy" ]; then
    # Destroy in reverse order — last created, first removed
    for ((i = ${#modules[@]} - 1; i >= 0; i--)); do
        terraform_module "${modules[$i]}"
    done
else
    for module in "${modules[@]}"; do
        terraform_module "$module"
    done
fi

exit $overall_status
