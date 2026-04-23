# systemd-journald disk cap

## Purpose

On 2026-04-23 the mainnet RPC box (`i-083fffeeb03583a18`) went into a disk-low
loop that was eventually traced to `/var/log/syslog` growing to 13 GiB over 17
days. That specific file is written by **rsyslog**, not systemd-journald — a
logrotate fix for it is tracked as a separate follow-up. Independently of that,
the box's **systemd-journald** binary journal was uncapped, meaning journald
could also grow without bound and contribute to future disk pressure. To
prevent a journald-only repeat of the same failure mode we cap
`SystemMaxUse=1G` on the mainnet RPC. opera's built-in disk watchdog shuts the
node down at <8 GiB free, so keeping each independent log surface bounded is a
hard operational requirement.

## Current state

- **Mainnet RPC** `i-083fffeeb03583a18` — capped at **1 GiB** as of 2026-04-23.
  `SystemMaxUse=1G` written to `/etc/systemd/journald.conf`,
  `systemd-journald` restarted, and `journalctl --vacuum-size=1G` run to bring
  existing journals under the new ceiling.
- **Testnet RPC** `i-0317eabd98fdf3951` — unchanged (out of scope for this
  change; the incident happened on mainnet only).
- **Testnet validator box** `i-029476269e84beb4a` — unchanged.

## Verification

Run these two commands on the target host (via SSM or SSH):

```bash
grep SystemMaxUse /etc/systemd/journald.conf   # expect: SystemMaxUse=1G
journalctl --disk-usage                        # expect: <= 1.0G
```

Both must be satisfied. If `grep` returns a commented `#SystemMaxUse=` line or
no match, the cap is not in effect.

## How to apply on a new host

The edit requires root (journald.conf is root-owned and `systemctl restart
systemd-journald` needs root), so the SSM document must be
`AWS-RunShellScript` invoked under an admin profile — the
`VinuChain-RunAsUbuntu` document runs as `ubuntu` and cannot restart
`systemd-journald`.

```bash
aws --profile default-root ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name AWS-RunShellScript \
  --comment "journald 1G cap" \
  --parameters 'commands=["bash -c '"'"'set -eu;
    sudo cp /etc/systemd/journald.conf /etc/systemd/journald.conf.bak-$(date +%Y%m%d%H%M%S);
    sudo awk \"/^\\\\[Journal\\\\]/ {in_journal=1; print; next}
               in_journal && /^\\\\[/ {if (!found) {print \\\"SystemMaxUse=1G\\\"; found=1} in_journal=0}
               in_journal && /^#?SystemMaxUse=/ {print \\\"SystemMaxUse=1G\\\"; found=1; next}
               {print}
               END {if (in_journal && !found) print \\\"SystemMaxUse=1G\\\"}\" \
      /etc/systemd/journald.conf > /tmp/journald.conf.new;
    sudo mv /tmp/journald.conf.new /etc/systemd/journald.conf;
    grep -n SystemMaxUse /etc/systemd/journald.conf;
    sudo systemctl restart systemd-journald;
    sudo journalctl --vacuum-size=1G;
    journalctl --disk-usage;
    grep SystemMaxUse /etc/systemd/journald.conf'"'"'"]' \
  --region us-west-2
```

The awk block is idempotent: it replaces any existing (commented or
uncommented) `SystemMaxUse=` line inside the `[Journal]` section, or appends
one if none exists. Running it a second time is a no-op.

Use `--vacuum-size=1G` (matching the configured cap), never `--vacuum-time`.

## Related

- `/var/log/syslog` on the mainnet RPC box was the direct trigger of the
  2026-04-23 incident. That file is written by rsyslog, and is independent of
  systemd-journald — this doc does not address it. A logrotate config (or
  equivalent rsyslog size cap) for `/var/log/syslog` is a separate follow-up.
- opera's disk-low watchdog kills the node at <8 GiB free. Keep every
  independent log surface on the box (journald, rsyslog, opera's own
  `opera_public_node.log` rotation, docker-compose container logs) bounded so
  no single surface can push free space under that threshold.
