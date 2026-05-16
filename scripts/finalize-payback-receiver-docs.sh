#!/usr/bin/env bash
set -euo pipefail

cat >&2 <<'EOF'
finalize-payback-receiver-docs.sh is retired.

The v2.0.17 proxy receiver rollout was superseded by the PaybackV2 binary-level
replacement. The corrected 2026-05-16 PaybackV2 contract is documented directly
in technical-docs/vinuchain-testnet/chain-upgrade-guide.md, so this old proxy
finalizer must not rewrite the guide as a completed proxy rollout.

Update the guide manually when a future PaybackV2 or mainnet rollout changes the
active contract address, node tag, or verification commands.
EOF

exit 1
