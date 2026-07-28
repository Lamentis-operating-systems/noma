#!/usr/bin/env bash
set -euo pipefail

project_ref="${SUPABASE_PROJECT_REF:-ogajkrmbznzpwjxhaxev}"
endpoint="https://${project_ref}.supabase.co/functions/v1/delete-account"
response_body="$(mktemp)"
trap 'rm -f "$response_body"' EXIT

status="$(
  curl --silent --show-error \
    --output "$response_body" \
    --write-out '%{http_code}' \
    --request POST \
    "$endpoint"
)"

if [[ "$status" != "401" ]]; then
  echo "delete-account deployment check failed: expected authenticated endpoint response 401, got $status" >&2
  sed -n '1,8p' "$response_body" >&2
  exit 1
fi

echo "delete-account is deployed with authentication enforcement in project ${project_ref}."
echo "Boundary: this route probe does not prove an authenticated deletion; the API revokes refresh sessions, while access JWTs remain valid until their exp claim."
echo "Boundary: without authenticated Supabase Management API access, this probe cannot bind the live function version to the repository source."
