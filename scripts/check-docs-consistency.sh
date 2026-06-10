#!/usr/bin/env bash
# Docs consistency gate. Fails on:
#  - internal/ops intel patterns (key locations, AWS identifiers, internal IPs)
#  - known-stale contract addresses outside the historical upgrade log
#  - the wrong-network-id regression
#  - broken relative links in SUMMARY.md
# Run from the repo root: ./scripts/check-docs-consistency.sh
set -u
cd "$(dirname "$0")/.."

fail=0

err() { echo "FAIL: $1"; fail=1; }

# 1) No internal-intel patterns anywhere in the docs tree.
if out=$(grep -rniE 'PRIVATE_TEST|\.env::|arn:aws|i-0[0-9a-f]{8,}|100\.22\.[0-9]+\.[0-9]+' \
    --include='*.md' --include='*.sh' . --exclude-dir=.git --exclude-dir=node_modules \
    | grep -v 'scripts/check-docs-consistency.sh'); then
  err "internal-intel pattern found:"$'\n'"$out"
fi

# 2) Superseded PaybackV2 address must not appear outside the upgrade guide's
#    version-history table (where it is documented as superseded).
if out=$(grep -rniE '0xdEA4687FDBA2528d1b30222e199c90b63AF8c850' --include='*.md' . \
    --exclude-dir=.git | grep -v 'vinuchain-testnet/chain-upgrade-guide.md'); then
  err "superseded PaybackV2 address referenced as if current:"$'\n'"$out"
fi

# 3) The wrong-network-id regression. Tolerant of Markdown bold/emphasis
# markers (e.g. "Set the **network id** to **26**"): allow up to 30
# non-digit characters between "network id" and the bare number 26.
if out=$(grep -rniE 'network[ *_]*id[^0-9]{0,30}\b(26|0x1a)\b' --include='*.md' . --exclude-dir=.git); then
  err "wrong network id (26) found:"$'\n'"$out"
fi

# 4) Leftover paste-accident links.
if out=$(grep -rni 'emojiguide\.com' --include='*.md' . --exclude-dir=.git); then
  err "emojiguide paste-accident link found:"$'\n'"$out"
fi

# 5) Every relative link in SUMMARY.md must resolve to a file.
while IFS= read -r target; do
  [ -f "$target" ] || err "SUMMARY.md links to missing file: $target"
done < <(grep -oE '\]\([^)]+\)' SUMMARY.md | sed 's/^](//; s/)$//' | grep -v '^http')

if [ "$fail" -ne 0 ]; then
  echo "docs consistency check FAILED"
  exit 1
fi
echo "docs consistency check passed"
