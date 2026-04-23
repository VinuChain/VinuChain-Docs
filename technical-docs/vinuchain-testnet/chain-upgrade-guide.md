# Chain Upgrade Guide (v2-elemont)

{% hint style="info" %}
**Latest release:** v2.0.11-elemont (scaffolding; awaiting Cycle-160 bytecode compile)
{% endhint %}

{% hint style="info" %}
**TL;DR**

* **Target tag:** `v2.0.11-elemont` (scaffolding pushed on branch `feat/sfc-v2-patch4-scaffolding`; not yet tagged — tag will be cut after the Cycle-160 bytecode lands)
* **Binary version string:** `2.0.11-elemont`
* **Build requirements:** Go 1.25+, C compiler, \~50 GB free disk
* **Fresh testnet genesis:** [vitainu-genesis-testnet-20260419.g](https://vinu-blockchain-genesis.s3.amazonaws.com/vitainu-genesis-testnet-20260419.g) (SHA256 `a541d761e5db846b84c5bf0eef9aa09f45246254a2876ab0f8caf0b47b32e0d9`, ~450 MB, history baked through epoch ~5637 / block ~1.42M — recognized as trusted preset under v2.0.9+, no `--genesis.allowExperimental` required). **Fresh-install operators should restore from the v2.0.11 post-seal chaindata snapshot** (to be published once v2.0.11 seals on live testnet) — required because the fresh-from-genesis replay path diverges on the first `SfcV2Patch*` seal. Until v2.0.11 is tagged, the v2.0.10 snapshot at `testnet-chaindata-v2.0.10-*.tar.gz` remains the correct bootstrap for operators still on v2.0.10.
* **New on testnet:** one-shot `SfcV2Patch4` upgrade flag that re-flashes the SFC bytecode at `0xFC00FACE...` with the Cycle-160 build. Fires once at the next epoch seal after a v2.0.11 binary boot.
{% endhint %}

{% hint style="warning" %}
**Patch release semantics.** v2.0.11-elemont supersedes v2.0.10-elemont. Adds **one new consensus flag** (`SfcV2Patch4`, testnet only) that re-flashes on-chain SFC bytecode at a single epoch seal. Mainnet rules are unchanged.

**What's new in v2.0.11-elemont:** Fixes the SFC lock-end-time bug in `_lockStake` / `relockStake`. The Cycle-159 bytecode installed by `SfcV2Patch3` checked `require(lockupDuration >= ld.duration)` when processing a relock, which compared the **new duration** against the **original lock duration**. That let a staker who had locked for 365 days and waited 340 days silently shorten their effective lock by relocking for 40 days (the new duration was less than the old duration, so the require failed and forced them to relock for at least the original 365 — but a staker who had already WAITED 340 days now had to commit an additional 365 to relock, even though their remaining lock was only 25 days). The Cycle-160 bytecode changes the check to `require(endTime >= ld.endTime)`, so the invariant becomes "you cannot shorten the absolute lock END TIME" — a 40-day relock that ends later than the currently-locked 25-day remaining period is now allowed.

**Current scaffolding state:** The v2.0.11-elemont binary ships with a `deadbeef` placeholder bytecode in `opera/contracts/sfc/sfc_patch4_bytecode.go`. A startup/activation guard (`validatePatch4Bytecode`) `log.Crit`s if the placeholder has not been replaced with a real compiled Cycle-160 SFC. The sequence from here is (1) merge `VinuChain/vinuchain-lists` PR #2, (2) compile the resulting SFC.sol with solc `0.5.17+commit.d19bba13`, `--optimize`, `--optimize-runs=10000`, `--evm-version=istanbul`, (3) replace `patch4PlaceholderBytecode` with the real compile and drop the `deadbeef` sentinel guard, (4) tag `v2.0.11-elemont`, (5) publish the post-seal chaindata snapshot. Operators must not deploy `v2.0.11-elemont` binaries until the tag is cut.

**Mainnet impact:** None at the consensus level. Mainnet has not yet activated `SfcV2` / `SfcV2Patch` / `SfcV2Patch2` / `SfcV2Patch3`, and the Cycle-160 bytecode (once compiled) will be installed directly when mainnet first activates `SfcV2` — no separate `SfcV2Patch4` activation is required on mainnet.
{% endhint %}

{% hint style="warning" %}
**Patch release semantics.** v2.0.10-elemont supersedes v2.0.9-elemont. Adds **one new consensus flag** (`SfcV2Patch3`, testnet only) that re-flashes on-chain SFC bytecode at a single epoch seal. Mainnet rules are unchanged.

**What's new in v2.0.10-elemont:** Fixes the SFC inline reentrancy guard. The Cycle-158 bytecode installed by `SfcV2Patch2` required `_reentrancyGuardCounter == 1` in the `nonReentrant` modifier, but that storage slot was appended to SFC after the contract was genesis-deployed at `0xFC00FACE...`, so the slot is `0` on-chain. `initialize()` is `initializer`-gated and cannot re-run after an evmwriter bytecode patch to populate the slot. The observable effect: **every `nonReentrant` entrypoint** — `delegate`, `undelegate`, `withdraw`, `claimRewards`, `restakeRewards`, `stashRewards`, `createValidator`, plus four admin paths — **reverted with `"ReentrancyGuard: reentrant call"` on the first external call**. The Cycle-159 bytecode installed by `SfcV2Patch3` relaxes the guard to `_reentrancyGuardCounter < 2` at all 11 inlined modifier sites: state `0` (never-written) and `1` (initialized) both count as "not entered", while `2` still means "actively entered" and any value `≥ 2` still reverts to fail closed on storage corruption. The post-body write normalises `0 → 1`, so after the first successful guarded call on each contract instance the standard OZ 1/2 pattern resumes.

**Byte-diff vs Cycle-158:** exactly the 11 guard sites (one `EQ 1` pattern flipped to `LT 2` per inlined site) plus the 32-byte Solidity bzzr metadata hash. Same solc settings (`0.5.17+commit.d19bba13`, `--optimize --optimize-runs=10000 --evm-version=istanbul`).

**Mainnet impact:** None at the consensus level. Mainnet has not yet activated `SfcV2` / `SfcV2Patch` / `SfcV2Patch2`, and the Cycle-159 bytecode will be installed directly when mainnet first activates `SfcV2` — no separate `SfcV2Patch3` activation is required on mainnet.

**If you are already on v2.0.9-elemont:** straight binary swap. No datadir reset, no peer reconnection, no new validator registration. After restart, at the next epoch seal the validator logs will show `Re-applying SFC V2 bytecode upgrade (patch 3)` exactly once — that is the seal-time activation. No further action required.

**Fresh install from genesis:** the distributed testnet genesis `vitainu-genesis-testnet-20260419.g` pre-dates `SfcV2Patch3`. A fresh-install node replaying from that genesis will seal `SfcV2`, `SfcV2Patch`, `SfcV2Patch2`, **and `SfcV2Patch3`** all at its first epoch seal — at a replay block different from the live chain's historical activation points — producing a `wrong event epoch hash` divergence against live peers. **Restore from the v2.0.10 post-seal chaindata snapshot** (`s3://vinu-blockchain-genesis/chaindata-snapshots/testnet-chaindata-v2.0.10-*.tar.gz`) to bypass the replay entirely and join at tip. The prior v2.0.8 chaindata snapshot is stale under v2.0.10 rules and must not be used.

**What's new in v2.0.9-elemont:** Adds a trusted-preset `AllowedOperaGenesis` entry recognizing the fresh 2026-04-19 testnet genesis export (`vitainu-genesis-testnet-20260419.g`). Operators doing fresh installs from that genesis no longer need `--genesis.allowExperimental` and no longer see the `SECURITY WARNING: Genesis file doesn't refer to any trusted preset` line on startup. Existing-datadir operators (those who already have chaindata) do not need to upgrade to v2.0.9 — v2.0.8 is functionally equivalent for them. **The 2024-06-21 testnet genesis (`vitainu-genesis-testnet-20240621.g`) is archived and must not be used for fresh installs under v2.0.8+** — it pre-dates `SfcV2` / `SfcV2Patch` / `SfcV2Patch2` and produces a `wrong event epoch hash` divergence on replay.

**What's new in v2.0.9-elemont:** Adds a trusted-preset `AllowedOperaGenesis` entry recognizing the fresh 2026-04-19 testnet genesis export (`vitainu-genesis-testnet-20260419.g`). Operators doing fresh installs from that genesis no longer need `--genesis.allowExperimental` and no longer see the `SECURITY WARNING: Genesis file doesn't refer to any trusted preset` line on startup. Existing-datadir operators (those who already have chaindata) do not need to upgrade to v2.0.9 — v2.0.8 is functionally equivalent for them. **The 2024-06-21 testnet genesis (`vitainu-genesis-testnet-20240621.g`) is archived and must not be used for fresh installs under v2.0.8+** — it pre-dates `SfcV2` / `SfcV2Patch` / `SfcV2Patch2` and produces a `wrong event epoch hash` divergence on replay.

**What's new in v2.0.8-elemont:** A targeted hotfix to `validatePeerProgress` in the gossip sync handler. v2.0.7's `validatePeerProgress` rejected any peer whose `ProgressMsg` reported an epoch more than 1,000 ahead of local, or a block more than 5,000 ahead. The cap was added as a Round-2 audit-finding guard, but it had no downstream DoS benefit (opera's `lightCheck` and `epochcheck.ErrNotRelevant` already gate event acceptance on epoch equality, so a peer lying about progress advances no state). The side effect was that **any validator that went offline long enough to fall more than 1,000 epochs behind tip rejected every live peer on the handshake** and could never rejoin — the stale node's log would show `Looking for peers peercount=1 tried=N` with `tried` climbing and `last_id` never advancing; the live-peer's log would show the stale node being dropped with `Removing p2p peer req=true err="subprotocol error" duration=~175ms` every ~30 s. v2.0.8 removes both drift caps and the unused constants, keeps the structural `progress.Epoch == 0` check, and restores the ability for a long-offline validator to catch up without a chaindata wipe. There are no consensus changes, no receipt or event format changes, no RPC additions, and no epoch-seal activation.

**If you are already on v2.0.7-elemont:** the upgrade is a straight binary swap. No datadir reset, no peer reconnection, no new validator registration, no epoch-seal wait. After the restart, a stale node resumes normal sync forward to tip.

**If you are already on v2.0.6-elemont:** v2.0.8-elemont also carries the per-peer event-processing quota fix introduced in v2.0.7 (see [§ v2.0.7-elemont Additions](chain-upgrade-rpc-breaking-changes.md#v207-elemont-additions)). v2.0.6's caps of 200 DAG events / 100 stream items per peer were smaller than a single legitimate sync chunk (`DefaultChunkItemsNum = 500`), so catch-up chunks were rejected with `Peer exceeded event processing quota`. v2.0.7 raised both caps to 3,250, matching `DagProcessor.EventsBufferLimit.Num`.

**If you are still on v2.0.5-elemont:** v2.0.8-elemont also carries the `vc_getPaybackBalance` JSON-RPC method introduced in v2.0.6 (rate-limited by a process-wide semaphore: 8 in-flight, 2 s acquire timeout, rejection code `-32005`). See [Elemont — RPC Breaking Changes → v2.0.6-elemont Additions](chain-upgrade-rpc-breaking-changes.md#v206-elemont-additions).

**If you are still on v2.0.4-elemont or earlier:** v2.0.8-elemont also carries the `SfcV2Patch2` flag introduced in v2.0.5 (testnet only). `SfcV2Patch2` installs the current Cycle-158 SFC bytecode at `0xFC00FACE00000000000000000000000000000000`, replacing the older b7ab5b5-era bytecode that was stuck on testnet. It fires once at the next epoch seal after a v2.0.5+ binary is first installed. Mainnet is unaffected — this flag is not set in mainnet rules.
{% endhint %}

{% hint style="info" %}
**Version string vs git tag.** The release is cut from git tag `v2.0.8-elemont`, but the binary reports `2.0.8-elemont`. Both refer to the same release; the leading `v` only appears on the git tag.
{% endhint %}

## Network Details

| Network | Chain ID   | RPC                              | Status          |
| ------- | ---------- | -------------------------------- | --------------- |
| Mainnet | 207 (0xcf) | `https://vinuchain-rpc.com`      | Upgrade pending |
| Testnet | 206 (0xce) | `https://vinufoundation-rpc.com` | Upgrade first   |

***

## Timeline

1. **Testnet upgrade** — genesis validators upgrade testnet nodes first.
2. **Testnet validation** — manual testing for stability (blocks, transactions, RPC endpoints, staking operations). Verify SFC contract at `0xFC00FACE00000000000000000000000000000000` is now verifiable on the explorer after the first post-upgrade epoch seal.
3. **Mainnet upgrade announcement** — date and time window communicated to all validators. Date: TBD — operator to schedule.
4. **Mainnet pre-staging** — validators build the binary ahead of time.
5. **Mainnet upgrade window** — binary swap within the announced window.
6. **Monitoring** — watch for clean resume of block production.

***

## Prerequisites

### Build requirements

* **Go 1.25+** (check with `go version`)
* **gcc (or clang)** and standard C library headers — required for building go-vinu's crypto and LevelDB C bindings.
* **git**
* At least **50 GB** free disk space

### Required Ports

Ensure these remain open in your firewall:

| Port  | Protocol | Purpose                             |
| ----- | -------- | ----------------------------------- |
| 5050  | TCP/UDP  | P2P networking                      |
| 18545 | TCP      | HTTP JSON-RPC (if exposing RPC)     |
| 18546 | TCP      | WebSocket JSON-RPC (if exposing WS) |

***

## Upgrade Steps

{% stepper %}
{% step %}

### Stop your node

{% hint style="warning" %}
**Clean shutdown required.** Do **not** force-kill the process. A hard kill during block processing can corrupt the LevelDB chaindata and force a full resync.
{% endhint %}

{% tabs %}
{% tab title="nohup (standard)" %}

```bash
pkill -TERM opera
```

If the process doesn't exit cleanly within \~10 seconds, check the logs. `pkill` sends SIGTERM by default, allowing graceful shutdown. Only use `pkill -KILL opera` as a last resort if the process is stuck.
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
Send `Ctrl+C` (SIGINT) to the foreground process and wait for it to exit cleanly. In tmux/screen, attach first, then send the interrupt.
{% endtab %}
{% endtabs %}

Verify the process has exited:

```bash
pgrep -f opera || echo "Stopped"
```

{% endstep %}

{% step %}

#### Download and build the new binary

Pick a persistent path with at least \~2GB free for the source tree, the Go module cache, and the resulting `~38MB` binary. Either `$HOME` or a system path like `/opt` works — choose whichever lives on a partition with headroom (mainnet operators with large chaindata may prefer `/opt` or another volume so the build doesn't compete with `$HOME` for space). Avoid `/tmp`: some Linux distributions clear it on reboot, which would wipe a pre-staged build.

The build directory is independent of your node's `--datadir`. The build process never reads or writes chain data, so a build that runs out of space fails cleanly without affecting the running node.

{% code title="Build the release tag" overflow="wrap" %}

```bash
git clone https://github.com/VinuChain/VinuChain.git $HOME/vinuchain-upgrade
cd $HOME/vinuchain-upgrade
git checkout v2.0.8-elemont
make opera
# Binary is at $HOME/vinuchain-upgrade/build/opera
```

{% endcode %}

Substitute `/opt/vinuchain-upgrade` (or any other path) if `$HOME` is not the right partition for your setup — every later command in this guide that references `$HOME/vinuchain-upgrade` should be adjusted to match.

{% hint style="info" %}
**`go.mod` pins unchanged.** The `v2.0.8-elemont` tag uses the same go-vinu `v1.20.14-quota` and lachesis-base `v0.1.6-elemont` pins as v2.0.4 and v2.0.5. `git checkout v2.0.8-elemont` pulls in the correct pins, and `make opera` fetches dependencies on first build.
{% endhint %}
{% endstep %}

{% step %}

#### Verify the new binary

The newly-built binary is at `vinuchain-upgrade/build/opera`. Move into that directory so the rest of the steps can use a relative `./opera` path:

```bash
cd $HOME/vinuchain-upgrade/build
./opera version
# Expected: Version: 2.0.8-elemont
```

{% hint style="info" %}
`opera version` prints `2.0.8-elemont` — this matches the git tag `v2.0.8-elemont`. See the note at the top of this page.
{% endhint %}
{% endstep %}

{% step %}

#### Start your node

{% tabs %}
{% tab title="nohup (standard)" %}
From the build directory you `cd`'d into in the previous step, start the node:

```bash
cd $HOME/vinuchain-upgrade/build

nohup ./opera \
  --bootnodes "enode://e2a95c1b8d85b018b8e88133bec342801b42e19b59a52e030462d04a5549f02fc57215b4ca97771ec6b3a0d30a78603fdccd2b5091c44f6ac439d6c8be8bc539@44.239.129.39:3000,enode://7a45d086b9c82bd3677a76d36e003b9490066d56b612f33d05cb4d242212acd4e5cab4abbcb15a0df9aa499e41b4b4e868d82ba1c509c1990c9217dfe4607775@44.239.129.39:3001,enode://d8e37eeba79b2c52dcba6e396ff907f27a6a8f7db34528cb8636bc3271291657a01c5649bff53429cea8a23b03fac13a178813c34c6d17d14f7b810a988393b5@44.239.129.39:3002,enode://3f15b5ac22dea3e37a90cd9378cf0cd4ed9ea122851846c8108fcc7d2c7e709ea4a089cf3da93c0d3d3053250417cf0ea9ad9eff0aa77ff07d76b6cf267a2937@44.239.129.39:3003" \
  --validator.id YOUR_VALIDATOR_ID \
  --validator.pubkey 0xYOUR_PUBKEY \
  --validator.password /absolute/path/to/password.txt \
  > validator.log &
```

The `--bootnodes` value above lists all four live testnet validators at `44.239.129.39` (ports 3000–3003). Use them as-is — they are the same enodes hardcoded into the binary's testnet defaults and will give a new or restarted node a working entrypoint into the peer mesh.

{% hint style="warning" %}
**Always use full absolute paths for `--validator.password` (and any other file flags).** Because we `cd`'d into `vinuchain-upgrade/build` before running `./opera`, opera's working directory is now `build/`. Any relative path you pass — `pw.txt`, `./pw.txt`, `secrets/pw.txt` — is resolved against `build/`, **not** against your home directory or wherever your real password file lives.

Examples:

* Password file in your home secrets directory: `--validator.password /home/ubuntu/secrets/pw.txt`
* **Even if the password file is inside the build folder**, write the full absolute path: `--validator.password $HOME/vinuchain-upgrade/build/pw.txt`

Never rely on `./pw.txt` or a bare `pw.txt` — it's the easiest way to end up with `Failed to unlock validator key: open pw.txt: no such file or directory` and waste an upgrade window debugging path resolution.

The same rule applies to `--datadir`, `--genesis`, and any other flag that takes a path.
{% endhint %}

Monitor the logs:

```bash
tail -f validator.log
```

**Optional flags** (add only if you were using them before):

* `--datadir /custom/path` — if chain data is not in the default `~/.opera` location

{% hint style="danger" %}
**`--nat extip:YOUR_PUBLIC_IP` is effectively required, not optional.**

Without `--nat`, opera advertises its enode at `ip=127.0.0.1` in the peer discovery table. The symptom is almost indistinguishable from a successful start:

* Process runs fine, logs scroll normally
* `New local node record` line shows `ip=127.0.0.1 udp=… tcp=…`
* `admin.peers` returns one or zero entries
* `net.peerCount == 1`, and that peer is usually an unrelated node stuck on an old epoch
* `New DAG summary` reports `age=15h…` or older — your node has caught up to the single stale peer and halted, because no other peer can dial you back

The fix is to pass `--nat extip:<your_public_ipv4>` on every launch. After restart, verify the startup log shows your real public IP:

```
INFO New local node record  seq=… id=… ip=<YOUR_PUBLIC_IP> udp=3000 tcp=3000
```

If you do not know your public IPv4, `curl -s ifconfig.me` from the node host is the simplest check. Hosting providers like Hetzner, OVH, and AWS all give each instance a routable IPv4 you can copy verbatim into `--nat extip:`.
{% endhint %}

{% hint style="info" %}
**Slow peer discovery on small networks?** On a small or freshly restarted testnet, discv5 discovery via `--bootnodes` can take several minutes to populate the peer table — and may fail entirely if the bootnode itself is restarting at the same time. The most reliable fix is to drop a `static-nodes.json` file inside `<datadir>/go-opera/` that lists every peer enode you want a persistent connection to. Opera reads it on every startup and dials those peers immediately, bypassing discovery.

```bash
mkdir -p $HOME/.vinuchain/go-opera
cat > $HOME/.vinuchain/go-opera/static-nodes.json <<'EOF'
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

Ensure your `docker run` command (or compose file) still mounts the datadir volume and exposes the same ports.
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

* `--datadir /path/to/chaindata` — if chain data is in a custom location (default: `~/.opera`)
{% endtab %}
{% endtabs %}
{% endstep %}

{% step %}

#### Verify the upgrade

What to expect:

**Startup banner.** Every v2.x build prints the VinuChain banner. This is the first visual confirmation that you are running v2.0.8-elemont and not the previous binary:

```text
 ██╗   ██╗██╗███╗   ██╗██╗   ██╗ ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
 ██║   ██║██║████╗  ██║██║   ██║██╔════╝██║  ██║██╔══██╗██║████╗  ██║
 ██║   ██║██║██╔██╗ ██║██║   ██║██║     ███████║███████║██║██╔██╗ ██║
 ╚██╗ ██╔╝██║██║╚██╗██║██║   ██║██║     ██╔══██║██╔══██║██║██║╚██╗██║
  ╚████╔╝ ██║██║ ╚████║╚██████╔╝╚██████╗██║  ██║██║  ██║██║██║ ╚████║
   ╚═══╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

                        v2.0  -  ELEMONT

  Version: 2.0.8-elemont
```

**Staging log (testnet only, first-time `SfcV2Patch2` install).** If you are upgrading from v2.0.4-elemont (never ran v2.0.5+), you will see on first boot:

```text
INFO Staged SfcV2Patch2 upgrade from binary rules; will activate at next epoch seal
```

This confirms the flag is pending. If you do not see this line, either you are running a pre-v2.0.5 binary (`opera version` check), or the flag has already been sealed in a prior v2.0.5/v2.0.6 boot on this datadir.

Mainnet nodes, and any testnet node that already sealed the patch on a prior v2.0.5/v2.0.6 boot, will not show this line.

**No new activation logs on v2.0.5 → v2.0.6 → v2.0.7 upgrades.** v2.0.8-elemont adds no consensus flags. A node moving between any of v2.0.5 / v2.0.6 / v2.0.7 will not print any `Staged ... upgrade` lines — this is expected.

**Seal-time activation (testnet only).** At the next epoch seal after the staging log appears, you will see:

```text
INFO Re-applying SFC V2 bytecode upgrade (patch 2)   block=<N>
```

This is the one-time bytecode installation. After this fires, the SFC contract at `0xFC00FACE00000000000000000000000000000000` contains the current Cycle-158 bytecode and can be verified on the testnet explorer using the current SFC source at [`vinuchain-lists/contracts/vinuchain/SFC.sol`](https://github.com/VinuChain/vinuchain-lists/blob/main/contracts/vinuchain/SFC.sol) (ABI alongside at `SFC_abi.json`).

#### Verification checklist

| Check                                                         | Expected                                                                            |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Startup banner                                                | `VINUCHAIN v2.0 - ELEMONT` ASCII art printed to stderr                              |
| `opera version`                                               | `Version: 2.0.8-elemont`                                                            |
| Block production                                              | Resumes within seconds of startup; block numbers advance                            |
| Peer count                                                    | Returns to prior steady-state within minutes                                        |
| Staging log (testnet, first v2.0.5+ boot from older binary)   | 1× `Staged SfcV2Patch2 upgrade from binary rules; will activate at next epoch seal` |
| Staging log (v2.0.5 → v2.0.6 upgrade, or mainnet, or testnet already sealed patch2) | None                                                                     |
| Seal-time log (testnet, first epoch seal after staging)       | 1× `Re-applying SFC V2 bytecode upgrade (patch 2)   block=<N>`                     |
| SFC verification on testnet explorer (after seal)             | `vinuchain-lists/contracts/vinuchain/SFC.sol` with solc 0.5.17 verifies successfully |
| Block hash vs peer                                            | Identical                                                                           |
| `rpc_modules` returns                                         | Includes `"vc":"1.0"` (new namespace with `vc_getPaybackBalance`)                   |
| `vc_getPaybackBalance` call                                   | Returns hex-encoded wei (or `0x0` for ineligible addresses / Podgorica inactive)    |

{% endstep %}

{% step %}

#### Verify you're on the correct chain

Confirm your node is on the same chain as the network:

```bash
curl -s -X POST http://localhost:18545/ \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' \
  | jq -r '"Block \(.result.number | tonumber): \(.result.hash)"'
```

Compare the block number and hash against the public RPC or another validator's node. If they match, you are on the correct chain.
{% endstep %}

{% step %}

#### Clean up rollback artifacts

If you kept a copy of your previous `opera` binary (or any other upgrade-related files) outside the scope of this guide, you can delete them once your validator has been running cleanly on the new binary for at least one full epoch and you've confirmed the chain hash matches in the previous step.

```bash
# Example — adapt to wherever you stashed the old binary
rm -f /path/to/opera.v2.0.4-elemont
```

The build directory under `$HOME/vinuchain-upgrade` can also be removed if you don't plan to rebuild locally.
{% endstep %}
{% endstepper %}

***

## Setting Up a New Validator

{% hint style="info" %}
New validator setup is **not** covered on this page. If you are installing a fresh validator for the first time rather than upgrading an existing one, follow the dedicated guide: [Become a Validator](../nodes-and-validators/become-a-validator.md).

That guide uses the correct `opera validator new` command for generating a validator key. A plain `opera account new` creates a regular externally-owned account, not a validator key.
{% endhint %}

***

## Rollback

Because v2.0.8-elemont is a patch release and not a hard fork, rollback is straightforward:

1. Stop the node (clean shutdown).
2. Replace `opera` with the v2.0.6-elemont (or v2.0.5-elemont) release binary.
3. Start the node.

No datadir changes are needed.

{% hint style="info" %}
**v2.0.8 → v2.0.7 rollback:** The only functional difference is that `validatePeerProgress` re-applies its drift caps (`maxPeerEpochDrift=1000`, `maxPeerBlockDrift=5000`). This is safe as long as the node is not offline long enough to fall past those caps; an offline stretch beyond ~1,000 epochs on v2.0.7 will lock the node out of re-peering (the bug v2.0.8 fixes). Consensus state, receipts, and block hashes are identical between the two versions.

**v2.0.7 → v2.0.6 rollback:** The only functional difference is the per-peer event-processing quota reverts to its smaller value, so the `Peer exceeded event processing quota` warning storm returns during sync. Consensus state, receipts, and block hashes are identical between the two versions.

**v2.0.6 → v2.0.5 rollback:** The only functional difference is the loss of the `vc_getPaybackBalance` RPC endpoint. Consensus state, receipts, and block hashes are identical between the two versions.
{% endhint %}

{% hint style="info" %}
**Testnet note:** Once `SfcV2Patch2` has sealed on testnet (first introduced in v2.0.5), the SFC bytecode change is permanent in chain state — rolling back the binary to v2.0.4 or earlier does not revert the contract bytecode. This is expected behavior; the bytecode update is the intended outcome of the upgrade.
{% endhint %}

***

## Troubleshooting

### Node won't start after upgrade

1. Check logs: `journalctl -u opera -f` (systemd) or the Docker / terminal output for your install method.
2. Verify the binary version is correct: `opera version` must print `2.0.8-elemont`.
3. If the database is reported as corrupted, stop the node, delete the chaindata directory, and re-sync from a published snapshot (or from genesis if no snapshot is available).

### Node starts but doesn't produce events

1. Confirm your validator key is accessible and `--validator.password` points to the right file.
2. Check that `--validator.id` and `--validator.pubkey` match your on-chain validator registration.
3. Ensure your node has peers: the logs should show incoming / outgoing peer connections. An isolated node cannot produce events.

### "Database is from a newer version" error

This should not occur on a v2.0.4-elemont → v2.0.8-elemont or v2.0.5-elemont → v2.0.8-elemont upgrade because the chain schema has not changed across these releases.

### Consensus stall / no new blocks

v2.0.8-elemont does not change consensus rules — the only additions since v2.0.5 are RPC-side (`vc_getPaybackBalance` and its concurrency cap, from v2.0.6) and a node-internal per-peer quota resize (v2.0.7). `SfcV2Patch2`, carried forward from v2.0.5, only modifies contract bytecode state, not block validation. A stall after upgrading a single node is almost certainly local (peering, disk, or key-loading) rather than network-wide.

### `WARN Incoming event rejected ... err="wrong event epoch hash"`

Your node's locally-computed epoch state hash does not match what the rest of the network has for that epoch boundary. Every event validators emit carries the hash of the previous epoch's state (`PrevEpochHash`); the check lives in `gossip/c_event_callbacks.go` and rejects any event whose `PrevEpochHash` differs from the local store's `EpochState.Hash()`. There is no protocol-level recovery; chaindata must be replaced with a snapshot that matches canonical testnet state.

{% hint style="danger" %}
**Do not resync from genesis.** Under v2.0.10-elemont, a fresh replay from any testnet genesis file (`vitainu-genesis-testnet-20240621.g`, `vitainu-genesis-testnet-20260419.g`, or any older distribution) stages all four upgrade flags (`SfcV2`, `SfcV2Patch`, `SfcV2Patch2`, `SfcV2Patch3`) from binary rules and fires them all at the first epoch seal of the replay. That seal happens at a replay block different from the live chain's historical activation points, so your locally-computed epoch state hash will not match live — your first event from any live peer then rejects with "wrong event epoch hash". Use the v2.0.10 chaindata snapshot below instead; it was captured after `SfcV2Patch3` sealed on the live testnet and is the only supported bootstrap path for v2.0.10 operators. The prior v2.0.8 chaindata snapshot is stale under v2.0.10 rules and must not be used.
{% endhint %}

**Recovery procedure (testnet) — chaindata snapshot:**

1. Stop opera cleanly (`pkill -TERM opera` or `systemctl stop opera`).
2. **Back up your validator identity.** Copy `<datadir>/keystore/` and `<datadir>/go-opera/nodekey` somewhere safe before deleting anything. These are your validator key material — losing them means losing validator identity on-chain.
3. Delete the stale chaindata in place (keeping keystore + nodekey):

   ```bash
   cd <datadir>
   rm -rf chaindata history
   # if go-opera/ contains anything other than nodekey, clear everything else:
   find go-opera -mindepth 1 -not -name nodekey -not -name 'static-nodes.json' -not -name 'trusted-nodes.json' -exec rm -rf {} +
   ```

4. Download the latest testnet snapshot and extract it in-place over the datadir (the tar is written with relative paths, so extract at the datadir root; the tar excludes `nodekey`, `keystore/`, `opera.ipc`, `static-nodes.json`, `trusted-nodes.json` so your identity files are preserved):

   ```bash
   cd <datadir>
   curl -LO https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.10-20260419T153040Z.tar.gz
   # verify integrity
   curl -L https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.10-20260419T153040Z.tar.gz.sha256 | sha256sum -c -
   tar -xzf testnet-chaindata-v2.0.10-20260419T153040Z.tar.gz
   rm testnet-chaindata-v2.0.10-20260419T153040Z.tar.gz
   ```

   Direct HTTPS URL (public, no AWS credentials required):

   ```
   https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.10-20260419T153040Z.tar.gz
   ```

   SHA256: `9b5dafecbb73f19a77e8ed4653007851ae6ba9d30398cfaf89abc5b594130ac2`. Size: approximately 2.3 GiB compressed (2,497,048,978 bytes). Published 2026-04-20 from the canonical testnet trace node at block ~1.42M / epoch ~5637, taken **after** `SfcV2Patch3` sealed so it is the correct bootstrap for v2.0.10 binaries. New snapshots are published under `s3://vinu-blockchain-genesis/chaindata-snapshots/` — pick the most recent v2.0.10-or-newer snapshot for the shortest catch-up. The bucket is public-read; `aws s3 ls s3://vinu-blockchain-genesis/chaindata-snapshots/` works with any AWS credentials or via `curl https://vinu-blockchain-genesis.s3.amazonaws.com/?list-type=2&prefix=chaindata-snapshots/` with none.

5. Ensure `--nat extip:<your_public_ip>` is set and `<datadir>/go-opera/static-nodes.json` contains the canonical bootnode list from the [Start your node](#start-your-node) section.
6. Restart opera. The node resumes from the snapshot's tip (~epoch 5637 at snapshot time) and syncs forward. Expect `New DAG summary age=<few seconds>` within 1-2 minutes of restart.

### Stuck at `net.peerCount == 1` with one stale peer

Symptom: `admin.peers` shows exactly one peer on a prior opera version, frozen at an old epoch. Your node catches up to that single peer's last block and then stops advancing.

This almost always means your enode record is advertising `127.0.0.1` (no peers outside that one random discovery hit can dial you back). Fix:

1. Confirm the startup log line `New local node record  ... ip=…` — if `ip=127.0.0.1`, `--nat extip` is missing.
2. Stop opera, add `--nat extip:<your_public_ipv4>` to the launch command, ensure `static-nodes.json` lists the canonical testnet bootnodes (see the [Start your node](#start-your-node) section), and restart.
3. Within a few minutes `net.peerCount` should be 4+ and `age` on `New DAG summary` lines should drop into the second / millisecond range.

If the peer count stays stuck at 1 after fixing `--nat`, check your host firewall / cloud security group: TCP and UDP on your `--port` (default 3000) must be open to `0.0.0.0/0`.

### `vc_getPaybackBalance` returns `-32005`

The RPC-safe payback accessor is gated by a process-wide semaphore (8 in-flight, 2 s acquire timeout). Error code `-32005` is the rate-limit rejection. Clients should retry with exponential backoff; operators running high-volume scanners should either spread load across multiple RPC endpoints or reduce concurrent caller count. See [RPC Breaking Changes → v2.0.6-elemont Additions](chain-upgrade-rpc-breaking-changes.md#v206-elemont-additions).

***

## Coordinated Upgrade Procedure

The recommended procedure is to upgrade within a bounded window so that the validator set converges quickly on the hardened binary:

1. **VinuChain team announces the patch window.** Date: TBD — operator to schedule.
2. **Pre-stage the binary** on every validator server before the window. See step 2 of the Upgrade Steps above.
3. **During the window**, each operator performs the binary swap (Upgrade Steps 1 → 5) at their own pace.
4. **Confirm in the coordination channel** that your node resumed block production cleanly after restart and that `opera version` reports `2.0.8-elemont`.

### Recovering a node that missed the window

Because non-upgraded nodes remain consensus-compatible with the network under v2.0.8-elemont (no new consensus flags since v2.0.5), a node that missed the window is **not** forked off. Upgrading at any later point is a plain binary swap.

{% tabs %}
{% tab title="nohup (standard)" %}

```bash
pkill -TERM opera
sleep 2

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

***

For the prior elemont hard-fork RPC changes (introduction of the `feeRefund` field, 30% base fee burn accounting, payback refund mechanics), see [Elemont Hard Fork — RPC Breaking Changes](chain-upgrade-rpc-breaking-changes.md).

***

## Contact

If you encounter issues during the upgrade, reach out to the VinuChain team through the official channels.

***

_Last updated: 2026-04-19 · VinuChain tag `v2.0.8-elemont` (published) · go-vinu `v1.20.14-quota` · lachesis-base `v0.1.6-elemont`_
