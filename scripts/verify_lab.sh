#!/usr/bin/env bash
set -euo pipefail

# verify_lab.sh
# Smoke test and security baseline check for the AWS Cybersecurity Homelab.
# Verifies core resources exist and key security controls are in place.
#
# Requirements:
#   - AWS CLI configured with the same profile/region used by Terraform
#   - Terraform state available in ./terraform

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}">)/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

PASS=0
FAIL=0

_pass() { echo "[PASS] $*"; PASS=$(( PASS + 1 )); }
_fail() { echo "[FAIL] $*"; FAIL=$(( FAIL + 1 )); }
_info() { echo "[INFO] $*"; }
_warn() { echo "[WARN] $*"; }

echo "[INFO] Cybersecurity homelab smoke test starting..."
echo "=========================================="

# ── Tool checks ───────────────────────────────────────────────────────────────
if ! command -v aws &>/dev/null; then
  echo "[ERROR] aws CLI not found in PATH."
  exit 1
fi
if ! command -v terraform &>/dev/null; then
  echo "[ERROR] terraform not found in PATH."
  exit 1
fi

# ── Terraform outputs ─────────────────────────────────────────────────────────
cd "${TF_DIR}"
_info "Reading Terraform outputs..."
KALI_ID="$(terraform output -raw kali_instance_id)"
WIN_ID="$(terraform output -raw windows_instance_id)"
TOOLS_ID="$(terraform output -raw tools_instance_id)"

VPC_ID="$(aws ec2 describe-instances \
  --instance-ids "${KALI_ID}" \
  --query 'Reservations[0].Instances[0].VpcId' \
  --output text)"

# ── EC2 instance state ────────────────────────────────────────────────────────
echo ""
_info "Checking EC2 instance states..."
STATES=$(aws ec2 describe-instances \
  --instance-ids "${KALI_ID}" "${WIN_ID}" "${TOOLS_ID}" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output text)

while read -r id state; do
  if [ "$state" = "running" ]; then
    _pass "Instance ${id}: ${state}"
  else
    _fail "Instance ${id}: ${state} (expected: running)"
  fi
done < <(echo "$STATES")

# ── VPC Flow Logs ─────────────────────────────────────────────────────────────
echo ""
_info "Checking VPC Flow Logs for VPC ${VPC_ID}..."
FLOW_STATUS="$(aws ec2 describe-flow-logs \
  --filter "Name=resource-id,Values=${VPC_ID}" \
  --query 'FlowLogs[].FlowLogStatus' \
  --output text || true)"

if [ -z "$FLOW_STATUS" ]; then
  _fail "No VPC Flow Logs found for ${VPC_ID}"
elif echo "$FLOW_STATUS" | grep -q "ACTIVE"; then
  _pass "VPC Flow Logs: ACTIVE"
else
  _fail "VPC Flow Logs found but status is: ${FLOW_STATUS}"
fi

# ── IAM instance profile ──────────────────────────────────────────────────────
echo ""
_info "Checking IAM instance profile on tools instance..."
TOOLS_PROFILE="$(aws ec2 describe-instances \
  --instance-ids "${TOOLS_ID}" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
  --output text || true)"

if [[ "${TOOLS_PROFILE}" == "None" || -z "${TOOLS_PROFILE}" ]]; then
  _fail "Tools instance has no IAM instance profile attached"
else
  _pass "Tools instance IAM profile: ${TOOLS_PROFILE}"
fi

# ── Security groups: check for dangerously open inbound rules ─────────────────
echo ""
_info "Checking security groups for overly permissive inbound rules..."

# Collect SG IDs for all three instances
ALL_SGS=$(aws ec2 describe-instances \
  --instance-ids "${KALI_ID}" "${WIN_ID}" "${TOOLS_ID}" \
  --query 'Reservations[].Instances[].SecurityGroups[].GroupId' \
  --output text | tr '\t' '\n' | sort -u)

DANGEROUS_PORTS=(22 3389 8834 8000 9997)
OPEN_RULES_FOUND=0

for SG_ID in $ALL_SGS; do
  for PORT in "${DANGEROUS_PORTS[@]}"; do
    # Check for 0.0.0.0/0 or ::/0 on sensitive ports
    OPEN=$(aws ec2 describe-security-groups \
      --group-ids "$SG_ID" \
      --query "SecurityGroups[0].IpPermissions[?
        (FromPort<=${PORT} && ToPort>=${PORT}) &&
        (IpRanges[?CidrIp=='0.0.0.0/0'] || Ipv6Ranges[?CidrIpv6=='::/0'])
      ].FromPort" \
      --output text 2>/dev/null || true)

    if [ -n "$OPEN" ] && [ "$OPEN" != "None" ]; then
      _fail "SG ${SG_ID}: port ${PORT} is open to 0.0.0.0/0 (world)"
      OPEN_RULES_FOUND=1
    fi
  done
done

if [ $OPEN_RULES_FOUND -eq 0 ]; then
  _pass "No sensitive ports open to 0.0.0.0/0 on checked security groups"
fi

# ── CloudTrail ────────────────────────────────────────────────────────────────
echo ""
_info "Checking CloudTrail..."
CT_STATUS=$(aws cloudtrail describe-trails \
  --query 'trailList[?HomeRegion==`'"$(aws configure get region || echo us-east-1)"'`].TrailARN' \
  --output text 2>/dev/null || true)

if [ -z "$CT_STATUS" ]; then
  _fail "No CloudTrail trail found in this region"
else
  # Check at least one trail is logging
  CT_LOGGING=$(aws cloudtrail get-trail-status \
    --name "$(echo "$CT_STATUS" | head -1)" \
    --query 'IsLogging' \
    --output text 2>/dev/null || true)

  if [ "$CT_LOGGING" = "True" ]; then
    _pass "CloudTrail is active and logging"
  else
    _fail "CloudTrail trail exists but IsLogging=False"
  fi
fi

# ── S3 bucket encryption ──────────────────────────────────────────────────────
echo ""
_info "Checking S3 bucket default encryption..."

# Get any S3 buckets referenced in Terraform outputs (best-effort)
S3_BUCKET=""
S3_BUCKET=$(terraform output -raw logs_bucket_name 2>/dev/null || true)

if [ -n "$S3_BUCKET" ] && [ "$S3_BUCKET" != "null" ]; then
  ENC=$(aws s3api get-bucket-encryption \
    --bucket "$S3_BUCKET" \
    --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
    --output text 2>/dev/null || true)

  if [ -z "$ENC" ] || [ "$ENC" = "None" ]; then
    _fail "S3 bucket '${S3_BUCKET}' does not have default encryption enabled"
  else
    _pass "S3 bucket '${S3_BUCKET}' encryption: ${ENC}"
  fi
else
  _warn "No 'logs_bucket_name' Terraform output found; skipping S3 encryption check"
fi

# ── IMDSv2 enforcement ────────────────────────────────────────────────────────
# Confirms http_tokens=required survived launch and was not overridden.
# IMDSv2 prevents SSRF attacks from reaching the instance metadata endpoint.
echo ""
_info "Checking IMDSv2 enforcement (HttpTokens=required)..."
for INST_ID in "$KALI_ID" "$WIN_ID" "$TOOLS_ID"; do
  TOKEN_STATE=$(aws ec2 describe-instances \
    --instance-ids "$INST_ID" \
    --query 'Reservations[0].Instances[0].MetadataOptions.HttpTokens' \
    --output text 2>/dev/null || true)
  if [ "$TOKEN_STATE" = "required" ]; then
    _pass "Instance ${INST_ID}: IMDSv2 enforced (HttpTokens=required)"
  else
    _fail "Instance ${INST_ID}: IMDSv2 not enforced (HttpTokens=${TOKEN_STATE})"
  fi
done

# ── EBS root volume encryption ────────────────────────────────────────────────
# Confirms each root volume is encrypted — an unencrypted root volume leaks
# credentials and keys if the volume is snapshotted or detached.
echo ""
_info "Checking EBS root volume encryption..."
for INST_ID in "$KALI_ID" "$WIN_ID" "$TOOLS_ID"; do
  VOL_ID=$(aws ec2 describe-instances \
    --instance-ids "$INST_ID" \
    --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' \
    --output text 2>/dev/null || true)

  if [ -z "$VOL_ID" ] || [ "$VOL_ID" = "None" ]; then
    _warn "Instance ${INST_ID}: unable to determine root EBS volume ID"
    continue
  fi

  VOL_ENC=$(aws ec2 describe-volumes \
    --volume-ids "$VOL_ID" \
    --query 'Volumes[0].Encrypted' \
    --output text 2>/dev/null || true)

  if [ "$VOL_ENC" = "True" ]; then
    _pass "Instance ${INST_ID}: root EBS volume ${VOL_ID} is encrypted"
  else
    _fail "Instance ${INST_ID}: root EBS volume ${VOL_ID} is NOT encrypted"
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
TOTAL=$(( PASS + FAIL ))
echo "Results: ${PASS}/${TOTAL} checks passed"
if [ $FAIL -eq 0 ]; then
  echo "[SUCCESS] All checks passed. Lab core resources and security controls are in place."
else
  echo "[WARN] ${FAIL} check(s) failed. Review the [FAIL] lines above."
fi
echo "=========================================="

# Exit non-zero if any check failed (useful for CI/CD pipelines)
[ $FAIL -eq 0 ]
