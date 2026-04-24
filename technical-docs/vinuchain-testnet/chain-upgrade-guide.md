# Chain Upgrade Guide (v2-elemont)

{% hint style="info" %}
**Latest release:** v2.0.11-elemont (tagged 2026-04-23; deployed to testnet RPC + 4 validators; `SfcV2Patch4` activates at the next epoch seal)
{% endhint %}

{% hint style="info" %}
**TL;DR**

* **Target tag:** `v2.0.11-elemont` (cut 2026-04-23; contains the real 45,240-byte Cycle-160 SFC runtime bytecode compiled from `VinuChain/vinuchain-lists@eecd660` with solc `0.5.17+commit.d19bba13 --optimize --optimize-runs=10000 --evm-version=istanbul`)
* **Binary version string:** `2.0.11-elemont`
* **Build requirements:** Go 1.25+, C compiler, \~50 GB free disk
* **Fresh testnet genesis:** [vitainu-genesis-testnet-20260419.g](https://vinu-blockchain-genesis.s3.amazonaws.com/vitainu-genesis-testnet-20260419.g) (SHA256 `a541d761e5db846b84c5bf0eef9aa09f45246254a2876ab0f8caf0b47b32e0d9`, ~450 MB, history baked through epoch ~5637 / block ~1.42M — recognized as trusted preset under v2.0.9+, no `--genesis.allowExperimental` required). **Fresh-install operators should restore from the v2.0.11 post-seal chaindata snapshot** (published at [testnet-chaindata-v2.0.11-20260423T151354Z-clean.tar.gz](https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.11-20260423T151354Z-clean.tar.gz), SHA256 `5b19cd392dc6a3ac7d52339a544747bac2132602a1f5c5b229ae3b3ce6736ab4`, 1.24 GB). The tarball is flat — top-level is `chaindata/` and `go-opera/` with no `datadir/` prefix, so `cd <your_datadir> && tar -xzf testnet-chaindata-v2.0.11-20260423T151354Z-clean.tar.gz` drops the directories directly where opera expects them. Fresh replay from genesis is not supported because all four `SfcV2Patch*` flags would fire at the first replay seal and produce a `wrong event epoch hash` divergence against the live chain.
* **New on testnet:** one-shot `SfcV2Patch4` upgrade flag that re-flashes the SFC bytecode at `0xFC00FACE...` with the Cycle-160 build. Fires once at the next epoch seal after a v2.0.11 binary boot.
{% endhint %}

{% hint style="info" %}
**Version string vs git tag.** The release is cut from git tag `v2.0.11-elemont`, but the binary reports `2.0.11-elemont`. Both refer to the same release; the leading `v` only appears on the git tag.
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

```text
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

| Check                                                       | Expected                                                                             |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Startup banner                                              | `VINUCHAIN v2.0 - ELEMONT` ASCII art printed to stderr                               |
| `opera version`                                             | `Version: 2.0.8-elemont`                                                             |
| Block production                                            | Resumes within seconds of startup; block numbers advance                             |
| Peer count                                                  | Returns to prior steady-state within minutes                                         |
| Staging log (testnet, first v2.0.5+ boot from older binary) | 1× `Staged SfcV2Patch2 upgrade from binary rules; will activate at next epoch seal`  |
| Staging log — all other cases (mainnet or sealed testnet)   | None                                                                                 |
| Seal-time log (testnet, first epoch seal after staging)     | 1× `Re-applying SFC V2 bytecode upgrade (patch 2)   block=<N>`                       |
| SFC verification on testnet explorer (after seal)           | `vinuchain-lists/contracts/vinuchain/SFC.sol` with solc 0.5.17 verifies successfully |
| Block hash vs peer                                          | Identical                                                                            |
| `rpc_modules` returns                                       | Includes `"vc":"1.0"` (new namespace with `vc_getPaybackBalance`)                    |
| `vc_getPaybackBalance` call                                 | Returns hex-encoded wei (or `0x0` for ineligible addresses / Podgorica inactive)     |

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

Because v2.0.11-elemont is a patch release and not a hard fork, rollback is straightforward:

1. Stop the node (clean shutdown).
2. Replace `opera` with a prior elemont release binary (e.g., v2.0.10-elemont, v2.0.9-elemont, or earlier).
3. Start the node.

No datadir changes are needed. Consensus state, receipts, and block hashes are identical across every adjacent pair of elemont releases listed below.

{% hint style="info" %}
**Per-version rollback deltas.** Each bullet describes the only functional difference between the two versions.

- **v2.0.11 → v2.0.10 rollback:** Loses the `SfcV2Patch4` staging logic in binary rules and the `sfc.EnforcePatch4StartupCheck` build guard. If `SfcV2Patch4` has already sealed on testnet, the Cycle-160 bytecode at `0xFC00FACE...` persists in chain state (see Testnet note below); the v2.0.10 binary continues to dispatch against it unchanged. The relock invariant remains `endTime >= ld.endTime` because that logic lives in the deployed bytecode, not the binary.
- **v2.0.10 → v2.0.9 rollback:** Loses the `SfcV2Patch3` staging logic. If `SfcV2Patch3` has already sealed, the Cycle-159 reentrancy-guard-fixed bytecode persists in chain state; all `nonReentrant` entrypoints continue to work because the `_reentrancyGuardCounter < 2` check is in the deployed bytecode.
- **v2.0.9 → v2.0.8 rollback:** Loses the trusted-preset entry for `vitainu-genesis-testnet-20260419.g`. Fresh installs on v2.0.8 from that genesis file again require `--genesis.allowExperimental` and print the `SECURITY WARNING: Genesis file doesn't refer to any trusted preset` line on startup; existing datadirs are unaffected.
- **v2.0.8 → v2.0.7 rollback:** `validatePeerProgress` re-applies its drift caps (`maxPeerEpochDrift=1000`, `maxPeerBlockDrift=5000`). Safe as long as the node is not offline long enough to fall past those caps; an offline stretch beyond ~1,000 epochs on v2.0.7 will lock the node out of re-peering (the bug v2.0.8 fixes).
- **v2.0.7 → v2.0.6 rollback:** The per-peer event-processing quota reverts to its smaller value (200 DAG events / 100 stream items), so the `Peer exceeded event processing quota` warning storm returns during sync.
- **v2.0.6 → v2.0.5 rollback:** The `vc_getPaybackBalance` JSON-RPC method disappears. Clients calling it receive `method not found`.
{% endhint %}

{% hint style="warning" %}
**Testnet note — sealed bytecode persists across rollbacks.** Once an `SfcV2Patch*` upgrade flag has sealed on testnet, the bytecode it flashed at `0xFC00FACE00000000000000000000000000000000` is permanent in chain state. Rolling back the binary does **not** revert the installed bytecode:

| Sealed patch  | Introduced in | Testnet seal                 | Installed bytecode                                |
| ------------- | ------------- | ---------------------------- | ------------------------------------------------- |
| `SfcV2Patch2` | v2.0.5        | Mid-v2.0.5 boot              | Cycle-158 SFC (45,240 bytes)                      |
| `SfcV2Patch3` | v2.0.10       | 2026-04-19 · block 1,424,440 | Cycle-159 SFC — inline reentrancy guard fix       |
| `SfcV2Patch4` | v2.0.11       | 2026-04-23 · block 1,430,436 | Cycle-160 SFC — `_lockStake` / `relockStake` fix  |

This is expected behavior — the bytecode update is the intended outcome of each upgrade and cannot be undone by swapping binaries. Reverting installed bytecode would require shipping another epoch-sealed upgrade flag, which is a forward-moving change rather than a rollback.

Mainnet is currently unaffected — no `SfcV2*` flag has sealed on mainnet, so mainnet operators can freely roll back to any elemont binary.
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
**Do not resync from genesis.** Under v2.0.11-elemont, a fresh replay from any testnet genesis file stages every not-yet-sealed `SfcV2*` flag from binary rules and fires them all at the first epoch seal of the replay — at a replay block different from the live chain's historical activation points, so your locally-computed epoch state hash will not match live and your first event from any live peer rejects with `wrong event epoch hash`.

* `vitainu-genesis-testnet-20240621.g` (archived) stages **all five**: `SfcV2`, `SfcV2Patch`, `SfcV2Patch2`, `SfcV2Patch3`, `SfcV2Patch4`.
* `vitainu-genesis-testnet-20260419.g` (current) already has `SfcV2` / `SfcV2Patch` / `SfcV2Patch2` baked into its exported history, so only `SfcV2Patch3` and `SfcV2Patch4` stage and fire together. The diagnostic fingerprint is two log lines at the same replay block before divergence:

  ```text
  INFO Re-applying SFC V2 bytecode upgrade (patch 3) block=<N>
  INFO Re-applying SFC V2 bytecode upgrade (patch 4) block=<N>
  WARN Incoming event rejected event=… err="wrong event epoch hash"
  ```

  On the live chain `SfcV2Patch3` sealed mid-v2.0.10 (2026-04-20) and `SfcV2Patch4` sealed at block 1,430,436 (2026-04-23) — two different seal blocks — so co-firing them at a single replay block produces a divergent SFC bytecode state and breaks `EpochState.Hash()` parity.

Use the v2.0.11 chaindata snapshot below instead; it was captured **after** `SfcV2Patch4` sealed on the live testnet and is the only supported bootstrap path for v2.0.11 operators. The prior v2.0.10 chaindata snapshot is stale under v2.0.11 rules and must not be used.
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
   curl -LO https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.11-20260423T151354Z-clean.tar.gz
   # verify integrity
   curl -L https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.11-20260423T151354Z-clean.tar.gz.sha256 | sha256sum -c -
   tar -xzf testnet-chaindata-v2.0.11-20260423T151354Z-clean.tar.gz
   rm testnet-chaindata-v2.0.11-20260423T151354Z-clean.tar.gz
   ```

   **Sanity-check the extraction before restarting opera.** Every published snapshot has a companion `SNAPSHOT_INFO.txt` with the exact tip block and sealed upgrade-flag state at snapshot time. Snapshots published from 2026-04-24 onwards include the file at the tarball root (so it lands in your datadir automatically on extraction). Older snapshots — including the current v2.0.11 — have it published only as an out-of-band companion in S3. Either way, read it before starting opera:

   ```bash
   # If the tarball included it, it's in your datadir:
   cat <datadir>/SNAPSHOT_INFO.txt 2>/dev/null \
     || curl -sL https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.11-20260423T151354Z-clean.SNAPSHOT_INFO.txt
   ```

   If the `cat` succeeds, the snapshot loaded correctly and the tip block listed in `SNAPSHOT_INFO.txt` is the minimum block number your first `New block` log line should show after restart. If neither the `cat` nor the `curl` returns anything, something is wrong with the extraction or network — do not start opera yet.

   Direct HTTPS URL (public, no AWS credentials required):

   ```text
   https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.11-20260423T151354Z-clean.tar.gz
   ```

   SHA256: `5b19cd392dc6a3ac7d52339a544747bac2132602a1f5c5b229ae3b3ce6736ab4`. Size: approximately 1.24 GiB compressed (1,243,197,032 bytes). Published 2026-04-24 from the canonical testnet trace node at block ~1.43M / epoch ~5637, taken **after** `SfcV2Patch4` sealed so it is the correct bootstrap for v2.0.11 binaries. The tarball is flat (top-level is `chaindata/` and `go-opera/` — no `datadir/` prefix to nest) and excludes `nodekey`, `keystore/`, `opera.ipc`, `static-nodes.json`, `trusted-nodes.json`, the archived `chaindata.bak.*/` from the pre-LevelDB-FSH migration, and any shell `history` file. New snapshots are published under `s3://vinu-blockchain-genesis/chaindata-snapshots/` — pick the most recent `-clean` snapshot for the shortest catch-up. The bucket is public-read; `aws s3 ls s3://vinu-blockchain-genesis/chaindata-snapshots/` works with any AWS credentials or via `curl https://vinu-blockchain-genesis.s3.amazonaws.com/?list-type=2&prefix=chaindata-snapshots/` with none.

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

The RPC-safe payback accessor is gated by a process-wide semaphore (8 in-flight, 2 s acquire timeout). Error code `-32005` is the rate-limit rejection. Clients should retry with exponential backoff; operators running high-volume scanners should either spread load across multiple RPC endpoints or reduce concurrent caller count. See [Changelog → Payback Fee Refunds](#payback-fee-refunds).

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

## Contact

If you encounter issues during the upgrade, reach out to the VinuChain team through the official channels.

***

## Changelog

This section consolidates release-specific change notes, JSON-RPC surface changes, consensus behaviors, and migration guidance for the Elemont upgrade series. It also documents JSON-RPC behavior that affects infrastructure consuming the node's interface — indexers, block explorers, dApps, and anything that parses transaction receipts, tracks supply, or uses the `eth_*` / `debug_*` / `trace_*` namespaces.

### Patch Release Semantics

{% hint style="warning" %}
**Patch release semantics.** v2.0.11-elemont supersedes v2.0.10-elemont. Adds **one new consensus flag** (`SfcV2Patch4`, testnet only) that re-flashes on-chain SFC bytecode at a single epoch seal. Mainnet rules are unchanged.

**What's new in v2.0.11-elemont:** Fixes the SFC lock-end-time bug in `_lockStake` / `relockStake`. The Cycle-159 bytecode installed by `SfcV2Patch3` checked `require(lockupDuration >= ld.duration)` when processing a relock, which compared the **new duration** against the **original lock duration**. That let a staker who had locked for 365 days and waited 340 days silently shorten their effective lock by relocking for 40 days (the new duration was less than the old duration, so the require failed and forced them to relock for at least the original 365 — but a staker who had already WAITED 340 days now had to commit an additional 365 to relock, even though their remaining lock was only 25 days). The Cycle-160 bytecode changes the check to `require(endTime >= ld.endTime)`, so the invariant becomes "you cannot shorten the absolute lock END TIME" — a 40-day relock that ends later than the currently-locked 25-day remaining period is now allowed.

**Cycle-160 bytecode integrity.** The tagged release inlines the real 45,240-byte Cycle-160 runtime bytecode in `opera/contracts/sfc/sfc_patch4_bytecode.go`, compiled from `VinuChain/vinuchain-lists@eecd660 contracts/vinuchain/SFC.sol`. The ABI is byte-identical to Cycle-159 (123 functions + 39 events, zero selector additions or removals); the byte-diff is concentrated in ~335 optimizer-reshuffle regions plus the 32-byte bzzr metadata hash. A binary startup guard (`sfc.EnforcePatch4StartupCheck`, wired from `cmd/opera/launcher/patch4_startup_check.go:init()`) rejects and `log.Crit`s on any invalid Patch4 asset — sentinel-prefixed, under-size, all-zero, or byte-identical to Patch3 — so a build that accidentally shipped a placeholder refuses to start. A v2.0.11 binary that passes `./build/opera version` is guaranteed to carry a real compile.

**Mainnet impact:** None at the consensus level. Mainnet has not yet activated `SfcV2` / `SfcV2Patch` / `SfcV2Patch2` / `SfcV2Patch3`, and the Cycle-160 bytecode now shipped in v2.0.11 will be installed directly when mainnet first activates `SfcV2` — no separate `SfcV2Patch4` activation is required on mainnet.
{% endhint %}

{% hint style="warning" %}
**Patch release semantics.** v2.0.10-elemont supersedes v2.0.9-elemont. Adds **one new consensus flag** (`SfcV2Patch3`, testnet only) that re-flashes on-chain SFC bytecode at a single epoch seal. Mainnet rules are unchanged.

**What's new in v2.0.10-elemont:** Fixes the SFC inline reentrancy guard. The Cycle-158 bytecode installed by `SfcV2Patch2` required `_reentrancyGuardCounter == 1` in the `nonReentrant` modifier, but that storage slot was appended to SFC after the contract was genesis-deployed at `0xFC00FACE...`, so the slot is `0` on-chain. `initialize()` is `initializer`-gated and cannot re-run after an evmwriter bytecode patch to populate the slot. The observable effect: **every `nonReentrant` entrypoint** — `delegate`, `undelegate`, `withdraw`, `claimRewards`, `restakeRewards`, `stashRewards`, `createValidator`, plus four admin paths — **reverted with `"ReentrancyGuard: reentrant call"` on the first external call**. The Cycle-159 bytecode installed by `SfcV2Patch3` relaxes the guard to `_reentrancyGuardCounter < 2` at all 11 inlined modifier sites: state `0` (never-written) and `1` (initialized) both count as "not entered", while `2` still means "actively entered" and any value `≥ 2` still reverts to fail closed on storage corruption. The post-body write normalises `0 → 1`, so after the first successful guarded call on each contract instance the standard OZ 1/2 pattern resumes.

**Byte-diff vs Cycle-158:** exactly the 11 guard sites (one `EQ 1` pattern flipped to `LT 2` per inlined site) plus the 32-byte Solidity bzzr metadata hash. Same solc settings (`0.5.17+commit.d19bba13`, `--optimize --optimize-runs=10000 --evm-version=istanbul`).

**Mainnet impact:** None at the consensus level. Mainnet has not yet activated `SfcV2` / `SfcV2Patch` / `SfcV2Patch2`, and the Cycle-159 bytecode will be installed directly when mainnet first activates `SfcV2` — no separate `SfcV2Patch3` activation is required on mainnet.

**If you are already on v2.0.9-elemont:** straight binary swap. No datadir reset, no peer reconnection, no new validator registration. After restart, at the next epoch seal the validator logs will show `Re-applying SFC V2 bytecode upgrade (patch 3)` exactly once — that is the seal-time activation. No further action required.

**Fresh install from genesis:** the distributed testnet genesis `vitainu-genesis-testnet-20260419.g` pre-dates `SfcV2Patch3`. A fresh-install node replaying from that genesis will seal `SfcV2`, `SfcV2Patch`, `SfcV2Patch2`, **and `SfcV2Patch3`** all at its first epoch seal — at a replay block different from the live chain's historical activation points — producing a `wrong event epoch hash` divergence against live peers. **Restore from the v2.0.10 post-seal chaindata snapshot** (`s3://vinu-blockchain-genesis/chaindata-snapshots/testnet-chaindata-v2.0.10-*.tar.gz`) to bypass the replay entirely and join at tip. The prior v2.0.8 chaindata snapshot is stale under v2.0.10 rules and must not be used.

**What's new in v2.0.9-elemont:** Adds a trusted-preset `AllowedOperaGenesis` entry recognizing the fresh 2026-04-19 testnet genesis export (`vitainu-genesis-testnet-20260419.g`). Operators doing fresh installs from that genesis no longer need `--genesis.allowExperimental` and no longer see the `SECURITY WARNING: Genesis file doesn't refer to any trusted preset` line on startup. Existing-datadir operators (those who already have chaindata) do not need to upgrade to v2.0.9 — v2.0.8 is functionally equivalent for them. **The 2024-06-21 testnet genesis (`vitainu-genesis-testnet-20240621.g`) is archived and must not be used for fresh installs under v2.0.8+** — it pre-dates `SfcV2` / `SfcV2Patch` / `SfcV2Patch2` and produces a `wrong event epoch hash` divergence on replay.

**What's new in v2.0.8-elemont:** A targeted hotfix to `validatePeerProgress` in the gossip sync handler. v2.0.7's `validatePeerProgress` rejected any peer whose `ProgressMsg` reported an epoch more than 1,000 ahead of local, or a block more than 5,000 ahead. The cap was added as a Round-2 audit-finding guard, but it had no downstream DoS benefit (opera's `lightCheck` and `epochcheck.ErrNotRelevant` already gate event acceptance on epoch equality, so a peer lying about progress advances no state). The side effect was that **any validator that went offline long enough to fall more than 1,000 epochs behind tip rejected every live peer on the handshake** and could never rejoin — the stale node's log would show `Looking for peers peercount=1 tried=N` with `tried` climbing and `last_id` never advancing; the live-peer's log would show the stale node being dropped with `Removing p2p peer req=true err="subprotocol error" duration=~175ms` every ~30 s. v2.0.8 removes both drift caps and the unused constants, keeps the structural `progress.Epoch == 0` check, and restores the ability for a long-offline validator to catch up without a chaindata wipe. There are no consensus changes, no receipt or event format changes, no RPC additions, and no epoch-seal activation.

**If you are already on v2.0.7-elemont:** the upgrade is a straight binary swap. No datadir reset, no peer reconnection, no new validator registration, no epoch-seal wait. After the restart, a stale node resumes normal sync forward to tip.

**If you are already on v2.0.6-elemont:** v2.0.8-elemont also carries the per-peer event-processing quota fix introduced in v2.0.7 (see [Performance & Reliability Improvements](#performance--reliability-improvements)). v2.0.6's caps of 200 DAG events / 100 stream items per peer were smaller than a single legitimate sync chunk (`DefaultChunkItemsNum = 500`), so catch-up chunks were rejected with `Peer exceeded event processing quota`. v2.0.7 raised both caps to 3,250, matching `DagProcessor.EventsBufferLimit.Num`.

**If you are still on v2.0.5-elemont:** v2.0.8-elemont also carries the `vc_getPaybackBalance` JSON-RPC method introduced in v2.0.6 (rate-limited by a process-wide semaphore: 8 in-flight, 2 s acquire timeout, rejection code `-32005`). See [Payback Fee Refunds](#payback-fee-refunds).

**If you are still on v2.0.4-elemont or earlier:** v2.0.8-elemont also carries the `SfcV2Patch2` flag introduced in v2.0.5 (testnet only). `SfcV2Patch2` installs the current Cycle-158 SFC bytecode at `0xFC00FACE00000000000000000000000000000000`, replacing the older b7ab5b5-era bytecode that was stuck on testnet. It fires once at the next epoch seal after a v2.0.5+ binary is first installed. Mainnet is unaffected — this flag is not set in mainnet rules.
{% endhint %}

### Release Overview

{% hint style="info" %}
**`v2.0.10-elemont`** — supersedes v2.0.9-elemont. Testnet-only consensus flag (`SfcV2Patch3`) that re-flashes the on-chain SFC bytecode with the Cycle-159 build to fix the inline reentrancy guard. **No JSON-RPC surface changes**. However, **observable on-chain behavior changes**: every SFC `nonReentrant` entrypoint (`delegate`, `undelegate`, `withdraw`, `claimRewards`, `restakeRewards`, `stashRewards`, `createValidator`) that previously reverted with `"ReentrancyGuard: reentrant call"` now proceeds as designed. See [SFC V2 Contract Upgrade](#sfc-v2-contract-upgrade).

**`v2.0.9-elemont`** — trusted-preset genesis entry only. No RPC, consensus, or receipt changes vs v2.0.8.

**`v2.0.8-elemont`** — node-internal hotfix: removes the peer-progress drift cap in the gossip sync handler that locked out any validator more than 1,000 epochs behind chain tip. No JSON-RPC, consensus, or receipt changes. See [Performance & Reliability Improvements](#performance--reliability-improvements).

**`v2.0.7-elemont`** — node-internal hotfix: raises the per-peer in-flight event-processing quota in the gossip handler so that legitimate sync chunks are no longer rejected with `Peer exceeded event processing quota`. No JSON-RPC, consensus, or receipt changes. See [Performance & Reliability Improvements](#performance--reliability-improvements).

**`v2.0.6-elemont`** — pure RPC addition: the new `vc_getPaybackBalance` method and RPC-safe payback accessor with a process-wide concurrency cap. No consensus or receipt changes. See [Payback Fee Refunds](#payback-fee-refunds).

**`v2.0.5-elemont`** — adds the `SfcV2Patch2` upgrade flag for testnet, which re-flashes SFC bytecode with the current Cycle-158 source. No RPC surface changes. See [SFC V2 Contract Upgrade](#sfc-v2-contract-upgrade).

**`v2.0.4-elemont`** — bumps lachesis-base to `v0.1.6-elemont`; consensus and reliability fixes with no direct RPC consumer impact. Also carries all v2.0.3 defensive RPC caps. See [Performance & Reliability Improvements](#performance--reliability-improvements).

**`v2.0.3-elemont`** — defensive RPC caps (batch size, concurrency, state override) from the upstream `go-vinu v1.20.14-quota` fork. Active immediately on restart. See [JSON-RPC Defensive Caps & Rate Limits](#json-rpc-defensive-caps--rate-limits).
{% endhint %}

{% hint style="warning" %}
**Build requirement (v2.0.2+):** Operators building from source need **Go 1.25+** (up from Go 1.14 on the pre-v2.0.2 branch). See [Prerequisites](#prerequisites).
{% endhint %}

{% hint style="info" %}
**Activation timing.**

- **v2.0.3-elemont caps** (batch size, concurrency, state override): active immediately on restart. Purely a local-node policy, no epoch seal required.
- **v2.0.2-elemont consensus changes** (`feeRefund`, base fee burn, Elemont consensus fixes): activate at the **next epoch seal** after a node first installs a v2.0.2+ binary. On startup you see three `Staged … upgrade from binary rules; will activate at next epoch seal` log lines before block processing resumes. Until the seal fires (up to ~4h after restart — the `MaxEpochDuration` cap; epochs may seal earlier from gas, event count, or cheaters), receipts and fee accounting continue to use pre-upgrade behavior. At the seal the new rules activate atomically on the same block.
- **v2.0.2+ → v2.0.3 / v2.0.4 upgrades**: if your node already sealed an epoch under v2.0.2-elemont, no second activation occurs on v2.0.3 or v2.0.4. The consensus flags are latched; both are pure binary swaps.
- **v2.0.4-elemont lachesis-base bump** (vecengine cap, dagprocessor drain fix, kvdb flushable, semaphore metric, gossip deadlock fix): active immediately on restart. Internal consensus-engine plumbing only — no RPC surface change, no receipt change, no new error responses for consumers.
- **v2.0.5-elemont `SfcV2Patch2`** (testnet only): activates at the **next epoch seal** after a v2.0.5+ binary boots. One-time bytecode installation; no receipt or RPC format change.
- **v2.0.6-elemont `vc_getPaybackBalance`**: active immediately on restart. Registered when the RPC server starts.
- **v2.0.7-elemont per-peer quota resize**: active immediately on restart. No epoch-seal wait, no staging log.
- **v2.0.8-elemont peer-progress drift cap removal**: active immediately on restart. No epoch-seal wait, no staging log.
- **v2.0.10-elemont `SfcV2Patch3`** (testnet only): activates at the **next epoch seal** after a v2.0.10+ binary boots.
- **v2.0.11-elemont `SfcV2Patch4`** (testnet only): activates at the **next epoch seal** after a v2.0.11+ binary boots.
{% endhint %}

---

### New `feeRefund` Field in Transaction Receipts

Transaction receipts now include an optional `feeRefund` field (hex-encoded wei value) for transactions where the sender received a gas fee refund from the payback system. The field is **omitted** when there is no refund, so receipts without an associated refund look identical to pre-upgrade receipts.

{% code title="Example receipt fragment" overflow="wrap" %}

```json
{
  "transactionHash": "0x...",
  "gasUsed": "0x5208",
  "feeRefund": "0x2386f26fc10000"
}
```

{% endcode %}

#### Impact on receipt consumers

- Most JSON parsers silently ignore unknown fields, so this is non-breaking for typical dApp usage.
- If your pipeline performs strict receipt schema validation, update the schema to allow an optional `feeRefund` field (hex string).
- If you compute or compare receipt hashes off-chain, update your encoder to include `feeRefund` when present — the on-chain receipt root includes it once Podgorica is active.

**Source:** the field is emitted by `ethapi/api.go` only when `receipt.FeeRefund` is non-nil, so older nodes continue to return receipts without the field.

The same `feeRefund` key also appears on the transaction object returned by `eth_getTransactionByHash`, `eth_getTransactionByBlockHashAndIndex`, and `eth_getTransactionByBlockNumberAndIndex` — not only on receipts. Clients that read refund amounts off the transaction response (rather than pulling the receipt) should handle it there as well.

A separate defensive cap on the `feeRefund` P2P ingress value (32 bytes / 256-bit integer) is documented under [JSON-RPC Defensive Caps & Rate Limits](#json-rpc-defensive-caps--rate-limits).

---

### SFC V2 Contract Upgrade

Once the SfcV2 upgrade is active, the Staking for Consensus (SFC) smart contract is replaced with the V2 implementation. The upgrade activates at the **next epoch seal** after the binary is installed.

#### Contract bytecode replacement

The on-chain SFC contract at `0xfc00face00000000000000000000000000000000` is rewritten with new bytecode. The V2 contract:

- Maintains **backward compatibility** with existing delegation and staking state — all delegations, stakes, and validator registrations remain valid and functional.
- Updates the logic for fee distribution, rewards calculation, and validator interactions to align with the new fee burn mechanism (see below).
- Does **not** change the function selectors (on-chain ABI) used by the driver contract or internal transactions — dApps and on-chain contracts calling the SFC continue to work without modification.

**Impact on smart contracts:** If your on-chain contract directly reads SFC state (e.g., via `staticCall`), you should verify the call succeeds after the upgrade. Staking, delegation, and withdrawal operations should remain unaffected.

#### `SfcV2Patch2` — Cycle-158 bytecode re-flash (v2.0.5-elemont, testnet only)

v2.0.5-elemont ships the same RPC surface as v2.0.4-elemont; the only addition is the `SfcV2Patch2` upgrade flag (testnet only):

| Scope | Change | Consumer impact |
| --- | --- | --- |
| `SfcV2Patch2` (testnet) | Re-flashes SFC contract bytecode at `0xFC00FACE00000000000000000000000000000000` with current Cycle-158 45,240-byte source at next epoch seal | None for RPC consumers — no new methods, fields, or response shape changes. dApps calling `staticCall` on the SFC will now interact with the corrected bytecode |
| SFC contract verification | After the epoch seal that fires `SfcV2Patch2`, the contract can be verified on testnet explorer using the current SFC source at [`vinuchain-lists/contracts/vinuchain/SFC.sol`](https://github.com/VinuChain/vinuchain-lists/blob/main/contracts/vinuchain/SFC.sol) and solc 0.5.17 | Infrastructure operators running their own Blockscout instance against testnet can now complete contract verification |

**Who is affected:**

- **Most consumers:** No action needed. The receipt format, method selectors, and ABI for SFC external functions are unchanged.
- **dApps relying on SFC internal state:** The corrected bytecode includes Cycle-158 hardening (reentrancyguard fix, slashing refund timelock, precision fixes). Behavior is compatible with all existing delegations and staking state; no migration is needed.
- **Explorer operators:** Blockscout verification against testnet will succeed after the epoch seal fires the patch.

**Activation timing.** `SfcV2Patch2` fires at the **next epoch seal** after a node running v2.0.5-elemont starts. The node logs:

```text
INFO Staged SfcV2Patch2 upgrade from binary rules; will activate at next epoch seal
```

...at startup, and then at the seal:

```text
INFO Re-applying SFC V2 bytecode upgrade (patch 2)   block=<N>
```

Mainnet is unaffected — `SfcV2Patch2` is not set in mainnet rules.

#### `SfcV2Patch3` — Cycle-159 reentrancy guard fix (v2.0.10-elemont, testnet only)

v2.0.10-elemont is a **testnet-only SFC bytecode re-flash** that fixes the inline reentrancy guard in the SFC contract at `0xFC00FACE...`. Mainnet rules are unchanged — mainnet has not yet activated any `SfcV2*` flag, and the Cycle-159 bytecode will be installed directly when mainnet first activates `SfcV2` (no separate `SfcV2Patch3` is required on mainnet).

**What changed.** A new upgrade flag, `SfcV2Patch3`, is set to `true` in testnet rules (`opera/rules.go`). When a v2.0.10 binary boots on a node that has not yet sealed `SfcV2Patch3`, the flag is staged in `DirtyRules` at startup and activates on the next epoch seal. At activation, the block processor re-flashes `sfc.GetContractBin()` (Cycle-159, 45,240 bytes, solc `0.5.17+commit.d19bba13`, `--optimize --optimize-runs=10000 --evm-version=istanbul`) over the existing SFC code at `0xFC00FACE...` via `StateDB.SetCode(...)` — one atomic code swap per node, idempotent across restarts.

**Why (bug and fix).** The Cycle-158 bytecode installed by `SfcV2Patch2` required `_reentrancyGuardCounter == 1` in the inline `nonReentrant` modifier. That storage slot was appended to SFC storage layout **after** the contract was genesis-deployed at `0xFC00FACE...`, so the slot is `0` on-chain. SFC's `initialize()` (which sets the slot to `1`) is gated by OpenZeppelin's `initializer` modifier and cannot re-run after an evmwriter bytecode patch. Net effect: **every SFC `nonReentrant` entrypoint reverted on its first external call** with `"ReentrancyGuard: reentrant call"` — `delegate`, `undelegate`, `withdraw`, `claimRewards`, `restakeRewards`, `stashRewards`, `createValidator`, plus four admin paths.

The Cycle-159 bytecode relaxes the guard to `_reentrancyGuardCounter < 2` at all 11 inlined modifier sites. State `0` (never-written) and `1` (initialized) both count as "not entered"; `2` still means "actively entered" and reverts on reentry; any value `≥ 2` (only possible via a storage-layout collision, e.g. from a future upgrade inheriting OZ `ReentrancyGuard` over the same slot) still reverts to fail closed. The post-body write normalises `0 → 1`, so after the first successful guarded call on each contract instance the standard OZ 1/2 pattern resumes unchanged.

**Byte-diff.** Against the Cycle-158 source: exactly the 11 guard sites (one `EQ 1` pattern flipped to `LT 2` per inlined site) plus the 32-byte Solidity bzzr metadata hash. Same solc version (`0.5.17+commit.d19bba13`), same settings (`--optimize --optimize-runs=10000 --evm-version=istanbul`), same contract length (45,240 bytes).

**Consumer impact.** JSON-RPC surface, ABI, method selectors, event topics, receipt encoding, and batch/concurrency/rate limits are **unchanged from v2.0.9**. Wallets and dApps calling `SFC.delegate(uint256)` etc. will see one observable behavior change: the call now **succeeds** (subject to normal revert conditions like insufficient balance, validator doesn't exist, or amount-below-minimum), instead of reverting universally with `"ReentrancyGuard: reentrant call"` during `eth_call` / `eth_estimateGas` / `eth_sendTransaction`.

The SFC ABI at [vinuchain-lists/contracts/vinuchain/SFC_abi.json](https://github.com/VinuChain/vinuchain-lists/blob/main/contracts/vinuchain/SFC_abi.json) is **byte-identical** to the pre-fix ABI — the modifier change is implementation-only. Downstream consumers (`vinuscan-backend`'s bundled ABI, `vinuexplorer-backend`'s cached ABI, third-party integrators) do not need to re-input or regenerate anything.

**Activation.** The flag stages at startup on any v2.0.10 binary boot and activates at the next epoch seal on the testnet consensus (up to `MaxEpochDuration = 4h` after restart; typically much sooner on an active network). The bytecode swap log line — `"Re-applying SFC V2 bytecode upgrade (patch 3)"` — fires exactly once per node, on the block where the seal commits. On 2026-04-19 testnet this happened at block **1424440** at **14:56:46 UTC** (epoch 5639 → 5640 transition).

**Blockscout verification.** After the re-flash fires, `testnet.vinuexplorer.org` and future `mainnet.vinuexplorer.org` will temporarily show stale bytecode because Blockscout's Elixir indexer never re-fetches `addresses.contract_code` for system-contract addresses whose code is swapped via the evmwriter precompile rather than a `CREATE` tx. A plain re-verify POST accepts (`"verification started"`) but compares against the stale cached bytecode and cannot overwrite the existing `smart_contracts` row. Testnet was re-verified on 2026-04-19 using the standard post-evmwriter recipe: `DELETE` the stale `smart_contracts` row, `UPDATE addresses.contract_code` with fresh `eth_getCode`, then `POST /api/v2/smart-contracts/0xfc00face.../verification/via/flattened-code` with the solc settings above. Mainnet operators will need to repeat the recipe when the Cycle-159 bytecode lands on mainnet via the first `SfcV2` activation.

#### `SfcV2Patch4` — Cycle-160 lock-end-time fix (v2.0.11-elemont, testnet only)

The v2.0.11-elemont release documented in the [Patch Release Semantics](#patch-release-semantics) block above fixes the SFC lock-end-time bug in `_lockStake` / `relockStake`. The Cycle-160 bytecode changes the relock invariant from `require(lockupDuration >= ld.duration)` (compared the **new duration** against the **original duration**) to `require(endTime >= ld.endTime)` (you cannot shorten the absolute lock **end time**). ABI and selectors are byte-identical to Cycle-159 — 123 functions + 39 events with zero additions or removals; the byte-diff is concentrated in ~335 optimizer-reshuffle regions plus the 32-byte bzzr metadata hash.

A binary startup guard (`sfc.EnforcePatch4StartupCheck`, wired from `cmd/opera/launcher/patch4_startup_check.go:init()`) rejects and `log.Crit`s on any invalid Patch4 asset — sentinel-prefixed, under-size, all-zero, or byte-identical to Patch3 — so a build that accidentally shipped a placeholder refuses to start.

**Activation.** At the next epoch seal after a v2.0.11 binary boots. On the 2026-04-23 live testnet, `SfcV2Patch4` sealed at block 1,430,436. Mainnet is unaffected — `SfcV2Patch4` is not set in mainnet rules; the Cycle-160 bytecode will be installed directly when mainnet first activates `SfcV2`.

---

### 30% Base Fee Burn (SfcV2)

Once the SfcV2 upgrade is active, 30% of the **base fee portion** of each transaction's fee is burned. The remaining 70% of the base fee and **all priority tips** are credited to the block's validator as before.

{% hint style="info" %}
**London fork requirement:** The base fee burn only applies if the London upgrade is also active. VinuChain has had London enabled since genesis, so the burn is active immediately when SfcV2 activates. If running on a network without London, the burn does not apply (base fees are not defined).
{% endhint %}

#### Burn mechanism

The burn is calculated **per transaction** at the end of block processing:

```text
baseFeeUsed = baseFee × gasUsed
burnAmount = baseFeeUsed × 30%
(capped at the validator's fee share, so it never exceeds what they'd earn)
validatorEarnings = transactionFee - feeRefund - burnAmount
```

- **Base fee only** — priority tips (miner tips) are never burned; they continue to flow entirely to the validator.
- **Per-block accrual** — the burn happens in the same transaction that credits the validator, not in a separate post-block settlement.
- **Order of operations** — refunds (Podgorica) are calculated first, then the burn is applied to what remains.

#### Impact on reward accounting

- **Validator rewards decrease** — validators receive 70% of base fees instead of 100%, a ~30% reduction in base-fee-derived revenue.
- **Circulating supply decreases** — burned base fees accumulate at the zero address, reducing the effective circulating supply over time.
- **APY recalculation required** — staking APY estimates that assume 100% of fees flow to validators will overstate actual validator returns by ~30% (on base fee components only).
- **Block reward structure** — the burn does not affect priority tips or post-internal transaction rewards; only the base fee is affected.

{% hint style="warning" %}
**Indexers tracking supply:** burned funds are transferred on-chain to the zero address `0x0000000000000000000000000000000000000000`. If you compute circulating supply by snapshotting balances, treat the zero-address balance as burned (subtract it from circulating totals). There is no separate "burned" counter — the zero-address balance is the source of truth.

**Example:** If 1,000 VC has accumulated at the zero address since the SfcV2 activation, subtract 1,000 from your circulating supply total.
{% endhint %}

---

### Cheater Fee Zeroing (Elemont)

When the Elemont upgrade is active, validators flagged as cheaters in an epoch have **all** their accumulated transaction fees for that epoch zeroed out at epoch seal time. This is applied when submitting the `SealEpoch` transaction to the SFC contract.

#### Impact on rewards

- **Cheater penalties increase** — instead of losing future rewards, cheaters lose all fees earned in the epoch they're caught, including fees from transactions before they were flagged.
- **Interaction with base fee burn** — the burn mechanism still applies per-transaction during block processing, but the final fee (after burn) is discarded anyway if the validator is later marked a cheater.

**Example scenario:**

1. Validator `A` produces 10 blocks in epoch N, earning 100 VC in fees (after 30% burn).
2. Validator `A` is detected as a cheater during epoch N.
3. At epoch seal, instead of receiving 100 VC, validator `A` receives 0 VC.

---

### Payback Fee Refunds

Stakers meeting the minimum stake threshold automatically receive gas fee refunds after each transaction they originate. This is the user-visible effect of the Podgorica upgrade and the `feeRefund` receipt field above.

#### How payback refunds work (without creating supply)

**Key principle:** Refunds are a **redistribution** of existing transaction fees, not new money creation. The on-chain mechanics are:

1. User submits a transaction with a declared `gasPrice`.
2. EVM execution consumes the full `gasUsed × gasPrice` from the sender's account (same as pre-Podgorica).
3. Full fee is credited to the validator (pre-refund, the fee is already out of the sender's balance).
4. **After epoch seal** — the payback system queries the sender's stake via the SFC contract. If the sender meets the minimum stake threshold, a **refund amount is returned from the validator's earned fees**.
5. The validator's total earnings decrease by the refund amount; the sender's balance increases by it.

**Result:** No new VC is created; the refund is simply moved from validator earnings to the eligible staker. The total money supply is unchanged.

#### Impact on gas accounting

- The `feeRefund` field appears in receipts for eligible senders only.
- Effective gas cost is lower for qualifying stakers — dApps showing "gas spent" metrics from receipts should subtract `feeRefund` from the raw `gasUsed * effectiveGasPrice` calculation.
- Refunds are applied **after** EVM execution. They do not change the declared `gasPrice`, `gasLimit`, or the `gasUsed` reported in the receipt.
- A transaction's nominal fee still leaves the sender's balance during execution; the refund is a separate state transition in the same block.

#### Programmatic access: `vc_getPaybackBalance` (v2.0.6-elemont)

v2.0.6-elemont adds a dedicated JSON-RPC method for querying the currently available payback balance of an address. It is a **pure RPC addition** on top of v2.0.5-elemont: no consensus rules change, no upgrade flags, no receipt format changes. Nodes on mixed v2.0.5 / v2.0.6 produce identical state roots.

| Field            | Value                                                                              |
| ---------------- | ---------------------------------------------------------------------------------- |
| Namespace        | `vc` (not `eth`)                                                                   |
| Method           | `vc_getPaybackBalance`                                                             |
| Params           | `[address]` — 20-byte hex string. Optional second param: block number or `"latest"` (default) |
| Returns          | Hex-encoded wei value (`*hexutil.Big`). Returns `0x0` for the zero address, when Podgorica is inactive, or when the caller stakes below minimum |
| Error `-32005`   | Rate-limit rejection when the process-wide in-flight cap is saturated              |

**Example:**

```bash
curl -s -X POST http://localhost:18545/ \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"vc_getPaybackBalance","params":["0xABCDEF0123456789ABCDEF0123456789ABCDEF01"],"id":1}'
```

Returns the currently available payback balance for the address at the latest sealed block.

**Concurrency cap and rejection code.** Each call executes up to five EVM `StaticCall`s against the payback proxy and SFC contracts (≈500k gas total), so the handler is gated by a process-wide semaphore:

| Knob                        | Value      |
| --------------------------- | ---------- |
| Max in-flight calls         | 8          |
| Acquire timeout             | 2 seconds  |
| Rejection error code        | `-32005`   |
| Rejection error message     | `payback query rate-limited` |

Clients should treat `-32005` as a transient rate-limit signal and retry with backoff. High-volume callers (indexers, scanners) should stagger requests or open multiple RPC endpoints rather than request a higher cap.

**Why a new namespace instead of `eth_`?** The accessor is intentionally RPC-safe: it never reads or writes `PaybackCache.blkCtx` and never mutates `StakesMap`, so concurrent RPC traffic cannot corrupt in-flight block-processing state. Placing it in the `vc` namespace keeps it distinct from Ethereum-standard methods and signals to consumers that it exposes VinuChain-specific accounting rather than EVM state.

**Who is affected:**

- **dApps, wallets, block explorers**: no action needed. Existing `eth_*` / `debug_*` / `trace_*` behavior is unchanged.
- **Scanners/indexers that want payback balance data**: replace any prior workaround (reading SFC state directly via `eth_call`) with `vc_getPaybackBalance`. The new method returns the final refund amount after the five internal StaticCalls that compute it.
- **Clients calling `eth_getPaybackBalance`**: that method never shipped in any public release. If you have custom client code referencing it from an internal branch, switch to `vc_getPaybackBalance`.

**Activation.** Immediate on restart. No epoch-seal wait, no staging log, no flag transition — the method is registered when the RPC server starts.

---

### JSON-RPC Defensive Caps & Rate Limits

The following caps and behaviors ship with **`v2.0.3-elemont`** via the upstream `go-vinu v1.20.14-quota` fork and carry forward into every later elemont release. They are **defensive hardening** — DoS mitigations, not protocol changes — but high-volume clients may see new error responses where previously the node accepted unbounded input.

| Cap / change | RPC method(s) | New limit | Error on exceed |
| --- | --- | --- | --- |
| JSON-RPC batch size ceiling | Any batched call (`POST` with a JSON array) | **100 messages per batch** | `invalid request: batch too large` |
| In-flight RPC concurrency | All HTTP & WS RPC methods | **50 concurrent requests** (new default; configurable via `--rpc.maxconcurrent`) | HTTP 503 Service Unavailable |
| `StateOverride.code` byte cap | `eth_call`, `eth_estimateGas`, `debug_traceCall` | **`MaxCodeSize` (24,576 bytes)** per account | `code size exceeds MaxCodeSize` |
| `StateOverride.stateDiff` entry count | `eth_call`, `eth_estimateGas`, `debug_traceCall` | **1,000 entries per account** | `stateDiff size exceeds 1000 entries` |
| Receipt `feeRefund` byte cap (P2P ingress) | Internal — peer-to-peer receipt RLP decoding | **32 bytes / 256-bit integer** | Peer connection drops offending receipt |
| Graceful shutdown error response | Any RPC method during node shutdown | (new) handler returns proper JSON-RPC error on shutdown instead of silent connection drop | `handler is stopping` |

#### Who is affected

- **Batch size (100 msgs):** indexers and explorers sometimes batch block-range queries. 100 covers >99% of observed batch sizes on the existing testnet; clients hitting this should paginate.
- **Concurrency (50):** the default prevents goroutine flooding on a single node. Operators with heavy analytics workloads can raise it via `--rpc.maxconcurrent=N` in the node flags; set to 0 for unlimited.
- **`stateOverride` caps:** tools that simulate large contracts (`eth_call` with injected contract code) must stay under 24,576 bytes. `stateDiff` entry cap of 1,000 is larger than most account storage layouts; affects only stress-test or fuzzer workloads.
- **`feeRefund` byte cap:** internal P2P validation only. No consumer impact — the cap matches the on-chain 256-bit integer type and prevents malformed peer data from entering the node.
- **Graceful shutdown error:** clients that reconnect after an interrupted request now receive a descriptive JSON-RPC error instead of a bare TCP close. Improves debuggability; no contract break.

#### Operator configuration

The concurrency cap accepts a CLI flag:

```bash
opera --rpc.maxconcurrent 100    # allow 100 in-flight RPC requests
opera --rpc.maxconcurrent 0      # disable the cap entirely
```

The batch size cap (100) and `stateOverride` caps are hard-coded. Clients that batch aggressively should reduce batch size rather than request a higher cap.

#### Migration checklist

- [ ] Indexers: split any batch >100 messages into chunks of ≤100
- [ ] Analytics: if you run 50+ concurrent `eth_call` against a single node, either set `--rpc.maxconcurrent` to your peak or distribute the load across multiple RPC endpoints
- [ ] Tooling: ensure `stateOverride.code` blobs stay under 24,576 bytes per account
- [ ] Error handling: accept the new `invalid request: batch too large` and `handler is stopping` error strings in retry logic

---

### Database & State Compatibility

**No state resync required.** All three upgrades (SfcV2, Podgorica, Elemont) are compatible with the existing LevelDB chain state. The binary upgrade does not change the storage schema or require database migration:

- **Existing delegations/stakes** remain valid under SFC V2 — no state migration happens.
- **Chain state** from blocks before the upgrade is unchanged and remains queryable.
- **Block history** is preserved — querying old blocks (before SfcV2/Elemont activation) returns pre-upgrade results.
- **No snapshot import needed** — a simple binary swap and restart is sufficient; no full resync from genesis.

Validators who miss the upgrade window can recover by installing the new binary and restarting (see "Recovering a node that missed the window" above).

---

### Performance & Reliability Improvements

The Elemont release includes several performance optimizations and reliability fixes across RPC, tracing, gas accounting, pruning, P2P gossip, and consensus-engine subsystems.

#### RPC concurrency limiting

The `MaxConcurrentRPC` configuration now enforces HTTP/WebSocket request concurrency limits in-process. Requires the go-vinu v1.20.9+ upgrade.

**Impact:**

- Prevents RPC endpoint saturation under load
- Queues excess requests gracefully instead of accepting unlimited connections
- Operators can tune `MaxConcurrentRPC` to match server capacity

#### TX tracing optimizations

Several fixes improve the stability and efficiency of the `trace_*` RPC namespace:

- **Unbounded memory accumulation fix** — `trace_filter` with `Count==0` now caps results at 10,000 entries per request instead of accumulating unbounded results across up to 1000 blocks (could reach 100s of MB).
- **Span map leak fix** — toggling tracing on/off no longer leaks in-flight span objects in memory.
- **Trace storage error propagation** — errors during trace storage are now properly logged at info level instead of silently swallowed.
- **Bounds checking** — `traceBlock` replay path now guards array indices to prevent panics on malformed receipts.

**Impact:** Trace endpoints no longer cause OOM errors on high-throughput chains.

#### FeeHistory response fix

`eth_feeHistory` response now properly copies the tips slice per entry instead of sharing the same backing array. Pre-fix, mutating one entry could corrupt all other entries.

**Impact:** RPC consumers using `feeHistory` results to estimate gas prices no longer risk data corruption.

#### Gas accounting fixes

- **Block vote gas overflow** — the consensus layer's block vote gas calculation now uses overflow-safe addition, preventing vote spam if governance sets `BlockVotesBaseGas` to a large value.
- **Gas oracle div-by-zero** — the gas price oracle guards against `MaxAllocPeriod=0` set via governance, preventing division by zero panics.
- **MinGasPrice validation** — governance cannot set `MinGasPrice` to zero, preventing EVM execution on zero-cost transactions.

#### Pruning improvements

- **Negative flag validation** — `--prune-keep-epochs` and `--prune-keep-blocks` now reject negative values with a clear error instead of wrapping to large unsigned values.
- **Receipt pruning** — new `opera snapshot prune-receipts` subcommand for fine-grained receipt retention control.
- **Pruning recovery** — if a pruning operation is interrupted (node crash), the next startup automatically resumes the interrupted prune.
- **Snapshot config tuning** — restored Snapshots `count=128` for better snapshot distribution.

**Impact:** Pruning is more robust, error messages are clearer, and recovery from node crashes is automatic.

#### EVM execution guards

- `eth_call` now enforces `MaxCodeSize` limit even when code is provided via state overrides, preventing oversized contract simulations.

#### Consensus engine internals (v2.0.4-elemont, lachesis-base v0.1.6-elemont)

v2.0.4-elemont ships the same RPC surface as v2.0.3-elemont. The only additions are consensus-engine internals in lachesis-base `v0.1.6-elemont`:

| Scope | Change | Consumer impact |
| --- | --- | --- |
| `vecengine` | Cap per-validator branch allocation | None — prevents Byzantine vector memory inflation; no observable behavior on healthy networks |
| `dagprocessor` / `gossip` | Drain queued events on quit, prevent checker-exit deadlock | None — only affects clean shutdown paths |
| `kvdb` | Clear flushable write buffer only after successful batch write | None — removes a race that could lose writes on crash mid-batch |
| `semaphore` | Zero metric after termination, clamp underflow | None — metric/debug plumbing |

RPC consumers (indexers, dApps, wallets) **do not need to change anything** for the v2.0.3 → v2.0.4 bump. All v2.0.3 migration checklist items above still apply.

#### P2P gossip — per-peer event-processing quota (v2.0.7-elemont)

v2.0.7-elemont is a **pure node-internal hotfix** on top of v2.0.6-elemont. No consensus rules change, no upgrade flags, no receipt format changes, no JSON-RPC surface changes. Nodes on mixed v2.0.6 / v2.0.7 produce identical state roots.

The per-peer in-flight quota in the gossip handler (`gossip/peer_ratelimit.go`) was sized smaller than a single legitimate DAG sync chunk:

| Quota                       | v2.0.6 cap | v2.0.7 cap | Sized to                                                |
| --------------------------- | ---------- | ---------- | ------------------------------------------------------- |
| `peerEventQuota` (DAG events) | 200        | 3,250      | `ParallelChunksDownload * DefaultChunkItemsNum + softLimitItems` (matches `DagProcessor.EventsBufferLimit.Num`) |
| `peerStreamQuota` (BV/BR/EP)  | 100        | 3,250      | Same formula                                              |

Because the dagstreamleecher delivers chunks of up to `DefaultChunkItemsNum = 500` events with `ParallelChunksDownload = 6` chunks in flight per active sync session (sessions are per-peer via `IsValidSession`), v2.0.6 dropped every legitimate chunk during catch-up and logged `Peer exceeded event processing quota` on every drop. v2.0.7 raises both per-peer caps to match the dagprocessor's own buffer (`EventsBufferLimit.Num = 3,250`).

**DoS guarantee preserved.** `gossip/config.go::Config.Validate()` still enforces `EventsSemaphoreLimit ≥ 2 × EventsBufferLimit`, so the global event-processing semaphore is at least 6,500 items. A single peer remains bounded to ≤50% of total capacity (3,250 of ≥6,500). v2.0.7 also adds a startup sanity assertion that fails fast if anyone ever shrinks the per-peer cap below the processor buffer in a future change.

**Who is affected:**

- **Validator and RPC operators**: no consumer-facing action needed. After the binary swap, the warning storm stops on the next chunk.
- **dApps, wallets, indexers, explorers**: no action — the JSON-RPC surface is byte-for-byte identical to v2.0.6.
- **Network analysts / observability**: any alerting on the `Peer exceeded event processing quota` log line should be updated to reflect that the warning is now an actual abuse signal rather than background sync noise.

**Activation.** Immediate on restart. No epoch-seal wait, no staging log, no flag transition.

#### P2P gossip — peer-progress drift caps removed (v2.0.8-elemont)

v2.0.8-elemont is a **pure node-internal hotfix** on top of v2.0.7-elemont. No consensus rules change, no upgrade flags, no receipt format changes, no JSON-RPC surface changes. Nodes on mixed v2.0.7 / v2.0.8 produce identical state roots.

`gossip/handler_sync.go::validatePeerProgress` — added in v2.0.7 (commit `9278d71`, "resolve remaining Round 2 audit findings") — rejected any peer whose `ProgressMsg` claimed an epoch more than 1,000 ahead of local, or a block more than 5,000 ahead. v2.0.8 removes both upper bounds and the unused constants, keeping only the structural `progress.Epoch == 0` check.

| Check                       | v2.0.7 behavior  | v2.0.8 behavior |
| --------------------------- | ---------------- | --------------- |
| `progress.Epoch == 0`       | reject (invalid) | reject (invalid) |
| `progress.Epoch > local+1000` | reject ("peer epoch N too far ahead") | **accepted** (catch-up is expected) |
| `progress.LastBlockIdx > local+5000` | reject ("peer block N too far ahead") | **accepted** |

**Who is affected:**

- **Validator operators returning from extended downtime**: on v2.0.7, any node whose chain state was more than 1,000 epochs behind live tip would successfully RLPx-handshake with current peers, then its own `validatePeerProgress` would reject every incoming `ProgressMsg` and it would close the subprotocol within ~175 ms. Visible symptom on the stale node: `Looking for peers peercount=1 tried=N` with `tried` climbing and `last_id` never advancing. Visible symptom on the tip-side peer: `Removing p2p peer req=true err="subprotocol error" duration=~175ms`, repeating every ~30 s against the same remote. v2.0.8 restores the ability for these nodes to catch up via normal DAG sync.
- **Fresh-install validators on testnet**: this release alone does **not** unblock fresh installs from the distributed 2024-06-21 genesis — that hits a separate "wrong event epoch hash" divergence at the first post-startup epoch seal, because the genesis pre-dates several SFC upgrade flags. See the chaindata snapshot instructions in the [Troubleshooting → wrong event epoch hash](#warn-incoming-event-rejected-err-wrong-event-epoch-hash) section above.
- **dApps, wallets, indexers, explorers**: no action — the JSON-RPC surface is byte-for-byte identical to v2.0.7.

**DoS guarantee.** The removed check never closed a real DoS vector. The deeper per-event acceptance path (`lightCheck` in `gossip/handler_sync.go:89` and the `epochcheck.ErrNotRelevant` gate) already refuses events whose epoch does not match local, so a peer lying about progress consumes no state. `progress.Epoch == 0` remains the structural sanity guard.

**Activation.** Immediate on restart. No epoch-seal wait, no staging log, no flag transition.

---

### Build & Tooling Changes

#### Minimum Go Version: 1.14 → 1.25+

The Elemont release requires **Go 1.25 or later** to build from source. The previous production branch (`main`) supported Go 1.14.

##### Impact on Node Operators

- **Pre-built binaries:** If you download the pre-built `opera` binary from the release page, Go is already compiled in — no action needed.
- **Building from source:** You must upgrade your Go toolchain before running `make opera`.

##### Upgrading Go

Detailed upgrade instructions are in the [Prerequisites](#prerequisites) section above under "Build requirements".

Quick verification:

```bash
go version
# Expected: go version go1.25.N linux/amd64 (or later, or different arch)
```

***

_Last updated: 2026-04-25 · VinuChain tag `v2.0.11-elemont` (published) · go-vinu `v1.20.14-quota` · lachesis-base `v0.1.6-elemont`_
