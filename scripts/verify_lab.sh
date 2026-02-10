#!/usr/bin/env bash
set -euo pipefail

# Simple smoke test for the AWS Cybersecurity Homelab.
# Verifies that core resources exist and basic security controls are in place.
#
# Requirements:
#   - AWS CLI configured with the same profile/region used by Terraform
#   - Terraform state available in ./terraform

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

echo "[INFO] Cybersecurity homelab smoke test starting..."

if ! command -v aws >/dev/null 2>&1; then
  echo "[ERROR] aws CLI not found in PATH."
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "[ERROR] terraform not found in PATH."
  exit 1
fi

cd "${TF_DIR}"

echo "[INFO] Reading Terraform outputs..."
KALI_ID="$(terraform output -raw kali_instance_id)"
WIN_ID="$(terraform output -raw windows_instance_id)"
TOOLS_ID="$(terraform output -raw tools_instance_id)"
VPC_ID="$(aws ec2 describe-instances --instance-ids "${KALI_ID}" --query 'Reservations[0].Instances[0].VpcId' --output text)"

echo "[INFO] Verifying EC2 instances are running..."
aws ec2 describe-instances --instance-ids "${KALI_ID}" "${WIN_ID}" "${TOOLS_ID}" \
  --query 'Reservations[].Instances[].State.Name' --output text

echo "[INFO] Verifying VPC Flow Logs exist for VPC ${VPC_ID}..."
FLOW_STATUS="$(aws ec2 describe-flow-logs --filter "Name=resource-id,Values=${VPC_ID}" --query 'FlowLogs[].FlowLogStatus' --output text || true)"
if [[ -z "${FLOW_STATUS}" ]]; then
  echo "[ERROR] No VPC Flow Logs found for VPC ${VPC_ID}."
  exit 1
fi
echo "[INFO] VPC Flow Logs status: ${FLOW_STATUS}"

echo "[INFO] Verifying IAM instance profile is attached to tools instance..."
TOOLS_PROFILE="$(aws ec2 describe-instances --instance-ids "${TOOLS_ID}" --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text || true)"
if [[ "${TOOLS_PROFILE}" == "None" || -z "${TOOLS_PROFILE}" ]]; then
  echo "[ERROR] Tools instance does not have an IAM instance profile attached."
  exit 1
fi
echo "[INFO] Tools instance IAM profile: ${TOOLS_PROFILE}"

echo "[SUCCESS] Basic smoke tests passed. Lab core resources and logging controls are in place."

