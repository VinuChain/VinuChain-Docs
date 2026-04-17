# VinuChain v2.0.3-elemont — Validator Upgrade Guide

{% hint style="info" %}
**Recommended security patch release.** v2.0.3-elemont is a rollup of
audit-driven hardening fixes on top of v2.0.2-elemont. It is **not** a
new hard fork — no new upgrade flags activate, and non-upgraded nodes
remain consensus-compatible with the network. However, non-upgraded
nodes miss the P2P, RPC, and SFC audit fixes shipped in this release,
so all validators are strongly encouraged to upgrade.
{% endhint %}

{% hint style="info" %}
**TL;DR**

- **Target tag:** `v2.0.3-elemont` (preparing — not yet published)
- **Binary version string:** `2.0.3-elemont`
- **Mandatory:** no, but strongly recommended
- **Activation:** binary swap only. No new hard fork, no coordinated
  block height, no datadir reset
- **Expected downtime:** 2–10 minutes per validator for a clean swap
- **Build requirements:** Go 1.25+, C compiler, ~50 GB free disk
  (unchanged from v2.0.2-elemont)
- **Upgrade window:** TBD — operator to schedule
{% endhint %}

{% hint style="warning" %}
**Patch release semantics.** v2.0.3-elemont supersedes v2.0.2-elemont.
The upgrade flags already active on your node from the v2.0.2-elemont
rollout (`Podgorica`, `SfcV2`, `Elemont`) remain active — this release
does not add or toggle any consensus flag. On **testnet**, if the
`SfcV2Patch` flag from v2.0.2-elemont was not yet applied on your node
(e.g. the node had been stopped since before its next epoch seal), it
will still fire on the first epoch seal after restart. Once applied, it
is a no-op on subsequent restarts.

**If you are already on v2.0.2-elemont:** the upgrade is a straight
binary swap. No datadir reset, no peer reconnection, no new validator
registration. Follow the same steps below as you did for
v2.0.2-elemont. You will not see any `Staged ... upgrade from binary
rules` log lines, because no new flags need staging — the banner and a
clean resume of block processing are your confirmation.
{% endhint %}

{% hint style="info" %}
**Version string vs git tag.** The release is cut from git tag
`v2.0.3-elemont`, but the binary reports `2.0.3-elemont`. Both refer to
the same release; the leading `v` only appears on the git tag.
{% endhint %}

## What's New in v2.0.3-elemont

v2.0.3-elemont rolls up hardening work from audit Cycles 152–157. The
changes fall into three surfaces — VinuChain core, the forked go-vinu
EVM/RPC dependency, and the pre-deployment SFC V2 contract.

### VinuChain core (this repo)

| Scope | Change |
| --- | --- |
| `evm/gas_power` | Saturate `GasRefund` addition in the gas power check to prevent uint64 overflow when a block accumulates a very large refund. |
| `gossip/gasprice` | Saturate `DirtyGasRefund` additions in the gas price oracle backend (same overflow class as above). |
| `evm/gas_power` | Clamp `prevGasPowerLeft` to `maxGasPower` in `CalcValidatorGasPower` as defense-in-depth against `MaxUint64` sentinel values leaking through the allocation path. |
| `gossip/blockproc` | New unit tests for `evmmodule` and `sealmodule`. Test-only; no runtime behavior change. |

### go-vinu fork (EVM + RPC)

v2.0.3-elemont **requires** a new go-vinu tag `v1.20.14-quota`. The
VinuChain `go.mod` replace directive is bumped from
`v1.20.13-quota` → `v1.20.14-quota` and must be in place before the
release is cut.

| Scope | Change |
| --- | --- |
| `rpc/ethapi` | Reject `StateOverride.Code` blobs larger than `MaxCodeSize`. Prevents `eth_call` clients from forcing a node to allocate unbounded contract code. |
| `rpc` | Enforce a 100-request ceiling on JSON-RPC batch calls. Caps per-batch fan-out work. |
| `rpc` | Cap `StateOverride.StateDiff` entry count at 1000. Symmetric with the code-size cap above. |
| `rpc` | `DefaultConfig.MaxConcurrentRPC` set to 50. Provides a sane default for operators who don't override the setting. |
| `rpc` | Return a JSON-RPC error (instead of hanging) when `startCallProc` runs while the handler is stopping. |
| `core/types/receipt` | Cap peer-decoded `FeeRefund` at 32 bytes, zero pre-Podgorica receipts, and restore test state. |
| `core/types/receipt` | Use `BitLen` for the `FeeRefund` size check instead of a byte-slice comparison. |
| `core/types` | New test coverage for `FeeRefundActive` transition paths. |

### SFC V2 contract (pre-deployment bytecode)

The SFC V2 Solidity source in `gitignore/sfc_fixed.sol` received a batch
of correctness and precision fixes during Cycles 152–157. Because the
V2 bytecode is **pre-deployment** — no network has yet locked it in via
a binary that ships with V2 baked into the binary rules — networks that
activate SfcV2 from v2.0.3-elemont onward will install the corrected
bytecode directly.

| Finding | Change |
| --- | --- |
| SFC-01 | `updateSlashingRefundRatio` now uses a 2-day `CORRECTION_TIMELOCK` with explicit queue / execute / cancel (was applied immediately). |
| SFC-01-B | Converted the pending-slashing-refund slot into a per-validator `mapping(uint256 => PendingSlashingRefund)` (was a single global slot that could collide across validators). |
| SFC-02 | `queueMigration` and `queueCopyCode` now revert if a pending op is already queued, preventing silent overwrite. |
| SFC-03 | `_calcRawValidatorEpochTxReward` now multiplies before dividing — preserves precision on small per-epoch reward increments. |
| SFC-04 | `nonReentrant` guard checks the counter `== 1` (was `!= 2`), which is the semantically correct assertion. |
| C157-L01 | `_popDelegationUnlockPenalty` rescales stashed reward deductions at the penalty cap so a capped penalty no longer leaves stash inconsistent. |
| C157-I01 / I02 | NatSpec documenting the cancel-requeue cooldown asymmetry and the genesis stashed-lockup seed. Documentation-only. |
| C157-I03 | Cumulative correction delta cap to prevent compound drift across many corrections. |

**Implication for existing testnet networks:** the `SfcV2Patch` re-flash
path introduced in v2.0.2-elemont is **unchanged** by this release.
Testnet nodes that already applied `SfcV2Patch` under v2.0.2-elemont do
not re-flash again under v2.0.3-elemont. New testnets or mainnet
activations that install SfcV2 from a v2.0.3-elemont (or later) binary
will pick up the corrected bytecode on first activation.

{% hint style="warning" %}
**Go bindings regeneration required before tag.** The SFC bytecode in
`opera/contracts/sfc/sfc_predeploy.go` is a compiled artifact of
`gitignore/sfc_fixed.sol`. Because the Solidity source changed, the Go
bindings must be regenerated with **`solc` 0.5.17** before the
`v2.0.3-elemont` tag is cut. Post-regeneration the bytecode size will
change — the exact new size is TBD until regeneration is complete.
{% endhint %}

### Changelog since v2.0.2-elemont

VinuChain-repo commits since `v2.0.2-elemont` (oldest first):

| Commit | Scope | Summary |
| --- | --- | --- |
| `a894112` | `evm/gas_power` | Saturate `GasRefund` addition to prevent uint64 overflow |
| `293fe5f` | `gossip/gasprice` | Saturate `DirtyGasRefund` additions in gas price oracle |
| `7487dd5` | `evm/gas_power` | Clamp `prevGasPowerLeft` to `maxGasPower` in `CalcValidatorGasPower` |
| `20e1951` | `gossip/blockproc` | Add `evmmodule` and `sealmodule` unit tests |

go-vinu commits that land in `v1.20.14-quota`:

| Commit | Scope | Summary |
| --- | --- | --- |
| `b6557ea7f` | `rpc/ethapi` | Reject oversized `StateOverride.Code` blobs |
| `565b48267` | `rpc` | Enforce 100-request JSON-RPC batch ceiling |
| `827040f3a` | `core/types/receipt` | Cap peer `FeeRefund` at 32 bytes, zero pre-Podgorica |
| `f8c5baea7` | `core/types/receipt` | Use `BitLen` for `FeeRefund` size check |
| `f6eed37c9` | `rpc` | `MaxConcurrentRPC=50` default in `DefaultConfig` |
| `38a713d64` | `rpc` | Cap `StateOverride.StateDiff` entry count at 1000 |
| `787061f3e` | `rpc` | Return JSON-RPC error on `startCallProc` when stopping |
| `b316aee38` | `core/types` | Test coverage for `FeeRefundActive` transition paths |

lachesis-base remains pinned at `v0.1.5-elemont` — no changes since
v2.0.2-elemont.

## What Is This Upgrade?

v2.0.3-elemont is a **security patch release**. It does not activate
any new upgrade flags on VinuChain and does not change consensus
behavior. Block hashes produced by an upgraded and a non-upgraded node
on the same transactions remain identical.

### Features Activated

None. The three flags already active from the elemont hard fork
(`Podgorica`, `SfcV2`, `Elemont`) continue to apply. On testnet,
`SfcV2Patch` continues to re-flash the SFC V2 bytecode at the first
post-restart epoch seal if it has not already been applied on the
node — this behavior is unchanged from v2.0.2-elemont.

### Why Upgrade?

Upgrading picks up:

- **P2P and RPC hardening** — batch caps, state-override caps, concurrent
  RPC default, and receipt decoding limits that reduce the blast radius
  of hostile or misbehaving peers and clients.
- **Overflow defense in the gas-power accounting path** — saturating
  addition and clamping in `CalcValidatorGasPower` and the gas price
  oracle backend prevent edge-case uint64 overflows that could have
  disrupted gas power allocation for a validator.
- **Corrected SFC V2 bytecode for new network activations** — the eight
  pre-deployment fixes above are baked into any new SfcV2 activation
  after this release.

### Network Details

| Network | Chain ID   | RPC                              | Status          |
|---------|------------|----------------------------------|-----------------|
| Mainnet | 207 (0xcf) | `https://vinuchain-rpc.com`      | Upgrade pending |
| Testnet | 206 (0xce) | `https://vinufoundation-rpc.com` | Upgrade first   |

---

## Timeline

1. **Testnet upgrade** — genesis validators upgrade testnet nodes first.
2. **Testnet validation** — manual testing for stability (blocks,
   transactions, RPC endpoints, staking operations).
3. **Mainnet upgrade announcement** — date and time window communicated
   to all validators. Date: TBD — operator to schedule.
4. **Mainnet pre-staging** — validators build the binary ahead of time.
5. **Mainnet upgrade window** — binary swap within the announced window.
6. **Monitoring** — watch for clean resume of block production.

---

## Prerequisites

### Build requirements

Unchanged from v2.0.2-elemont:

- **Go 1.25+** (check with `go version`)
- **gcc (or clang)** and standard C library headers — required for
  building go-vinu's crypto and LevelDB C bindings.
- **git**
- At least **50 GB** free disk space
- Current node must be **fully synced** before upgrading

{% hint style="info" %}
If you already built v2.0.2-elemont on this host and have not changed
the Go toolchain since, no build-environment changes are needed for
v2.0.3-elemont. The `go.mod` bump to `go-vinu v1.20.14-quota` is
fetched transparently by `make opera`.
{% endhint %}

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

### Download and build the new binary

Pick a persistent path with at least ~2GB free for the source tree, the
Go module cache, and the resulting `~38MB` binary. Either `$HOME` or a
system path like `/opt` works — choose whichever lives on a partition
with headroom (mainnet operators with large chaindata may prefer `/opt`
or another volume so the build doesn't compete with `$HOME` for space).
Avoid `/tmp`: some Linux distributions clear it on reboot, which would
wipe a pre-staged build.

The build directory is independent of your node's `--datadir`. The
build process never reads or writes chain data, so a build that runs
out of space fails cleanly without affecting the running node.

{% code title="Build the release tag" overflow="wrap" %}

```bash
git clone https://github.com/VinuChain/VinuChain.git $HOME/vinuchain-upgrade
cd $HOME/vinuchain-upgrade
git checkout v2.0.3-elemont
make opera
# Binary is at $HOME/vinuchain-upgrade/build/opera
```

{% endcode %}

Substitute `/opt/vinuchain-upgrade` (or any other path) if `$HOME` is
not the right partition for your setup — every later command in this
guide that references `$HOME/vinuchain-upgrade` should be adjusted to
match.

{% hint style="info" %}
**`go.mod` bump included in the tag.** The `v2.0.3-elemont` tag bumps
the go-vinu replace directive to `v1.20.14-quota`. You do not need to
edit `go.mod` manually — `git checkout v2.0.3-elemont` pulls in the
correct pin, and `make opera` fetches the new dependency on first
build. lachesis-base remains at `v0.1.5-elemont`.
{% endhint %}

{% endstep %}

{% step %}

### Verify the new binary

The newly-built binary is at `vinuchain-upgrade/build/opera`. Move into
that directory so the rest of the steps can use a relative `./opera`
path:

```bash
cd $HOME/vinuchain-upgrade/build
./opera version
# Expected: Version: 2.0.3-elemont
```

{% hint style="info" %}
`opera version` prints `2.0.3-elemont` — this matches the git tag
`v2.0.3-elemont`. See the note at the top of this page.
{% endhint %}

{% endstep %}

{% step %}

### Start your node

{% tabs %}
{% tab title="nohup (standard)" %}

From the build directory you `cd`'d into in the previous step, start
the node:

```bash
cd $HOME/vinuchain-upgrade/build

nohup ./opera \
  --bootnodes "enode://e2a95c1b8d85b018b8e88133bec342801b42e19b59a52e030462d04a5549f02fc57215b4ca97771ec6b3a0d30a78603fdccd2b5091c44f6ac439d6c8be8bc539@44.239.129.39:3000,enode://7a45d086b9c82bd3677a76d36e003b9490066d56b612f33d05cb4d242212acd4e5cab4abbcb15a0df9aa499e41b4b4e868d82ba1c509c1990c9217dfe4607775@44.239.129.39:3001,enode://d8e37eeba79b2c52dcba6e396ff907f27a6a8f7db34528cb8636bc3271291657a01c5649bff53429cea8a23b03fac13a178813c34c6d17d14f7b810a988393b5@44.239.129.39:3002,enode://3f15b5ac22dea3e37a90cd9378cf0cd4ed9ea122851846c8108fcc7d2c7e709ea4a089cf3da93c0d3d3053250417cf0ea9ad9eff0aa77ff07d76b6cf267a2937@44.239.129.39:3003" \
  --validator.id YOUR_VALIDATOR_ID \
  --validator.pubkey 0xYOUR_PUBKEY \
  --validator.password /absolute/path/to/password.txt \
  > validator.log &
```

The `--bootnodes` value above lists all four live testnet validators at
`44.239.129.39` (ports 3000–3003). Use them as-is — they are the same
enodes hardcoded into the binary's testnet defaults and will give a new
or restarted node a working entrypoint into the peer mesh.

{% hint style="warning" %}
**Always use full absolute paths for `--validator.password` (and any
other file flags).** Because we `cd`'d into `vinuchain-upgrade/build`
before running `./opera`, opera's working directory is now `build/`.
Any relative path you pass — `pw.txt`, `./pw.txt`, `secrets/pw.txt` —
is resolved against `build/`, **not** against your home directory or
wherever your real password file lives.

Examples:

- Password file in your home secrets directory:
  `--validator.password /home/ubuntu/secrets/pw.txt`
- **Even if the password file is inside the build folder**, write the
  full absolute path:
  `--validator.password $HOME/vinuchain-upgrade/build/pw.txt`

Never rely on `./pw.txt` or a bare `pw.txt` — it's the easiest way to
end up with `Failed to unlock validator key: open pw.txt: no such file
or directory` and waste an upgrade window debugging path resolution.

The same rule applies to `--datadir`, `--genesis`, and any other flag
that takes a path.
{% endhint %}

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

### Verify the upgrade

Because v2.0.3-elemont is **not a hard fork**, most nodes will see no
`Staged ... upgrade from binary rules` lines at startup. What to expect:

**Startup banner.** Every v2.x build prints the VinuChain banner. This
is the first visual confirmation that you are running v2.0.3-elemont
and not the previous binary:

```text
 ██╗   ██╗██╗███╗   ██╗██╗   ██╗ ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
 ██║   ██║██║████╗  ██║██║   ██║██╔════╝██║  ██║██╔══██╗██║████╗  ██║
 ██║   ██║██║██╔██╗ ██║██║   ██║██║     ███████║███████║██║██╔██╗ ██║
 ╚██╗ ██╔╝██║██║╚██╗██║██║   ██║██║     ██╔══██║██╔══██║██║██║╚██╗██║
  ╚████╔╝ ██║██║ ╚████║╚██████╔╝╚██████╗██║  ██║██║  ██║██║██║ ╚████║
   ╚═══╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

                        v2.0  -  ELEMONT

  Version: 2.0.3-elemont
```

**Staging logs — conditional.** For most operators upgrading from
v2.0.2-elemont there are **no new flags to stage**, and you will not
see any `Staged ...` lines. The exception is the testnet-only
`SfcV2Patch` flag: if your node never completed an epoch seal under
v2.0.2-elemont (for example the node was stopped before its first
post-upgrade seal), the patch is still pending and will log:

```text
INFO Staged SfcV2Patch upgrade from binary rules; will activate at next epoch seal
```

If the patch already applied on your node under v2.0.2-elemont, this
line does **not** appear.

**Seal-time activation — conditional.** Only relevant to testnet nodes
that still have `SfcV2Patch` pending. At the next epoch seal on such a
node you will see:

```text
INFO Re-applying SFC V2 bytecode upgrade (patch)   block=<N>
```

For all other nodes (including all mainnet nodes) the upgrade is
complete as soon as the node resumes producing/processing events under
the new binary.

#### Verification checklist

| Check | Expected |
| --- | --- |
| Startup banner | `VINUCHAIN  v2.0 - ELEMONT` ASCII art printed to stderr |
| `opera version` | `Version: 2.0.3-elemont` |
| Block production | Resumes within seconds of startup; block numbers advance |
| Peer count | Returns to prior steady-state within minutes |
| Staging log (testnet, SfcV2Patch still pending) | 1× `Staged SfcV2Patch upgrade from binary rules; will activate at next epoch seal` |
| Staging log (v2.0.2-elemont already fully sealed, or mainnet) | None |
| Block hash vs peer | Identical |

{% endstep %}

{% step %}

### Verify you're on the correct chain

Confirm your node is on the same chain as the network:

```bash
curl -s -X POST http://localhost:18545/ \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' \
  | jq -r '"Block \(.result.number | tonumber): \(.result.hash)"'
```

Compare the block number and hash against the public RPC or another
validator's node. If they match, you are on the correct chain.
{% endstep %}

{% step %}

### Clean up rollback artifacts

If you kept a copy of your previous `opera` binary (or any other
upgrade-related files) outside the scope of this guide, you can delete
them once your validator has been running cleanly on the new binary for
at least one full epoch and you've confirmed the chain hash matches in
the previous step.

Because v2.0.3-elemont is not a hard fork, rollback to v2.0.2-elemont
is technically possible at any time — but it is also pointless once the
new binary is running healthy, and keeping stale binaries around just
consumes disk and risks confusing future operators.

```bash
# Example — adapt to wherever you stashed the old binary
rm -f /path/to/opera.v2.0.2-elemont
```

The build directory under `$HOME/vinuchain-upgrade` (or wherever you
cloned the source) can also be removed if you don't plan to rebuild
locally — the running node uses the binary that was already started, so
deleting the source tree has no effect on it.
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

Because v2.0.3-elemont is a patch release and not a hard fork, rollback
is straightforward:

1. Stop the node (clean shutdown).
2. Replace `/usr/local/bin/opera` (or your image) with the
   v2.0.2-elemont release binary.
3. Start the node.

No datadir changes are needed. The node resumes from the same state
under the older binary. You will miss the audit fixes shipped in this
release, so rollback should only be used if v2.0.3-elemont exhibits an
unexpected regression on your node.

{% hint style="info" %}
On testnet nodes where `SfcV2Patch` has already applied: the patch
install is a one-time state change that persists in chain state
regardless of which binary is running. Rolling back the binary does
not un-patch the SFC V2 bytecode.
{% endhint %}

---

## Troubleshooting

### Node won't start after upgrade

1. Check logs: `journalctl -u opera -f` (systemd) or the Docker /
   terminal output for your install method.
2. Verify the binary version is correct: `opera version` must print
   `2.0.3-elemont`.
3. If the database is reported as corrupted, stop the node, delete the
   chaindata directory, and re-sync from a published snapshot (or from
   genesis if no snapshot is available). See the late-upgrade recovery
   section below for the exact commands.

### Node starts but doesn't produce events

1. Confirm your validator key is accessible and `--validator.password`
   points to the right file.
2. Check that `--validator.id` and `--validator.pubkey` match your
   on-chain validator registration.
3. Ensure your node has peers: the logs should show incoming / outgoing
   peer connections. An isolated node cannot produce events.

### "Database is from a newer version" error

This should not occur on a v2.0.2-elemont → v2.0.3-elemont upgrade
because the chain schema has not changed between these releases. If
you see it, you are likely attempting to downgrade past v2.0.2-elemont
(a hard-fork boundary) — see that release's upgrade guide for the
correct downgrade procedure below that boundary.

### Consensus stall / no new blocks

v2.0.3-elemont does not change consensus rules, so a stall after
upgrading a single node is almost certainly local (peering, disk, or
key-loading) rather than network-wide. If the full network stops
producing blocks independently of your upgrade, contact the VinuChain
team via the official coordination channel.

---

## Coordinated Upgrade Procedure

Because v2.0.3-elemont is a security patch release and not a hard
fork, upgrades do **not** need to be coordinated across validators.
Each operator can restart their node on the new binary independently at
any time.

The recommended procedure is still to upgrade within a bounded window
so that the validator set converges quickly on the hardened binary:

1. **VinuChain team announces the patch window.** Date: TBD — operator
   to schedule.
2. **Pre-stage the binary** on every validator server before the
   window. See step 2 of the Upgrade Steps above.
3. **During the window**, each operator performs the binary swap
   (Upgrade Steps 1 → 5) at their own pace.
4. **Confirm in the coordination channel** that your node resumed block
   production cleanly after restart and that `opera version` reports
   `2.0.3-elemont`.

### Recovering a node that missed the window

Because non-upgraded nodes remain consensus-compatible with the network
under v2.0.3-elemont, a node that missed the window is **not** forked
off. It is simply running the older binary with the older set of audit
fixes. Upgrading at any later point is a plain binary swap:

{% tabs %}
{% tab title="nohup (standard)" %}

```bash
pkill -TERM opera
sleep 2  # Give the process time to exit

# Restart using the upgraded binary
cd $HOME/vinuchain-upgrade/build
nohup ./opera \
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
# Rebuild and retag as shown in the build step
docker start opera
```

{% endtab %}
{% endtabs %}

There is no separate "resync from scratch" path for this patch
release — the chain state is unchanged between v2.0.2-elemont and
v2.0.3-elemont, so a clean restart on the new binary is always
sufficient.

---

## Breaking Changes for RPC Consumers

v2.0.3-elemont introduces **defensive RPC caps** that a small number of
high-volume clients may notice:

- **`eth_call` with `stateOverride.code` larger than `MaxCodeSize`** now
  rejects instead of silently accepting. Callers who synthesize arbitrarily
  large contract code in `stateOverride` must shrink it or split calls.
- **JSON-RPC batches larger than 100 requests** now reject at the handler
  boundary. Callers that submit large batches must split them into
  chunks of ≤100.
- **`stateOverride.stateDiff` with more than 1000 entries** now rejects.
  Callers must split large state-diff overrides across multiple calls.
- **Default `MaxConcurrentRPC`** is now 50 if not overridden in config.
  Operators who rely on the previous (unset) default may need to set an
  explicit higher value in their config.
- **RPC receipt output** continues to include the `feeRefund` field
  activated under Podgorica — unchanged from v2.0.2-elemont.

For the prior elemont hard-fork RPC changes (introduction of the
`feeRefund` field, 30% base fee burn accounting, payback refund
mechanics), see
[Elemont Hard Fork — RPC Breaking Changes](chain-upgrade-rpc-breaking-changes.md).

---

## Contact

If you encounter issues during the upgrade, reach out to the VinuChain
team through the official coordination channels.

---

*Last updated: 2026-04-17 · VinuChain tag `v2.0.3-elemont` (preparing) ·
go-vinu `v1.20.14-quota` · lachesis-base `v0.1.5-elemont`*
