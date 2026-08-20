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

# 6) vinuscan.com does not resolve. The registration expired 2026-07-06 and the
#    name entered redemption period 2026-08-17, so every host under it (apex,
#    www., mainnet., testnet., faucet., vinu-price.) returns NXDOMAIN — verified
#    2026-08-19. That is how a dead staking link sat in staking/overview.md.
#    Explorer links belong on vinuexplorer.org / testnet.vinuexplorer.org; the
#    staking UI is https://vinuchain.org/staking.
#
#    THIS CHECK IS CONDITIONAL, NOT PERMANENT. The domain is redeemable until it
#    drops (~mid-September 2026) and the serving path behind it is intact, so if
#    vinuscan.com is redeemed and resolving again, relax or delete this check
#    rather than working around it. Confirm with:
#        dig +short mainnet.vinuscan.com
#    Background: vinuchain-ops-docs ops/incident-2026-08-19-vinuscan-domain-expiry.md
if out=$(grep -rniE '[a-z0-9.-]*vinuscan\.com' --include='*.md' . --exclude-dir=.git); then
  err "vinuscan.com link found; that domain does not resolve (expired 2026-07-06, in redemption since 2026-08-17). Use vinuexplorer.org / testnet.vinuexplorer.org for explorers, or https://vinuchain.org/staking for staking. If the domain has since been redeemed, relax check 6 instead of adding the link back:"$'\n'"$out"
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

# 8) Secret-bearing examples must ignore local credentials and avoid key-bearing output.
if ! grep -qE '^\.env$|^\.env\.\*$' .gitignore; then
  err ".gitignore must ignore local .env credentials"
fi
if out=$(grep -rniE "password[[:space:]]*=[[:space:]]*['\"][^$'\"]+['\"]|\'(Decrypted Key:|Decrypted Wallet:|Encrypted Key:|Encrypted Wallet:|Create an account:|Create an account with a Private key:|Adding another account using private key:)" --include='*.md' technical-docs/web3-methods); then
  err "unsafe wallet secret example found:"$'\n'"$out"
fi

# 9) Rollback guidance must cover every persisted SFC patch currently active.
upgrade_guide="technical-docs/vinuchain-testnet/chain-upgrade-guide.md"
rollback_section=$(sed -n '/^\*\*Per-version rollback deltas\./,/^{% endhint %}$/p' "$upgrade_guide")
bytecode_table=$(sed -n '/^| Sealed patch /,/^$/p' "$upgrade_guide")
for marker in SfcV2Patch7 SfcV2Patch8 SfcV2Patch9 v2.0.41 v2.0.43 v2.0.44; do
  if ! grep -qF -- "$marker" <<<"$rollback_section"; then
    err "rollback section is missing current marker: $marker"
  fi
  if ! grep -qF -- "$marker" <<<"$bytecode_table"; then
    err "sealed-bytecode table is missing current marker: $marker"
  fi
done

# 10) Every relative link in the root README must resolve to a file or directory.
while IFS= read -r target; do
  target="${target%%#*}"
  [ -n "$target" ] || continue
  [ -e "$target" ] || err "README.md links to missing path: $target"
done < <(grep -oE '\]\([^)]+\)' README.md | sed 's/^](//; s/)$//' | grep -Ev '^(https?:|mailto:|#)')

# 11) Every relative link in SUMMARY.md must resolve to a file.
while IFS= read -r target; do
  [ -f "$target" ] || err "SUMMARY.md links to missing file: $target"
done < <(grep -oE '\]\([^)]+\)' SUMMARY.md | sed 's/^](//; s/)$//' | grep -v '^http')

if [ "$fail" -ne 0 ]; then
  echo "docs consistency check FAILED"
  exit 1
fi
echo "docs consistency check passed"
