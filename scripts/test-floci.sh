#!/usr/bin/env bash
# Start Floci, apply examples/floci-aws, then destroy. Mirrors the CI floci-apply job.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE="${ROOT}/examples/floci-aws"

# Pin by digest (floci/floci:2.4.0). Update digest when bumping the release.
FLOCI_IMAGE="${FLOCI_IMAGE:-floci/floci:2.4.0@sha256:5ee85db604c4aa74ac76e07ea5cc83086f37bb472bf3dbb97e34019e48efae9c}"
FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-http://localhost:4566}"
CONTAINER_NAME="${FLOCI_CONTAINER_NAME:-platform-templates-floci}"
TF_BIN="${TF_BIN:-terraform}"

cleanup() {
  local ec=$?
  if docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  fi
  exit "${ec}"
}
trap cleanup EXIT

command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
command -v "${TF_BIN}" >/dev/null || { echo "terraform is required" >&2; exit 1; }

if curl -sf "${FLOCI_ENDPOINT}/_localstack/health" >/dev/null 2>&1 \
  || curl -sf "${FLOCI_ENDPOINT}/_floci/health" >/dev/null 2>&1; then
  echo "Floci already appears to be listening on ${FLOCI_ENDPOINT}; refusing to clobber it." >&2
  echo "Stop it, or set FLOCI_ENDPOINT to a free instance." >&2
  exit 1
fi

echo "==> Starting Floci (${FLOCI_IMAGE})"
docker pull "${FLOCI_IMAGE}"
docker run -d --rm \
  --name "${CONTAINER_NAME}" \
  -p 4566:4566 \
  "${FLOCI_IMAGE}"

echo "==> Waiting for Floci health"
ready=0
for _ in $(seq 1 60); do
  if curl -sf "${FLOCI_ENDPOINT}/_localstack/health" >/dev/null 2>&1 \
    || curl -sf "${FLOCI_ENDPOINT}/_floci/health" >/dev/null 2>&1 \
    || curl -sf "${FLOCI_ENDPOINT}" >/dev/null 2>&1; then
    # Prefer a real AWS call once the process accepts TCP.
    if AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
      aws --endpoint-url "${FLOCI_ENDPOINT}" sts get-caller-identity >/dev/null 2>&1; then
      ready=1
      break
    fi
  fi
  sleep 2
done
if [[ "${ready}" -ne 1 ]]; then
  echo "Floci did not become healthy in time" >&2
  docker logs "${CONTAINER_NAME}" >&2 || true
  exit 1
fi

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL="${FLOCI_ENDPOINT}"

echo "==> Terraform init / apply / destroy (${EXAMPLE})"
cd "${EXAMPLE}"
"${TF_BIN}" init -input=false
"${TF_BIN}" apply -auto-approve -input=false -var="floci_endpoint=${FLOCI_ENDPOINT}"

ROLE_NAME="$("${TF_BIN}" output -raw iam_role_name)"
POLICY="$("${TF_BIN}" output -raw assume_role_policy)"
SECRET_ID="$("${TF_BIN}" output -raw secret_id)"

echo "${POLICY}" | grep -q 'sts:AssumeRoleWithWebIdentity'
echo "${POLICY}" | grep -q "system:serviceaccount:checkout:checkout-gateway"
echo "${POLICY}" | grep -q 'sts.amazonaws.com'
[[ "${ROLE_NAME}" == "checkout-gateway" ]]

aws --endpoint-url "${FLOCI_ENDPOINT}" iam get-role --role-name "${ROLE_NAME}" >/dev/null
aws --endpoint-url "${FLOCI_ENDPOINT}" secretsmanager get-secret-value --secret-id "${SECRET_ID}" \
  --query SecretString --output text | grep -q EXAMPLE_KEY

"${TF_BIN}" destroy -auto-approve -input=false -var="floci_endpoint=${FLOCI_ENDPOINT}"

echo "==> Floci apply test passed"
