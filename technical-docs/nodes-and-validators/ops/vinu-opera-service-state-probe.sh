#!/bin/bash
# vinu-opera-service-state-probe.sh
#
# Publishes the systemd state of vinu-opera.service to CloudWatch as a 0/1
# metric (namespace VinuChain, metric OperaServiceFailed). Value is 1 iff the
# unit is in state "failed" at the time of sampling, 0 otherwise (active,
# activating, inactive, deactivating, unknown).
#
# Expected to be invoked from cron every minute. Stays silent on success and
# swallows transient IMDS / aws-cli failures — the alarm is configured with
# treat-missing-data=notBreaching and a 3/3 datapoints window, so a single
# missed publish does not page.
#
# Required environment: ENV (mainnet|testnet).

set -eu

if [ -z "${ENV:-}" ]; then
  echo "vinu-opera-service-state-probe: ENV is unset" >&2
  exit 1
fi

STATE=$(systemctl is-failed vinu-opera.service 2>/dev/null || true)
if [ "$STATE" = "failed" ]; then
  VAL=1
else
  VAL=0
fi

TOKEN=$(curl -sf -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60" \
  http://169.254.169.254/latest/api/token 2>/dev/null || true)
if [ -z "$TOKEN" ]; then
  exit 0
fi

IID=$(curl -sf \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || true)
if [ -z "$IID" ]; then
  exit 0
fi

aws cloudwatch put-metric-data \
  --namespace VinuChain \
  --metric-name OperaServiceFailed \
  --dimensions InstanceId="$IID",Environment="$ENV" \
  --value "$VAL" \
  --unit Count \
  --region us-west-2 >/dev/null 2>&1 || true
