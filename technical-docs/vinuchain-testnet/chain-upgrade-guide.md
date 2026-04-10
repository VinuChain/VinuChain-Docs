# VinuChain v1.0.1-elemont — Validator Upgrade Guide

{% hint style="danger" %}
**This is a mandatory hard fork.** Validators still running the old
binary after the next epoch seal on their node will be forked off the
network and unable to produce blocks until they upgrade.
{% endhint %}

{% hint style="info" %}
**TL;DR**

- **Target tag:** `v1.0.1-elemont`
- **Binary version string:** `2.0.0-elemont` (the tag name and the
  `opera version` output are intentionally different — see note below)
- **Mandatory:** yes, all validators
- **Activation:** per-node at the **next epoch seal** after restart
  (up to ~4h later; no coordinated block height)
- **Expected downtime:** 2–10 minutes per validator for a clean swap
- **Build requirements:** Go 1.25+, C compiler, ~50 GB free disk
{% endhint %}

{% hint style="info" %}
**Version string vs git tag.** The release is cut from git tag
`v1.0.1-elemont`, but the binary reports `2.0.0-elemont`. The tag is the
release name; the version string comes from `version/version.go`
(`VersionMajor=2`, `VersionMinor=0`, `VersionPatch=0`,
`VersionMeta=elemont`). Both refer to the same release.
{% endhint %}

## What Is This Upgrade?

This hard fork activates three upgrade flags on VinuChain. All validators
must upgrade before their next epoch seal or risk being forked off the
network.

### Features Activated

| Feature | What It Does |
| --------- | ------------- |
| **Podgorica** | Activates the payback fee refund system — eligible stakers receive gas fee refunds |
| **SfcV2** | Upgrades the SFC (Staking for Consensus) contract bytecode with V2 logic and implements 30% base fee burn |
| **Elemont** | Consensus-level fixes for cheater detection, epoch advancement, median time, and validator handling |

#### SfcV2 — specific changes

SfcV2 gates the following staking and fee mechanism changes, all of which
activate atomically when the flag is set:

- **SFC V2 contract bytecode** — the staking contract is replaced with the
  V2 implementation, which includes updated logic for delegation, rewards,
  and validator interactions. The V2 contract is backward-compatible with
  existing delegation and staking state.
- **30% base fee burn** — 30% of the **base fee portion** of each
  transaction's fee is burned (sent to the zero address `0x0000…0000`)
  instead of flowing entirely to the block validator. The remaining 70% of
  base fees and all priority tips continue to reward validators as before.
- **Effective supply reduction** — as base fees accumulate at the zero
  address, the effective circulating supply gradually decreases over time.

Source: `gossip/blockproc/drivermodule/driver_txs.go` (burn logic);
`opera/contracts/sfc/contract.go` (V2 bytecode); `block_processor.go`
(bytecode installation).

#### Elemont — specific fixes

Elemont gates the following consensus-critical behavioral fixes, all of
which activate atomically when the flag is set:

- **NoCheaters merged view** — cheater list is evaluated against the
  merged block/epoch view rather than a single source.
- **AdvanceEpochs full 32-byte ABI decode** — governance payloads use the
  full 32-byte ABI word instead of a truncated read.
- **Cheater fee zeroing** — validators flagged as cheaters receive no
  fee share for the affected block.
- **vecmt GatherFrom tie-breaking** — vector clock tie-breaking for
  event selection becomes deterministic.
- **MedianTime stable sort** — epoch median-time computation uses a
  stable sort so ties no longer depend on input order.
- **Empty-pubkey validator skip at epoch seal** — validators with an
  empty public key are skipped during epoch seal instead of aborting.

#### Why Elemont fixes matter

These fixes address edge cases in consensus safety and determinism:

- **NoCheaters merged view + cheater fee zeroing** — prevents validators
  flagged as cheaters from earning fees on disputed blocks, reducing
  incentive for consensus attacks.
- **AdvanceEpochs 32-byte decode** — ensures governance proposals are
  decoded correctly across all validators (prevents divergence from
  truncation bugs).
- **vecmt tie-breaking + MedianTime stable sort** — make event selection
  and time computation deterministic, preventing non-deterministic block
  hashes when multiple events have equal priority.
- **Empty-pubkey skip** — prevents epoch seal panics from malformed
  validator registrations, improving uptime.

**Impact on block hashes:** All Elemont fixes are consensus-critical, meaning
post-activation block hashes will differ from a pre-Elemont binary running on
the same transactions. This is expected and correct.

Source: `opera/rules.go` (`Upgrades.Elemont` comment block).

### Network Details

| Network | Chain ID   | RPC                              | Status          |
|---------|------------|----------------------------------|-----------------|
| Mainnet | 207 (0xcf) | `https://vinuchain-rpc.com`      | Upgrade pending |
| Testnet | 206 (0xce) | `https://vinufoundation-rpc.com` | Upgrade first   |

---

## Timeline

1. **Testnet upgrade** — genesis validators upgrade testnet nodes first.
2. **Testnet validation** — manual testing for stability (blocks,
   transactions, staking, fee refunds).
3. **Mainnet upgrade announcement** — date and time window communicated
   to all validators.
4. **Mainnet pre-staging** — validators build the binary ahead of time.
5. **Mainnet upgrade window** — coordinated binary swap within the
   announced window.
6. **Monitoring** — watch for activation logs and chain health.

---

## Prerequisites

### Go Version Upgrade (1.14 → 1.25+)

{% hint style="danger" %}
**Critical build requirement change.** This release requires **Go 1.25+** or
later. The production `main` branch supported Go 1.14; the Elemont binary
will not build on Go 1.14 or any 1.x version below 1.25.

**Check your current Go version:**

```bash
go version
# Expected output: go version go1.25.N linux/amd64 (or later)
```

**If you are running Go 1.14–1.24**, you **must upgrade** before building:

```bash
# Download Go 1.25 or later
wget https://go.dev/dl/go1.25.8.linux-amd64.tar.gz

# Extract to a temporary location
tar -xvf go1.25.8.linux-amd64.tar.gz

# Remove the old Go installation
sudo rm -rf /usr/local/go

# Move the new Go to the system location
sudo mv go /usr/local

# Verify the upgrade
go version
# Expected: go version go1.25.8 linux/amd64
```

For arm64 systems, use `go1.25.8.linux-arm64.tar.gz` instead.
Verify you are using the correct architecture before downloading.
{% endhint %}

### Other Prerequisites

- **gcc (or clang)** and standard C library headers — required for building
  go-vinu's crypto and LevelDB C bindings.
- **git**
- At least **50 GB** free disk space
- Current node must be **fully synced** before upgrading

### Required Ports

No port changes in this upgrade. Ensure these remain open in your
firewall:

| Port | Protocol | Purpose |
| ------ | ---------- | --------- |
| 5050 | TCP/UDP | P2P networking |
| 18545 | TCP | HTTP JSON-RPC (if exposing RPC) |
| 18546 | TCP | WebSocket JSON-RPC (if exposing WS) |

---

## Upgrade Steps

{% stepper %}

{% step %}

### Stop your node

{% hint style="warning" %}
**Clean shutdown required.** Do **not** force-kill the process. A hard
kill during block processing can corrupt the LevelDB chaindata and
force a full resync.
{% endhint %}

{% tabs %}
{% tab title="nohup (standard)" %}

```bash
pkill -TERM opera
```

If the process doesn't exit cleanly within ~10 seconds, check the logs.
`pkill` sends SIGTERM by default, allowing graceful shutdown. Only use
`pkill -KILL opera` as a last resort if the process is stuck.

{% endtab %}

{% tab title="Systemd" %}

```bash
sudo systemctl stop opera
```

{% endtab %}

{% tab title="Docker" %}

```bash
docker stop opera
```

{% endtab %}

{% tab title="Manual (foreground)" %}
Send `Ctrl+C` (SIGINT) to the foreground process and wait for it to
exit cleanly. In tmux/screen, attach first, then send the interrupt.
{% endtab %}
{% endtabs %}

Verify the process has exited:

```bash
pgrep -f opera || echo "Stopped"
```

{% endstep %}

{% step %}

### Back up your data

{% hint style="warning" %}
**Legacy datadir path.** If your node was installed before the rename
from `opera` to `vinuchain`, your datadir is at `~/.opera`, not
`~/.vinuchain`. The binary auto-detects the legacy location and uses it
if `~/.vinuchain` does not yet exist (see
`cmd/opera/launcher/defaults.go`). Substitute the correct path in the
commands below — **do not move files between directories**.
{% endhint %}

```bash
# Adjust the source path to match your datadir
cp -r ~/.vinuchain ~/.vinuchain.backup-pre-elemont
```

{% endstep %}

{% step %}

### Download and build the new binary

Pre-stage the binary in a persistent location. Avoid `/tmp` — some Linux
distributions clear `/tmp` on reboot, which would wipe a pre-staged
build.

{% code title="Build the release tag" overflow="wrap" %}

```bash
git clone https://github.com/VinuChain/VinuChain.git $HOME/vinuchain-upgrade
cd $HOME/vinuchain-upgrade
git checkout v1.0.1-elemont
make opera
# Binary is at $HOME/vinuchain-upgrade/build/opera
```

{% endcode %}

If you prefer system paths, use `/opt/vinuchain-upgrade` instead of
`$HOME/vinuchain-upgrade`.
{% endstep %}

{% step %}

### Verify the new binary

The newly-built binary is at:

```bash
$HOME/vinuchain-upgrade/build/opera version
# Expected: Version: 2.0.0-elemont
```

{% hint style="info" %}
`opera version` prints `2.0.0-elemont` — this is correct even though
the git tag is `v1.0.1-elemont`. See the note at the top of this page.
{% endhint %}

{% endstep %}

{% step %}

### Start your node

{% tabs %}
{% tab title="nohup (standard)" %}

Start the node from the upgraded binary:

```bash
nohup $HOME/vinuchain-upgrade/build/opera \
  --bootnodes "enode://e2a95c1b8d85b018b8e88133bec342801b42e19b59a52e030462d04a5549f02fc57215b4ca97771ec6b3a0d30a78603fdccd2b5091c44f6ac439d6c8be8bc539@44.239.129.39:3000,enode://7a45d086b9c82bd3677a76d36e003b9490066d56b612f33d05cb4d242212acd4e5cab4abbcb15a0df9aa499e41b4b4e868d82ba1c509c1990c9217dfe4607775@44.239.129.39:3001,enode://d8e37eeba79b2c52dcba6e396ff907f27a6a8f7db34528cb8636bc3271291657a01c5649bff53429cea8a23b03fac13a178813c34c6d17d14f7b810a988393b5@44.239.129.39:3002,enode://3f15b5ac22dea3e37a90cd9378cf0cd4ed9ea122851846c8108fcc7d2c7e709ea4a089cf3da93c0d3d3053250417cf0ea9ad9eff0aa77ff07d76b6cf267a2937@44.239.129.39:3003" \
  --validator.id YOUR_VALIDATOR_ID \
  --validator.pubkey 0xYOUR_PUBKEY \
  --validator.password /path/to/password.txt \
  > validator.log &
```

The `--bootnodes` value above lists all four live testnet validators at
`44.239.129.39` (ports 3000–3003). Use them as-is — they are the same
enodes hardcoded into the binary's testnet defaults and will give a new
or restarted node a working entrypoint into the peer mesh.

Monitor the logs:

```bash
tail -f validator.log
```

**Optional flags** (add only if you were using them before):

- `--datadir /custom/path` — if chain data is not in the default `~/.opera` location
- `--nat extip:YOUR_PUBLIC_IP` — if needed for P2P networking configuration

{% hint style="info" %}
**Slow peer discovery on small networks?** On a small or freshly
restarted testnet, discv5 discovery via `--bootnodes` can take several
minutes to populate the peer table — and may fail entirely if the
bootnode itself is restarting at the same time. The most reliable fix
is to drop a `static-nodes.json` file inside `<datadir>/go-opera/` that
lists every peer enode you want a persistent connection to. Opera reads
it on every startup and dials those peers immediately, bypassing
discovery.

```bash
mkdir -p $HOME/.opera/go-opera
cat > $HOME/.opera/go-opera/static-nodes.json <<'EOF'
[
  "enode://e2a95c1b8d85b018b8e88133bec342801b42e19b59a52e030462d04a5549f02fc57215b4ca97771ec6b3a0d30a78603fdccd2b5091c44f6ac439d6c8be8bc539@44.239.129.39:3000",
  "enode://7a45d086b9c82bd3677a76d36e003b9490066d56b612f33d05cb4d242212acd4e5cab4abbcb15a0df9aa499e41b4b4e868d82ba1c509c1990c9217dfe4607775@44.239.129.39:3001",
  "enode://d8e37eeba79b2c52dcba6e396ff907f27a6a8f7db34528cb8636bc3271291657a01c5649bff53429cea8a23b03fac13a178813c34c6d17d14f7b810a988393b5@44.239.129.39:3002",
  "enode://3f15b5ac22dea3e37a90cd9378cf0cd4ed9ea122851846c8108fcc7d2c7e709ea4a089cf3da93c0d3d3053250417cf0ea9ad9eff0aa77ff07d76b6cf267a2937@44.239.129.39:3003"
]
EOF
```

Adjust the path if you use a non-default `--datadir`.
{% endhint %}

{% endtab %}

{% tab title="Systemd" %}

```bash
sudo systemctl start opera
sudo journalctl -u opera -f
```

{% endtab %}

{% tab title="Docker" %}

```bash
docker start opera
docker logs -f opera
```

Ensure your `docker run` command (or compose file) still mounts the
datadir volume and exposes the same ports.
{% endtab %}

{% tab title="Manual (foreground)" %}

For testing or development, you can run in the foreground:

```bash
./opera \
  --validator.id YOUR_VALIDATOR_ID \
  --validator.pubkey 0xYOUR_PUBKEY \
  --validator.password /path/to/password.txt
```

**Optional flags:**

- `--datadir /path/to/chaindata` — if chain data is in a custom location
  (default: `~/.opera`)

{% endtab %}
{% endtabs %}
{% endstep %}

{% step %}

### Verify activation

{% hint style="info" %}
Activation is **per-validator**. There is no coordinated block height.
Each node stages the new upgrade flags into its pending rules at
startup, and the flags activate atomically at the **next epoch seal**
on that node — at which point the SFC V2 contract bytecode is installed
in chain state and the Podgorica/Elemont effects become live.
{% endhint %}

On startup, the node prints an ASCII banner identifying the release.
This is the first visual confirmation that you are running the Elemont
binary:

```text
 ██╗   ██╗██╗███╗   ██╗██╗   ██╗ ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
 ██║   ██║██║████╗  ██║██║   ██║██╔════╝██║  ██║██╔══██╗██║████╗  ██║
 ██║   ██║██║██╔██╗ ██║██║   ██║██║     ███████║███████║██║██╔██╗ ██║
 ╚██╗ ██╔╝██║██║╚██╗██║██║   ██║██║     ██╔══██║██╔══██║██║██║╚██╗██║
  ╚████╔╝ ██║██║ ╚████║╚██████╔╝╚██████╗██║  ██║██║  ██║██║██║ ╚████║
   ╚═══╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

                        v2.0  -  ELEMONT

  Version: 2.0.0-elemont
```

Immediately after the banner, you should see **three log lines** (the
binary staging the hardcoded upgrade flags into pending rules):

```text
INFO Staged SfcV2 upgrade from binary rules; will activate at next epoch seal
INFO Staged Podgorica upgrade from binary rules; will activate at next epoch seal
INFO Staged Elemont upgrade from binary rules; will activate at next epoch seal
```

Then, at the **next epoch seal** on your node (up to ~4 hours after
startup — this is the `MaxEpochDuration` cap; epochs can seal earlier
if triggered by gas, event count, or cheaters), you should see **two
log lines**:

```text
INFO Applying SFC V2 bytecode upgrade              block=<N>
INFO Activating Podgorica fee refund encoding      block=<N>
```

The Elemont consensus fixes activate **silently** at the same epoch seal —
there is no separate log line for Elemont, but it is active and consensus
rules have changed (visible in different block hashes vs peers running
older versions).

Once you have seen the banner, all three startup staging lines, **and**
both seal-time activation lines at the next seal, the upgrade is
complete on your node. You can verify Elemont is active by confirming
your block hashes match peers running the Elemont binary.

#### Verification checklist

| Check | Expected |
| --- | --- |
| Startup banner | `VINUCHAIN  v2.0 - ELEMONT` ASCII art printed to stderr |
| `opera version` | `Version: 2.0.0-elemont` |
| Startup log | 3× `Staged ... upgrade from binary rules; will activate at next epoch seal` |
| Next epoch seal log | `Applying SFC V2 bytecode upgrade block=<N>` + `Activating Podgorica fee refund encoding block=<N>` |
| First post-seal block | `feeRefund` appears on eligible receipts; base fee burn credited to `0x0000…0000` |
| Block hash vs peer | Identical |

{% endstep %}

{% step %}

### Verify you're on the correct chain

After the epoch seal (when you see `Applying SFC V2 bytecode upgrade`
in the logs), confirm your node is on the same chain as the network.

```bash
curl -s -X POST http://localhost:18545/ \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' \
  | jq -r '"Block \(.result.number | tonumber): \(.result.hash)"'
```

Compare the block number and hash against the public RPC or another
validator's node. If they match, you are on the correct chain.
{% endstep %}

{% endstepper %}

---

## Setting Up a New Validator

{% hint style="info" %}
New validator setup is **not** covered on this page. If you are
installing a fresh validator for the first time rather than upgrading an
existing one, follow the dedicated guide:
[Become a Validator](../nodes-and-validators/become-a-validator.md).

That guide uses the correct `opera validator new` command for
generating a validator key. A plain `opera account new` creates a
regular externally-owned account, not a validator key.
{% endhint %}

---

## Rollback

Rollback behavior depends on whether your node has already sealed an
epoch under the new binary.

### Before the epoch seal

If you have not yet seen `Applying SFC V2 bytecode upgrade` in the
logs, rollback is straightforward — no datadir changes are needed.

1. Stop the node (clean shutdown).
2. Replace `/usr/local/bin/opera` (or your image) with the previous
   release binary.
3. Start the node.

The upgrade flags staged at startup live in the pending `DirtyRules`
on the stored block state. Starting the old binary leaves them
unapplied; starting the new binary again re-stages them idempotently.
No data is lost.

### After the epoch seal

{% hint style="danger" %}
**Rollback after the epoch seal is not supported.** Once
`Applying SFC V2 bytecode upgrade` has been logged, the SFC V2 bytecode
is written into chain state and distributed across validators.
Restoring your pre-upgrade datadir backup will only rewind *your local
view* — the network has already moved on, and your node will diverge
from consensus the moment it tries to sync.
{% endhint %}

If you must recover a node whose datadir is stuck on an old state,
follow the late-upgrade recovery steps below rather than restoring a
backup.

---

## Troubleshooting

### Node won't start after upgrade

1. Check logs: `journalctl -u opera -f` (systemd) or the Docker /
   terminal output for your install method.
2. Verify the binary version is correct: `opera version` must print
   `2.0.0-elemont`.
3. If the database is reported as corrupted, stop the node and restore
   from your pre-upgrade backup.

### Node starts but doesn't produce events

1. Confirm your validator key is accessible and `--validator.password`
   points to the right file.
2. Check that `--validator.id` and `--validator.pubkey` match your
   on-chain validator registration.
3. Ensure your node has peers: the logs should show incoming / outgoing
   peer connections. An isolated node cannot produce events.

### "Database is from a newer version" error

You attempted to downgrade. Restore from your pre-upgrade backup if you
need to revert — and only if you have not yet passed the epoch seal
(see the Rollback section above).

### Consensus stall / no new blocks

If the network stops producing blocks, it usually means not enough
validators have upgraded. Contact the VinuChain team immediately via
the official coordination channel.

---

## Coordinated Upgrade Procedure

This hard fork requires **all validators** to upgrade within a short
window.

### How the upgrade activates

The upgrade does **not** activate at a specific block height. Instead,
on each node:

1. The operator installs the new binary and restarts.
2. On startup, the binary stages the new flags (`Podgorica`, `SfcV2`,
   `Elemont`) into the pending `DirtyRules` on the stored block state,
   logging the three `Staged … upgrade from binary rules` lines.
3. At the next epoch seal on that node (up to ~4 hours — the
   `MaxEpochDuration` cap; can be shorter if triggered by gas, event
   count, or cheaters), the staged rules take effect: the SFC V2
   bytecode is installed in chain state, the Podgorica fee refund
   encoding turns on, and the Elemont consensus fixes apply.
4. From that point, all nodes must be on the new binary to process
   subsequent blocks correctly.

Validators can upgrade at any time before the epoch seal — there is no
need to restart simultaneously. All validators should be upgraded
**within the same epoch** to avoid divergence.

### Recommended procedure

1. **VinuChain team announces an upgrade window** — e.g. "Tuesday
   14:00–16:00 UTC".
2. **Pre-stage the binary** on every validator server before the
   window, but do not install it yet. See step 3 of the Upgrade Steps
   above.
3. **During the window**, each operator performs the binary swap
   (Upgrade Steps 1 → 5).
4. **Confirm in the coordination channel** — each operator confirms
   they see the three `Staged … upgrade from binary rules` log lines.
5. **Wait for epoch seal** — the next epoch seal triggers the atomic
   activation. All operators verify the two seal-time log lines
   (`Applying SFC V2 bytecode upgrade` and
   `Activating Podgorica fee refund encoding`), then spot-check that a
   post-seal eligible-staker transaction carries `feeRefund` and that
   the zero-address balance is growing block over block.

### Recovering a validator that missed the upgrade

If your validator missed the fork and is stuck, always start with a
simple restart on the new binary. A full resync is a **last resort** —
it takes hours to days.

**Step 1 — Install and restart on the new binary.**

{% tabs %}
{% tab title="nohup (standard)" %}

```bash
pkill -TERM opera
sleep 2  # Give the process time to exit

# Restart using the upgraded binary
nohup $HOME/vinuchain-upgrade/build/opera \
  --validator.id YOUR_VALIDATOR_ID \
  --validator.pubkey 0xYOUR_PUBKEY \
  --validator.password /path/to/password.txt \
  > validator.log &
```

{% endtab %}

{% tab title="Systemd" %}

```bash
sudo systemctl stop opera
sudo cp $HOME/vinuchain-upgrade/build/opera /usr/local/bin/opera
sudo systemctl start opera
```

{% endtab %}

{% tab title="Docker" %}

```bash
docker stop opera
# Rebuild and retag as shown in the Replace the Binary step
docker start opera
```

{% endtab %}
{% endtabs %}

**Step 2 — Watch the logs for sync progress.**

{% tabs %}
{% tab title="nohup (standard)" %}

```bash
tail -f validator.log
```

{% endtab %}

{% tab title="Systemd" %}

```bash
sudo journalctl -u opera -f
```

{% endtab %}

{% tab title="Docker" %}

```bash
docker logs -f opera
```

{% endtab %}
{% endtabs %}

If you see block numbers advancing and normal sync messages, the node
is recovering on its own. Let it catch up to the chain head before
doing anything else.

**Step 3 — Only if logs show repeated invalid-block errors.** This
means your local chain has diverged beyond what the new binary can
reconcile. Resync from scratch:

{% hint style="danger" %}
**Last resort only.** The following command deletes your local
chaindata. Only run it after Step 2 has clearly failed (repeated
invalid-block errors in the logs for more than a few minutes), and
make sure your pre-upgrade backup still exists.
{% endhint %}

{% tabs %}
{% tab title="nohup (standard)" %}

```bash
pkill -TERM opera
sleep 2
rm -rf ~/.opera/chaindata           # or ~/.vinuchain/chaindata if using that path

# Restart the node from upgraded binary
nohup $HOME/vinuchain-upgrade/build/opera \
  --validator.id YOUR_VALIDATOR_ID \
  --validator.pubkey 0xYOUR_PUBKEY \
  --validator.password /path/to/password.txt \
  > validator.log &

# Node will resync from genesis — this can take hours to days
```

{% endtab %}

{% tab title="Systemd" %}

```bash
sudo systemctl stop opera
rm -rf ~/.vinuchain/chaindata       # or ~/.opera/chaindata on legacy path
sudo systemctl start opera
# Node will resync from genesis — this can take hours to days
```

{% endtab %}

{% tab title="Docker" %}

```bash
docker stop opera
docker run --rm -v opera_chaindata:/chaindata \
  busybox rm -rf /chaindata/chaindata
docker start opera
# Node will resync from genesis — this can take hours to days
```

{% endtab %}
{% endtabs %}

If the VinuChain team publishes a database snapshot, importing it is
much faster than a genesis resync.

### What if not enough validators upgrade?

{% hint style="warning" %}
The network requires **2/3+ of stake-weighted validators** to produce
blocks. If too few validators upgrade before the epoch seal, the chain
stalls until enough validators catch up. There is no automatic
rollback — the only path forward is upgrading.
{% endhint %}

- The epoch seal still triggers on upgraded validators.
- If upgraded validators hold 2/3+ stake, the chain continues normally.
- If they do not, the chain stalls until enough validators upgrade.

---

## Breaking Changes for RPC Consumers

Infrastructure that queries the node's RPC (indexers, explorers, dApps)
should review the changes introduced by this release:
[Elemont Hard Fork — RPC Breaking Changes](chain-upgrade-rpc-breaking-changes.md).

---

## Contact

If you encounter issues during the upgrade, reach out to the VinuChain
team through the official coordination channels.

---

*Last updated: 2026-04-10 · VinuChain commit `2baf08b` · Tag `v1.0.1-elemont`*
