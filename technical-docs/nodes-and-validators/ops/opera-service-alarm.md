# CloudWatch alarm: `vinu-opera.service` failed state

## Purpose

`vinu-opera.service` ships with `Restart=no`. When opera crashes, systemd
leaves the unit in `failed` state indefinitely — there is no auto-restart
loop to observe. Historical incident: on 2026-04-21 at 00:07 UTC the
mainnet RPC opera process died, and the RPC stayed dead for ~57 hours
before anybody noticed the chain tip was two days stale.

This alarm closes that gap. A per-minute probe publishes the systemd
`is-failed` state to CloudWatch, and a CloudWatch alarm pages on the SNS
topic `arn:aws:sns:us-west-2:586704765697:vinuchain-alerts` as soon as the
unit stays `failed` for three consecutive datapoints (3 minutes).

| Box | Instance ID | Environment dimension | Alarm name |
|-----|-------------|-----------------------|------------|
| mainnet RPC | `i-083fffeeb03583a18` | `mainnet` | `mainnet-rpc-vinu-opera-service-failed` |
| testnet RPC | `i-0317eabd98fdf3951` | `testnet` | `testnet-rpc-vinu-opera-service-failed` |

## Moving parts

- `/usr/local/bin/vinu-opera-service-state-probe.sh` — probe script, owner
  `root:root`, mode `0755`. Reads `systemctl is-failed vinu-opera.service`,
  maps `failed` → 1 and everything else → 0, then calls
  `aws cloudwatch put-metric-data`.
- `/etc/cron.d/vinu-opera-service-probe` — root cron, runs every minute
  with `ENV=<mainnet|testnet>` injected per box.
- CloudWatch metric: namespace `VinuChain`, metric `OperaServiceFailed`,
  dimensions `InstanceId` + `Environment`, unit `Count`.
- CloudWatch alarm (one per box): period 60s, statistic `Maximum`,
  threshold `>= 1`, `evaluation-periods 3`, `datapoints-to-alarm 3`,
  `treat-missing-data notBreaching`. Alarm and OK actions both target
  the SNS topic so the alarm auto-resolves when opera comes back.

The probe exits 0 on IMDS or aws-cli transient failure — it never publishes
partial data. Missing datapoints are explicitly treated as notBreaching, so
a single missed minute does not trip the alarm. The `3/3` window needs a
full three minutes of sustained `failed` to page.

## Install on a new box

The probe script and the cron file both live under `/usr/local/bin/` and
`/etc/cron.d/` respectively, which are root-owned. Install via SSM using
`AWS-RunShellScript` (not `VinuChain-RunAsUbuntu`) because the cron drop-in
and the `chown root:root` require root.

**Quoting note.** SSM `commands[]` strings flatten newlines to the literal
two bytes `\n` — heredocs across command-array entries do not work. Use
the base64 pattern below (same one used to install the probe originally):
encode both payloads on the workstation, inline the blobs as single-line
shell variables, and let the remote bash decode them into files. Wrap the
whole install as a single `;`-chained command so `set -eu` works.

```bash
# Workstation:
SCRIPT_B64=$(base64 -w0 vinu-opera-service-state-probe.sh)
CRON_B64=$(printf '%s\n' \
  '# Publishes vinu-opera.service systemd state to CloudWatch every minute' \
  '* * * * * root ENV=__ENV__ /usr/local/bin/vinu-opera-service-state-probe.sh >/dev/null 2>&1' \
  | base64 -w0)
ENV_NAME=mainnet   # or testnet

cat > /tmp/install.json <<JSON
{
  "commands": [
    "set -eu; SCRIPT_B64='${SCRIPT_B64}'; CRON_B64='${CRON_B64}'; ENV_NAME=${ENV_NAME}; echo \"\$SCRIPT_B64\" | base64 -d > /usr/local/bin/vinu-opera-service-state-probe.sh; chown root:root /usr/local/bin/vinu-opera-service-state-probe.sh; chmod 0755 /usr/local/bin/vinu-opera-service-state-probe.sh; echo \"\$CRON_B64\" | base64 -d | sed \"s/__ENV__/\${ENV_NAME}/\" > /etc/cron.d/vinu-opera-service-probe; chown root:root /etc/cron.d/vinu-opera-service-probe; chmod 0644 /etc/cron.d/vinu-opera-service-probe; ENV=\${ENV_NAME} /usr/local/bin/vinu-opera-service-state-probe.sh && echo 'probe exit=0'"
  ]
}
JSON

aws --profile default-root ssm send-command \
  --instance-ids <instance-id> \
  --document-name AWS-RunShellScript \
  --parameters file:///tmp/install.json \
  --region us-west-2
```

The instance profile `VinuChainSSMProfile` already carries
`CloudWatchAgentServerPolicy`, which grants `cloudwatch:PutMetricData`.
No IAM change is required when adding this probe to a new box that already
runs under that profile. Note however that `CloudWatchAgentServerPolicy`
does **not** grant `cloudwatch:GetMetricStatistics`, so any metric
readback from the box itself will fail — always query metrics from a
workstation with broader CloudWatch read permissions.

## Create the alarm

Run from a workstation holding root-equivalent credentials
(`--profile default-root`). The `vinuchain-ops` IAM user is SSM-only and
cannot create CloudWatch alarms.

```bash
aws --profile default-root cloudwatch put-metric-alarm \
  --region us-west-2 \
  --alarm-name mainnet-rpc-vinu-opera-service-failed \
  --alarm-description "vinu-opera.service is in systemd failed state on mainnet RPC for 3+ minutes" \
  --namespace VinuChain \
  --metric-name OperaServiceFailed \
  --dimensions Name=InstanceId,Value=i-083fffeeb03583a18 Name=Environment,Value=mainnet \
  --statistic Maximum \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 3 \
  --datapoints-to-alarm 3 \
  --treat-missing-data notBreaching \
  --alarm-actions arn:aws:sns:us-west-2:586704765697:vinuchain-alerts \
  --ok-actions arn:aws:sns:us-west-2:586704765697:vinuchain-alerts

aws --profile default-root cloudwatch put-metric-alarm \
  --region us-west-2 \
  --alarm-name testnet-rpc-vinu-opera-service-failed \
  --alarm-description "vinu-opera.service is in systemd failed state on testnet RPC for 3+ minutes" \
  --namespace VinuChain \
  --metric-name OperaServiceFailed \
  --dimensions Name=InstanceId,Value=i-0317eabd98fdf3951 Name=Environment,Value=testnet \
  --statistic Maximum \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 3 \
  --datapoints-to-alarm 3 \
  --treat-missing-data notBreaching \
  --alarm-actions arn:aws:sns:us-west-2:586704765697:vinuchain-alerts \
  --ok-actions arn:aws:sns:us-west-2:586704765697:vinuchain-alerts
```

## Test without stopping opera

Do **not** stop `vinu-opera.service` to exercise the alarm path — even a
short outage on the mainnet RPC is user-visible. Instead, create a
throwaway unit that is intentionally failed and point a temporary copy of
the probe at that unit. The real probe only reads `vinu-opera.service`, so
a generic failed unit does **not** raise the live metric — this is by
design. Rewriting the unit name at the top of a copy of the script
exercises the `failed → 1` mapping against a safe target.

Recommended test loop (SSM the box; the verification `aws` call runs on
the workstation because `CloudWatchAgentServerPolicy` on the box does not
include `cloudwatch:GetMetricStatistics`):

```bash
# On the box (SSM AWS-RunShellScript, single command):
set -eu
systemd-run --unit=opera-alarm-probe-test.service /bin/false || true
sleep 2
cp /usr/local/bin/vinu-opera-service-state-probe.sh /tmp/probe-test.sh
sed -i 's/vinu-opera.service/opera-alarm-probe-test.service/' /tmp/probe-test.sh
ENV=testnet bash /tmp/probe-test.sh && echo 'probe-test exit=0'
# cleanup is a second SSM command to avoid set -eu killing it on a failed assert:
systemctl reset-failed opera-alarm-probe-test.service || true
rm -f /tmp/probe-test.sh

# From the workstation (wait ~30 s after the probe-test call for ingestion):
aws --profile default-root cloudwatch get-metric-statistics \
  --region us-west-2 \
  --namespace VinuChain --metric-name OperaServiceFailed \
  --dimensions Name=InstanceId,Value=<iid> Name=Environment,Value=testnet \
  --statistic Maximum --period 60 \
  --start-time "$(date -u -d '-5 min' +%FT%TZ)" \
  --end-time   "$(date -u +%FT%TZ)"
```

Expected: the workstation `get-metric-statistics` call shows a single
`1.0` datapoint for the minute when the probe-test ran, bracketed by
`0.0` datapoints from the real cron. The real cron still watches
`vinu-opera.service` (still active), so it publishes `0` every minute;
the probe-test publishes `1` once to the same dimensions and
`Maximum` over that 60 s period sees both and reports `1.0`. That is
exactly what would happen on a real opera failure during the first
affected minute, so it proves the alarm wiring end-to-end without
stopping opera.

A single `1` datapoint does **not** trip the alarm (3/3 required). The
metric graph will show a one-minute spike; do not panic.

## Resolution logic

- Alarm state is `Maximum >= 1` over 3 consecutive 60-second periods.
- Missing datapoints are notBreaching — a probe that fails to publish for
  one minute (IMDS hiccup, aws-cli transient) does not affect state.
- OK action is wired to the same SNS topic as the alarm action. As soon as
  opera is restarted and the probe publishes a single `0`, the 3/3 window
  resets; the alarm will transition to OK within ~3 minutes of recovery
  and send an OK notification.

## Verification after install

```bash
aws --profile default-root cloudwatch describe-alarms \
  --region us-west-2 \
  --alarm-names mainnet-rpc-vinu-opera-service-failed testnet-rpc-vinu-opera-service-failed \
  --query 'MetricAlarms[].[AlarmName,StateValue]' --output table
```

Expected: both alarms listed, `StateValue` either `OK` or
`INSUFFICIENT_DATA` (transient — flips to `OK` within ~5 minutes of the
probe's first publish).

On each box, confirm the cron is active:

```bash
systemctl list-timers --all | head    # cron.service should be active
grep -r 'vinu-opera-service-state-probe' /etc/cron.d/
grep CRON /var/log/syslog | grep vinu-opera | tail -5
```
