#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$DOCS_DIR/.." && pwd)"
VINUCHAIN_DIR="${VINUCHAIN_DIR:-$WORKSPACE_DIR/VinuChain}"
GUIDE="${GUIDE:-$DOCS_DIR/technical-docs/vinuchain-testnet/chain-upgrade-guide.md}"
EXPECTED_IMPLEMENTATION="${EXPECTED_IMPLEMENTATION:-0x80DA5f5e78c94EE5125Be515Ad4cd248469B57ba}"
UPGRADE_TX="${QUOTA_UPGRADE_TX:-}"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage:
  scripts/finalize-payback-receiver-docs.sh [options] <upgrade-tx>

Options:
  --upgrade-tx <hash>  Upgrade transaction hash. May also be set as QUOTA_UPGRADE_TX.
  --dry-run            Validate readiness and print the planned replacement summary.
  -h, --help           Show this help.

This script refuses to edit docs until the live testnet Quota proxy points at the
receiver-capable implementation and the implementation bytecode contains
stakeFor(address).
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --upgrade-tx)
      UPGRADE_TX="${2:-}"
      if [ -z "$UPGRADE_TX" ]; then
        printf '%s\n' '--upgrade-tx requires a hash' >&2
        exit 1
      fi
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    0x*)
      if [ -n "$UPGRADE_TX" ]; then
        printf 'upgrade transaction hash specified more than once\n' >&2
        exit 1
      fi
      UPGRADE_TX="$1"
      shift
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! "$UPGRADE_TX" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
  printf 'Set QUOTA_UPGRADE_TX or pass a 32-byte upgrade tx hash.\n' >&2
  exit 1
fi

if [ ! -x "$VINUCHAIN_DIR/scripts/audit-payback-receiver-testnet.sh" ]; then
  printf 'missing VinuChain audit script: %s\n' "$VINUCHAIN_DIR/scripts/audit-payback-receiver-testnet.sh" >&2
  exit 1
fi

audit_json="$("$VINUCHAIN_DIR/scripts/audit-payback-receiver-testnet.sh")"
receiver_readiness="$(jq -r '.receiverReadiness' <<<"$audit_json")"
implementation="$(jq -r '.quotaProxy.implementation' <<<"$audit_json")"
implementation_has_stake_for="$(jq -r '.quotaProxy.implementationHasStakeFor' <<<"$audit_json")"
ready_blockers="$(jq -r '.readyBlockers | length' <<<"$audit_json")"

if [ "$receiver_readiness" != "ready" ]; then
  printf '%s\n' "$audit_json"
  printf 'Refusing to finalize docs: receiverReadiness=%s.\n' "$receiver_readiness" >&2
  exit 1
fi

if [ "$(printf '%s' "$implementation" | tr '[:upper:]' '[:lower:]')" != "$(printf '%s' "$EXPECTED_IMPLEMENTATION" | tr '[:upper:]' '[:lower:]')" ]; then
  printf '%s\n' "$audit_json"
  printf 'Refusing to finalize docs: implementation %s does not match %s.\n' "$implementation" "$EXPECTED_IMPLEMENTATION" >&2
  exit 1
fi

if [ "$implementation_has_stake_for" != "true" ] || [ "$ready_blockers" != "0" ]; then
  printf '%s\n' "$audit_json"
  printf 'Refusing to finalize docs: implementation is not receiver-ready.\n' >&2
  exit 1
fi

node - "$GUIDE" "$UPGRADE_TX" "$EXPECTED_IMPLEMENTATION" "$DRY_RUN" <<'NODE'
const fs = require('fs')

const [guidePath, upgradeTx, implementation, dryRunValue] = process.argv.slice(2)
const dryRun = dryRunValue === 'true'
const completedDate = new Date().toISOString().slice(0, 10)
let text = fs.readFileSync(guidePath, 'utf8')

function replaceOnce(pattern, replacement, label) {
  const next = text.replace(pattern, replacement)
  if (next === text) {
    throw new Error(`Could not update ${label}`)
  }
  text = next
}

replaceOnce(
  /\*\*Payback receiver rollout status:\*\*[\s\S]*?\n\n`v2\.0\.16-elemont`/,
  `**Payback receiver rollout status:** Complete as of ${completedDate}. The v2.0.17 node binary is deployed on testnet, the testnet Quota proxy \`0x824B93dE7221cf8a35FBd29d5202f6eFa3A29C5D\` points at the verified receiver-capable implementation \`${implementation}\`, VinuExplorer reports verified unchanged bytecode, and the quota audit confirms the explorer ABI and deployed bytecode match the local \`QuotaContract\` artifact. Upgrade transaction: \`${upgradeTx}\`. \`QuotaContract.stakeFor(address)\` lets a funding wallet supply VC while the receiver address owns the Quota stake and receives refunds for transactions it signs.\n\n\`v2.0.16-elemont\``,
  'rollout status'
)

replaceOnce(
  /\| v2\.0\.17-elemont \| Payback\/Quota receiver staking\s+\|[^|]+\|/,
  `| v2.0.17-elemont | Payback/Quota receiver staking          | Deployed to testnet RPC + validators on 2026-05-10. The node PaybackCache recognizes \`stakeFor(address)\` as stake owned by the receiver, preserving same-epoch duration accounting for the refunding address. Receiver implementation \`${implementation}\` is deployed, verified with unchanged bytecode, artifact-matched, and active behind the live Quota proxy; upgrade tx \`${upgradeTx}\`. |`,
  'v2.0.17 release row'
)

replaceOnce(
  /In the pending proxy-upgrade Payback receiver flow, a funding wallet may call `QuotaContract\.stakeFor\(receiver\)` instead of `stake\(\)`\./,
  'In the Payback receiver flow, a funding wallet may call `QuotaContract.stakeFor(receiver)` instead of `stake()`.',
  'Payback receiver flow wording'
)

replaceOnce(
  /7\. In `VinuChain-Docs`, after the live proxy audit passes and the upgrade\n   transaction hash is known, finalize this guide:\n\n   ```bash\n   QUOTA_UPGRADE_TX=<UPGRADE_TX_HASH> scripts\/finalize-payback-receiver-docs\.sh\n   ```/,
  `7. This guide records the completed Quota proxy upgrade to \`${implementation}\`, including upgrade transaction \`${upgradeTx}\`.`,
  'completion checklist docs item'
)

replaceOnce(
  /_Last updated: 2026-05-10 · latest released VinuChain tag `v2\.0\.17-elemont` · receiver implementation verified with unchanged bytecode and partial VinuExplorer status; Quota proxy upgrade pending · go-vinu `v1\.20\.14-quota` · lachesis-base `v0\.1\.6-elemont`_/,
  `_Last updated: ${completedDate} · latest released VinuChain tag \`v2.0.17-elemont\` · Payback receiver rollout complete; Quota proxy upgraded via \`${upgradeTx}\`; explorer bytecode artifact-matched · go-vinu \`v1.20.14-quota\` · lachesis-base \`v0.1.6-elemont\`_`,
  'last updated marker'
)

const stalePatterns = [
  'still points at the verified pre-receiver implementation',
  'remaining mutating step',
  'proxy upgrade pending',
  'live Quota proxy upgrade is still pending',
  'pending proxy-upgrade',
]
const stale = stalePatterns.filter((pattern) => text.includes(pattern))
if (stale.length > 0) {
  throw new Error(`Docs still contain stale pending text: ${stale.join(', ')}`)
}

if (dryRun) {
  console.log(
    JSON.stringify(
      {
        guide: guidePath,
        dryRun,
        implementation,
        upgradeTx,
        completedDate,
      },
      null,
      2
    )
  )
} else {
  fs.writeFileSync(guidePath, text)
  console.log(
    JSON.stringify(
      {
        guide: guidePath,
        dryRun,
        implementation,
        upgradeTx,
        completedDate,
        updated: true,
      },
      null,
      2
    )
  )
}
NODE
