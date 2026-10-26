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
# The script asks for your name, the state bucket and your AWS profile when it starts.
# Values already set in the shell (PARTICIPANT, STATE_BUCKET, PROFILE, REGION) are used
# without asking. REGION defaults to us-east-1.

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

# Ask once per run (skipped if the value is already set in the shell)
if [ -z "${PARTICIPANT:-}" ]; then
    read -rp "Your name (lowercase, no spaces, e.g. aman): " PARTICIPANT
fi
if ! [[ "$PARTICIPANT" =~ ^[a-z0-9-]{2,20}$ ]]; then
    echo "Name must be 2-20 characters: lowercase letters, digits or hyphens."
    exit 1
fi
if [ -z "${STATE_BUCKET:-}" ]; then
    read -rp "State bucket (from the trainer): " STATE_BUCKET
fi
if [ -z "$STATE_BUCKET" ]; then
    echo "State bucket is required."
    exit 1
fi
if [ -z "${PROFILE:-}" ]; then
    read -rp "AWS profile [default]: " PROFILE
fi

PROFILE=${PROFILE:-default}
REGION=${REGION:-us-east-1}

# Values for each module's variables.tf
tf_vars=(-var="participant=${PARTICIPANT}" -var="region=${REGION}" -var="profile=${PROFILE}")

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
            run_command terraform -chdir=devops/$module plan "${tf_vars[@]}"
            ;;
        apply)
            run_command terraform -chdir=devops/$module plan "${tf_vars[@]}" -out=tfplan &&
                run_command terraform -chdir=devops/$module apply tfplan
            ;;
        destroy)
            run_command terraform -chdir=devops/$module plan -destroy "${tf_vars[@]}" -out=tfplan &&
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
