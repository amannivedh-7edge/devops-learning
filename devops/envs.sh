#!/bin/bash

# envs.sh — read by data "external" "env" in every module.
# Picks the lab variables out of the environment and prints them as JSON.
vars=$(printenv | awk -F= '/^PARTICIPANT=|^REGION=|^PROFILE=/ {printf "\"%s\":\"%s\",\n", $1, $2}')
vars="${vars%,}" # Remove the trailing comma

cat <<JSON
{
  $vars
}
JSON
