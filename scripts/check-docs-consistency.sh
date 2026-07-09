#!/usr/bin/env bash
# Docs consistency gate. Fails on:
#  - internal/ops intel patterns (key locations, AWS identifiers, internal IPs)
#  - known-stale contract addresses outside the historical upgrade log
#  - the wrong-network-id regression
#  - stale bare VinuScan domain links
#  - mojibake marker characters from mis-decoded UTF-8
#  - duplicate manual anchor IDs
#  - broken relative links in SUMMARY.md
# Run from the repo root: ./scripts/check-docs-consistency.sh
set -u

for cmd in dirname grep sed sort uniq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FAIL: required command not found: $cmd" >&2
    exit 127
  fi
done

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

# 5) Mojibake marker characters often appear when UTF-8 is decoded as a
#    Windows code page and then committed as UTF-8. Keep this script ASCII by
#    matching the UTF-8 byte sequences for U+00C2, U+00C3, U+00E2, U+00EF,
#    and U+FFFD through ANSI-C quoted octal escapes.
mojibake_pattern=$'\303\202|\303\203|\303\242|\303\257|\357\277\275'
if out=$(grep -rniE "$mojibake_pattern" --include='*.md' . --exclude-dir=.git); then
  err "mojibake marker found; re-save the affected text as UTF-8 or replace it with plain ASCII:"$'\n'"$out"
fi

# 6) VinuScan links must use the explicit mainnet/testnet hosts.
if out=$(grep -rniE 'https?://(www\.)?vinuscan\.com([/?#)]|$)' --include='*.md' . --exclude-dir=.git); then
  err "bare vinuscan.com link found; use mainnet.vinuscan.com or testnet.vinuscan.com:"$'\n'"$out"
fi

# 7) Manual anchor IDs must be unique. Duplicate IDs can make GitBook route
#    section links to the wrong heading or fail on generated anchors.
duplicate_ids=$(grep -rhoE 'id="[^"]+"' --include='*.md' . --exclude-dir=.git \
  | sed 's/^id="//; s/"$//' \
  | sort \
  | uniq -d)
if [ -n "$duplicate_ids" ]; then
  out=""
  while IFS= read -r anchor_id; do
    [ -n "$anchor_id" ] || continue
    matches=$(grep -rniF "id=\"$anchor_id\"" --include='*.md' . --exclude-dir=.git)
    out="${out}${anchor_id}"$'\n'"${matches}"$'\n'
  done <<< "$duplicate_ids"
  err "duplicate manual anchor id found:"$'\n'"$out"
fi

# 8) Every relative link in the root README must resolve to a file or directory.
while IFS= read -r target; do
  target="${target%%#*}"
  [ -n "$target" ] || continue
  [ -e "$target" ] || err "README.md links to missing path: $target"
done < <(grep -oE '\]\([^)]+\)' README.md | sed 's/^](//; s/)$//' | grep -Ev '^(https?:|mailto:|#)')

# 9) Every relative link in SUMMARY.md must resolve to a file.
while IFS= read -r target; do
  [ -f "$target" ] || err "SUMMARY.md links to missing file: $target"
done < <(grep -oE '\]\([^)]+\)' SUMMARY.md | sed 's/^](//; s/)$//' | grep -v '^http')

if [ "$fail" -ne 0 ]; then
  echo "docs consistency check FAILED"
  exit 1
fi
echo "docs consistency check passed"
