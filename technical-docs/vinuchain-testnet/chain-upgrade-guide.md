<!-- markdownlint-disable MD013 -->

# Chain Upgrade Guide (v2-elemont)

## Latest release

| Version           | Network | Status                                                                 |
| ----------------- | ------- | ---------------------------------------------------------------------- |
| `v2.0.37-elemont` | Testnet | Binary deployed to validators/RPC; BLS staged; latest-EVM deferred     |

## What's new

- **Stages VinuChain-specific BLS12-381 and latest-EVM forks on testnet.** `VinuBLS12381` enables the EIP-2537/BLS12-381 precompile family at `0x0b`-`0x11` as an explicit VinuChain fork flag. `VinuLatestEVM` then enables P256VERIFY at `0x0100`, CLZ, MODEXP bounds/repricing, and the EIP-7825 per-transaction gas cap. These are staged in order and activate only at epoch seals.
- **Adds `eth_config` support.** The public RPC now reports the sealed execution configuration, chain ID, fork ID, activation block/time, and active precompile set. `eth_config` does not expose pending `DirtyRules`; use `vc_getRules("latest")` after each seal to confirm fork activation.
- **Adds explicit gas-cap enforcement and tests.** v2.0.36 rejects transactions above the `VinuLatestEVM` per-transaction gas cap in txpool, state transition, and block execution, and caps `eth_estimateGas` once the fork is active.
- **Consumes the go-vinu precompile/ModExp vector-test release.** v2.0.37 pins go-vinu `v1.20.24-quota`, which carries the broader BLS12-381, secp256r1/P256, CLZ, MODEXP, and gas-cap vector coverage used for this testnet hard-fork validation. lachesis-base remains `v0.1.6-elemont`.
- **Carries forward ERC-4337 account abstraction on testnet.** The canonical EntryPoint v0.7 (`0x0000000071727De22E5E9d8BAf0edAc6f37da032`), SimpleAccountFactory (`0x27e13cC69A1d0cb6205153f89Be711B1872CfFd6`), and a public Skandha bundler (`https://bundler-testnet.vinuexplorer.org/rpc`) are live, and the explorer indexes and renders UserOperations. See [Account Abstraction (ERC-4337)](../smart-contracts/account-abstraction.md).
- Adds the `--rpc.allow-unprotected-txs` node flag (v2.0.29) so operators can admit pre-EIP-155 (chain-id-less) transactions over RPC — required to land the Arachnid deterministic deployer and the canonical EntryPoint. The flag is **refused on mainnet** (NetworkID 207) by a gossip-layer guard; it is for non-mainnet networks only.
- Adds a mainnet allowlist (v2.0.30) for the single canonical Arachnid deterministic-deployer transaction, pinned by exact tx hash, so the canonical EntryPoint can eventually land on mainnet without otherwise relaxing replay protection. It is replay-benign and independent of the flag above.
- Hardens the unprotected-tx mainnet guard (v2.0.31): extracts it into a tested helper with all-network regression coverage and adds an `ethapi` call-site test. No consensus or state change — testnet/mainnet behavior is identical to v2.0.30, so this release activates no new flag.
- Carries forward Prague/EIP-7702 set-code support (v2.0.28), Shanghai/Cancun execution compatibility, the `SfcV2Patch6` Cycle-162 backfill, and the corrected PaybackV2 address `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4`.
- Current source stages a future mainnet hard fork for SfcV2, Podgorica, ElemontPubkeyValidation, Shanghai, Cancun, and Prague, and points fresh mainnet rules at the live Quota proxy. Mainnet `PaybackV2`, `VinuBLS12381`, and `VinuLatestEVM` remain deliberately false until separate activation releases.

## Current Testnet Rollout State

`v2.0.37-elemont` was built on the testnet hosts and deployed to the public trace RPC plus validators V1-V4 on 2026-06-03. The deployed client string is `go-opera/v2.0.37-elemont-df23f245-1780458226/linux-amd64/go1.26.3`. The trace RPC and validator host binaries are byte-identical (`sha256 89b63f226d9621f11fd8a3ad979563895c57555bdf7b8a0e3440cc215d826edb`).

Post-deploy verification confirmed:

- All four validator services are active on `v2.0.37-elemont`, at the same live head, with `eth_syncing=false`.
- The public trace RPC at `http://100.22.109.110:4000` serves `v2.0.37-elemont`, exposes `trace` and `debug`, returns `eth_syncing=false`, and `trace_block("latest")` succeeds.
- `vc_getRules("latest")` reports `PaybackV2=true`, `PaybackV2Patch=true`, and `Economy.QuotaCacheAddress=0x89d1cbd9deaab4dff6f800a336fbdd9a5c6829e4`.
- The corrected PaybackV2 contract has code at `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4`, owner `0xf9c82B1117e8BeA97843042521B8FBC93044f347`, and the `stakeFor(address)` / `unstakeFor(address,uint256)` selectors.
- At 2026-06-03 05:29 UTC, testnet was still in epoch `5906` at block `1,482,805`; `VinuBLS12381` was staged in `DirtyRules` and waiting for the next epoch seal, and `VinuLatestEVM` was correctly deferred until after BLS seals. Until those seals complete, BLS/P256/CLZ/MODEXP/latest-EVM runtime smoke checks are not final.

The latest public recovery snapshot currently published before this rollout is:

```text
https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.31-elemont-20260529T002920Z-clean.tar.gz
```

Snapshot SHA256:

```text
77523c5f907add15ddde257fe6c80f4b3ac07d2c3129da2d5135f90570c59e16
```

Treat that object as the last public pre-v2.0.37 snapshot, not as a post-BLS/latest-EVM recovery point. After `VinuBLS12381` or `VinuLatestEVM` seals, publish and use a new snapshot taken after those seals. During the 2026-06-03 trace-RPC recovery, the stale replay path was avoided by restoring `chaindata/` from a current validator snapshot instead.

---

## Network Details

| Network | Chain ID   | RPC                              | Status          |
| ------- | ---------- | -------------------------------- | --------------- |
| Mainnet | 207 (0xcf) | `https://vinuchain-rpc.com`      | Upgrade pending |
| Testnet | 206 (0xce) | `https://vinufoundation-rpc.com` | v2.0.37 deployed; PaybackV2 active; BLS staged |

---

## Prerequisites

### Build requirements

- **Go 1.25+** (check with `go version`)
- **gcc (or clang)** and standard C library headers — required for building go-vinu's crypto and LevelDB C bindings.
- **git**
- At least **50 GB** free disk space

### Required Ports

Ensure these remain open in your firewall:

| Port  | Protocol | Purpose                             |
| ----- | -------- | ----------------------------------- |
| 5050  | TCP/UDP  | P2P networking                      |
| 18545 | TCP      | HTTP JSON-RPC (if exposing RPC)     |
| 18546 | TCP      | WebSocket JSON-RPC (if exposing WS) |

---

## Upgrade Steps

{% hint style="info" %}
**Fresh install?** This guide covers binary swaps on existing validator nodes. Bootstrapping a brand-new testnet node by replaying from genesis is **not supported under the current v2.x binary rules** — follow the snapshot-restore procedure in [Troubleshooting → Wrong event epoch hash](#warn-incoming-event-rejected-err-wrong-event-epoch-hash) instead. Do not use this guide as a routine pre-activation mainnet genesis-replay path: the current binary hardcodes future mainnet `SfcV2` / EVM fork activations and stages those transitions at the next epoch seal when run on a pre-activation mainnet datadir.
{% endhint %}

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
git checkout v2.0.37-elemont
make opera
# Binary is at $HOME/vinuchain-upgrade/build/opera
```

{% endcode %}

Substitute `/opt/vinuchain-upgrade` (or any other path) if `$HOME` is not the right partition for your setup — every later command in this guide that references `$HOME/vinuchain-upgrade` should be adjusted to match.

{% hint style="info" %}
**Dependency pins.** `v2.0.37-elemont` uses go-vinu `v1.20.24-quota` (Shanghai, selected Cancun execution support, Prague/EIP-7702 set-code transactions, VinuBLS12381, VinuLatestEVM, and precompile/ModExp vector tests) and lachesis-base `v0.1.6-elemont`. `make opera` fetches dependencies on first build.
{% endhint %}
{% endstep %}

{% step %}

#### Verify the new binary

The newly-built binary is at `vinuchain-upgrade/build/opera`. Move into that directory so the rest of the steps can use a relative `./opera` path:

```bash
cd $HOME/vinuchain-upgrade/build
./opera version
# Expected: Version: 2.0.37-elemont
```

{% hint style="info" %}
`opera version` prints `2.0.37-elemont` — this matches the git tag `v2.0.37-elemont`. See the note at the top of this page.
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

- Password file in your home secrets directory: `--validator.password /home/ubuntu/secrets/pw.txt`
- **Even if the password file is inside the build folder**, write the full absolute path: `--validator.password $HOME/vinuchain-upgrade/build/pw.txt`

Never rely on `./pw.txt` or a bare `pw.txt` — it's the easiest way to end up with `Failed to unlock validator key: open pw.txt: no such file or directory` and waste an upgrade window debugging path resolution.

The same rule applies to `--datadir`, `--genesis`, and any other flag that takes a path.
{% endhint %}

Monitor the logs:

```bash
tail -f validator.log
```

**Optional flags** (add only if you were using them before):

- `--datadir /custom/path` — if chain data is not in the default `~/.opera` location

{% hint style="danger" %}
**`--nat extip:YOUR_PUBLIC_IP` is effectively required, not optional.**

Without `--nat`, opera advertises its enode at `ip=127.0.0.1` in the peer discovery table. The symptom is almost indistinguishable from a successful start:

- Process runs fine, logs scroll normally
- `New local node record` line shows `ip=127.0.0.1 udp=… tcp=…`
- `admin.peers` returns one or zero entries
- `net.peerCount == 1`, and that peer is usually an unrelated node stuck on an old epoch
- `New DAG summary` reports `age=15h…` or older — your node has caught up to the single stale peer and halted, because no other peer can dial you back

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

- `--datadir /path/to/chaindata` — if chain data is in a custom location (default: `~/.opera`)

{% endtab %}
{% endtabs %}
{% endstep %}

{% step %}

#### Verify the upgrade

What to expect:

**Startup banner.** Every v2.x build prints the VinuChain banner. This is the first visual confirmation that you are running v2.0.37-elemont and not the previous binary:

```text
 ██╗   ██╗██╗███╗   ██╗██╗   ██╗ ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
 ██║   ██║██║████╗  ██║██║   ██║██╔════╝██║  ██║██╔══██╗██║████╗  ██║
 ██║   ██║██║██╔██╗ ██║██║   ██║██║     ███████║███████║██║██╔██╗ ██║
 ╚██╗ ██╔╝██║██║╚██╗██║██║   ██║██║     ██╔══██║██╔══██║██║██║╚██╗██║
  ╚████╔╝ ██║██║ ╚████║╚██████╔╝╚██████╗██║  ██║██║  ██║██║██║ ╚████║
   ╚═══╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

                        v2.0  -  ELEMONT

  Version: 2.0.37-elemont
```

**Staging logs (testnet only, first-time Shanghai/Cancun/Prague/BLS/latest-EVM install).** On the first boot of a node that has not yet sealed Shanghai (e.g. a genesis replay rather than a snapshot restore), you will see Shanghai staged while later forks are deferred:

```text
INFO Staged Shanghai upgrade from binary rules; will activate at next epoch seal
INFO Deferring Cancun upgrade from binary rules until Shanghai is active
INFO Deferring Prague upgrade from binary rules until Cancun is active
INFO Deferring VinuBLS12381 upgrade from binary rules until Prague is active
INFO Deferring VinuLatestEVM upgrade from binary rules until VinuBLS12381 is active
```

This confirms EIP-3651, EIP-3855, and EIP-3860 are pending for the next epoch seal, while Cancun is intentionally held back so skipped-binary nodes do not collapse Shanghai and Cancun into the same activation height.

After `vc_getRules` reports `Upgrades.Shanghai = true`, v2.0.37 stages Cancun automatically on the same continuous process:

```text
INFO Staged Cancun upgrade from binary rules; will activate at next epoch seal
INFO Deferring Prague upgrade from binary rules until Cancun is active
INFO Deferring VinuBLS12381 upgrade from binary rules until Prague is active
INFO Deferring VinuLatestEVM upgrade from binary rules until VinuBLS12381 is active
```

This confirms EIP-1153, EIP-5656, and EIP-6780 behavior are pending for the next epoch seal.

After `vc_getRules` reports `Upgrades.Cancun = true`, v2.0.37 stages Prague automatically on the same continuous process:

```text
INFO Staged Prague upgrade from binary rules; will activate at next epoch seal
INFO Deferring VinuBLS12381 upgrade from binary rules until Prague is active
INFO Deferring VinuLatestEVM upgrade from binary rules until VinuBLS12381 is active
```

After `vc_getRules` reports `Upgrades.Prague = true`, v2.0.37 stages VinuBLS12381:

```text
INFO Staged VinuBLS12381 upgrade from binary rules; will activate at next epoch seal
INFO Deferring VinuLatestEVM upgrade from binary rules until VinuBLS12381 is active
```

After `vc_getRules` reports `Upgrades.VinuBLS12381 = true`, v2.0.37 stages VinuLatestEVM:

```text
INFO Staged VinuLatestEVM upgrade from binary rules; will activate at next epoch seal
```

On current post-Prague testnet datadirs, the expected first-boot staging line is `Staged VinuBLS12381 ...`, followed by `Deferring VinuLatestEVM ...`. That is the correct state until the next epoch seal. `eth_config` reports sealed execution config only; it does not show pending `DirtyRules`, so use `vc_getRules("latest")` after the seal to confirm that the flag is active. If you do not see a staging line, you may be running the wrong binary (`opera version` check), the flag may already be pending in `DirtyRules` from an earlier boot, or the flag may already be sealed on this datadir. Absence of the staging line by itself is not proof that the fork has sealed; confirm with `vc_getRules`. Mainnet does not stage `VinuBLS12381` or `VinuLatestEVM` in v2.0.37.

**Older staging logs (testnet only, first-time SfcV2Patch6 install).** Nodes upgrading from before v2.0.21 that have not yet sealed SfcV2Patch6 can also see this older staging line:

```text
INFO Staged SfcV2Patch6 upgrade from binary rules; will activate at next epoch seal
```

This confirms the Cycle-162 SFC bytecode re-flash and automatic testnet delegation backfill are pending. Mainnet nodes never show this line because SfcV2Patch6 is testnet-only. Nodes upgrading directly from v2.0.18 or earlier may also see the older `Staged PaybackV2Patch ...` line if that edge has not yet sealed on their datadir.

**Seal-time activation (testnet only).** At the next epoch seal after Shanghai staging, `vc_getRules` must report `Upgrades.Shanghai = true`. At the next epoch seal after Cancun staging, it must also report `Upgrades.Cancun = true`. At the next epoch seal after Prague staging, it must also report `Upgrades.Prague = true`. At the next epoch seal after VinuBLS12381 staging, `vc_getRules` must report `Upgrades.VinuBLS12381 = true` and `eth_config.current.precompiles` must include the BLS12-381 precompiles. At the next epoch seal after VinuLatestEVM staging, `vc_getRules` must report `Upgrades.VinuLatestEVM = true` and `eth_config.current.precompiles` must include `P256VERIFY`. There is no SFC bytecode re-flash, contract address change, or registry update for these EVM fork flags.

If SfcV2Patch6 is also still pending, the same seal can include the older SFC Patch6 re-flash:

```text
INFO Re-applying SFC V2 bytecode upgrade (patch 6) block=<N>
```

If the node writes SFC storage, you will also see the backfill log:

```text
INFO Backfilled SFC Patch6 testnet delegations block=<N> appended=3 repaired=0
```

If every listed pair is already visible in `stakes[]` or has dropped to zero stake, the re-flash log can appear without a `Backfilled ...` line. After it fires, `vc_getRules` must report `Upgrades.SfcV2Patch6 = true`, and `eth_call` to SFC `version()` must return `0x333035` (`"305"`). The `Backfilled ...` counts are lower if a listed pair already became visible or dropped to zero stake before the seal; `repaired` may be non-zero if a pair is present in `stakes[]` but its `stakePosition` points at a stale row. `Economy.QuotaCacheAddress` remains the corrected PaybackV2 address `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4`.

**Future mainnet SfcV2 activation.** When mainnet activation is explicitly scheduled, the first current v2.x boot on a pre-SfcV2 mainnet datadir stages `SfcV2`, not `SfcV2Patch6`:

```text
INFO Staged SfcV2 upgrade from binary rules; will activate at next epoch seal
INFO Applying SFC V2 bytecode upgrade block=<N>
INFO Backfilled SFC V2 mainnet delegations block=<N> appended=82 repaired=0
```

After the mainnet seal, `vc_getRules` must report `Upgrades.SfcV2 = true`, SFC `version()` must return `0x333035` (`"305"`), and the `Backfilled ...` counts should be reconciled against the refreshed mainnet missing-delegation audit taken immediately before the release. Counts can be lower if a listed pair became visible or dropped to zero stake; `repaired` can be non-zero for stale `stakePosition` rows. The staging network (`NetworkID = 205`) inherits mainnet rules and uses this same `SfcV2` activation/backfill path for rehearsal; it does not use the testnet `SfcV2Patch6` edge.

#### Verification checklist

| Check                                                     | Expected                                                                                                                                              |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Startup banner                                            | `VINUCHAIN v2.0 - ELEMONT` ASCII art printed to stderr                                                                                                |
| `opera version`                                           | `Version: 2.0.37-elemont`                                                                                                                             |
| Block production                                          | Resumes within seconds of startup; block numbers advance                                                                                              |
| Peer count                                                | Returns to prior steady-state within minutes                                                                                                          |
| Shanghai staging logs (testnet, first pre-Shanghai boot) | 1× `Staged Shanghai upgrade …`; Cancun and Prague may log as deferred until predecessors are active                                                    |
| Shanghai rule after seal                                  | `vc_getRules` reports `Upgrades.Shanghai = true`                                                                                                      |
| Cancun staging logs (testnet, post-Shanghai process)      | 1× `Staged Cancun upgrade …` after Shanghai seals; no restart required                                                                                 |
| Cancun rule after seal                                    | `vc_getRules` reports `Upgrades.Cancun = true`                                                                                                        |
| Prague staging logs (testnet, post-Cancun process)        | 1× `Staged Prague upgrade …` after Cancun seals; already-active testnet nodes will not show it again                                                  |
| Prague rule after seal                                    | `vc_getRules` reports `Upgrades.Prague = true`                                                                                                        |
| EIP-7702 transaction support after Prague seal             | Set-code transactions (`type: 0x04`) accepted; blob transactions (`type: 0x03`) remain rejected                                                        |
| VinuBLS12381 staging logs (testnet, post-Prague process)  | 1× `Staged VinuBLS12381 upgrade …`; `VinuLatestEVM` remains deferred until BLS is active                                                              |
| VinuBLS12381 rule after seal                              | `vc_getRules` reports `Upgrades.VinuBLS12381 = true`; `eth_config` includes `BLS12_G1ADD` through `BLS12_MAP_FP2_TO_G2`                               |
| VinuLatestEVM staging logs (testnet, post-BLS process)    | 1× `Staged VinuLatestEVM upgrade …` after BLS seals; no restart required                                                                               |
| VinuLatestEVM rule after seal                             | `vc_getRules` reports `Upgrades.VinuLatestEVM = true`; `eth_config` includes `P256VERIFY` at `0x0000000000000000000000000000000000000100`             |
| VinuLatestEVM transaction gas cap                         | Over-cap transactions are rejected by txpool/state transition; `eth_estimateGas` caps at the fork limit                                               |
| SfcV2Patch6 staging logs (older unsealed datadirs only)   | 1× `Staged SfcV2Patch6 …`                                                                                                                             |
| SfcV2Patch6 staging log — all other cases                 | None                                                                                                                                                  |
| Mainnet staging logs (future coordinated SfcV2 release)   | 1× `Staged SfcV2 upgrade …` on a pre-SfcV2 mainnet datadir                                                                                            |
| Staging-network SfcV2 rehearsal                           | Same SfcV2 logs as mainnet; no `SfcV2Patch6` staging line                                                                                             |
| Seal-time logs (testnet, first epoch seal after staging)  | 1× `Re-applying SFC V2 bytecode upgrade (patch 6) …`; normally 1× `Backfilled SFC Patch6 testnet delegations … appended=3 repaired=0`                 |
| Mainnet seal-time logs (future coordinated SfcV2 release) | 1× `Applying SFC V2 bytecode upgrade …`; normally 1× `Backfilled SFC V2 mainnet delegations … appended=82 repaired=0` after refreshing the audit list |
| SFC version after seal                                    | `version()` returns `0x333035` (`"305"`)                                                                                                              |
| PaybackV2 address after seal                              | `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4`                                                                                                          |
| Block hash vs peer                                        | Identical                                                                                                                                             |
| `rpc_modules` returns                                     | Includes `"vc":"1.0"` (`vc_getPaybackBalance`)                                                                                                        |
| `vc_getPaybackBalance` call                               | Returns hex-encoded wei (or `0x0` for ineligible addresses / Podgorica inactive)                                                                      |
| `eth_config` before BLS/latest seals                      | Reports the sealed current config; pending `DirtyRules` are not shown                                                                                 |

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
rm -f /path/to/opera.v2.0.10-elemont
```

The build directory under `$HOME/vinuchain-upgrade` can also be removed if you don't plan to rebuild locally.
{% endstep %}
{% endstepper %}

---

## Setting Up a New Validator

{% hint style="info" %}
New validator setup is **not** covered on this page. If you are installing a fresh validator for the first time rather than upgrading an existing one, follow the dedicated guide: [Become a Validator](../nodes-and-validators/become-a-validator.md).

That guide uses the correct `opera validator new` command for generating a validator key. A plain `opera account new` creates a regular externally-owned account, not a validator key.
{% endhint %}

---

## Rollback

Before a staged fork seals, rollback is a normal coordinated binary swap back to the previous testnet binary. After `VinuBLS12381` seals, do not roll back below v2.0.33 without operator coordination: older binaries do not know the BLS12-381 rule bit or precompile set. After `VinuLatestEVM` seals, do not roll back below v2.0.36 without operator coordination: older binaries lack the latest-EVM execution rules and complete per-transaction gas-cap enforcement. The earlier Prague rollback constraint still applies: after Prague seals, do not roll back below v2.0.28 without operator coordination. The earlier Shanghai/Cancun rollback constraints also still apply: after Shanghai seals, do not roll back below v2.0.26 without operator coordination, and after Cancun seals do not roll back below the release that sealed Cancun on that datadir.

The earlier SfcV2Patch6 rollback constraints still apply. After SfcV2Patch6 seals, do not roll back below v2.0.21 without operator coordination: the Cycle-162 bytecode and automatic testnet delegation backfill persist in chain state, and older binaries do not contain the activation-time backfill logic. The corrected PaybackV2 v2.0.19 rollback constraints still apply if PaybackV2Patch was also part of the node's upgrade path.

For the future mainnet `SfcV2` release, rollback before the mainnet SfcV2 seal is a normal coordinated binary rollback. After mainnet SfcV2 seals, do not roll below the activation binary without operator coordination: Cycle-162 SFC bytecode and the mainnet delegation backfill persist in chain state. Fresh or recovering mainnet nodes should use a post-SfcV2 snapshot once that activation has happened; replaying from a pre-activation genesis/datadir under a different binary can re-stage the transition at the wrong seal.

1. Stop the node (clean shutdown).
2. Replace `opera` with a prior elemont release binary (e.g., v2.0.10-elemont, v2.0.9-elemont, or earlier).
3. Start the node.

No datadir changes are needed for a pre-seal rollback. A post-seal rollback must be treated as a coordinated incident response, not a routine downgrade.

{% hint style="info" %}
**Per-version rollback deltas.** Each bullet describes the only functional difference between the two versions.

- **v2.0.37 → earlier rollback:** v2.0.37 consumes the go-vinu precompile/ModExp vector-test release. Treat rollback like v2.0.36: safe only before the relevant BLS/latest-EVM seal, and never below the binary that sealed an already-active flag without operator coordination.
- **v2.0.36 → earlier rollback:** Safe only before the `VinuLatestEVM` seal. After the seal, older binaries do not consistently reject over-cap transactions across txpool, state transition, block execution, and `eth_estimateGas`.
- **v2.0.34/v2.0.35 → earlier rollback:** Safe only before the `VinuLatestEVM` seal. After the seal, older binaries lack P256VERIFY, CLZ, MODEXP bounds/repricing, `eth_config` latest-EVM reporting, and the VinuLatestEVM RLP/config bits.
- **v2.0.33 → earlier rollback:** Safe only before the `VinuBLS12381` seal. After the seal, older binaries lack the BLS12-381 precompile set, RLP bit, EVM chain-config mapping, and staged activation logic.
- **v2.0.32 → earlier rollback:** Mainnet/staging rehearsal release for SfcV2/Podgorica/Shanghai/Cancun/Prague rule defaults and the mainnet Quota proxy pointer. Existing testnet datadirs are governed by the already-sealed testnet flags above.
- **v2.0.28 → earlier rollback:** Safe only before the Prague seal. After Prague seals, older binaries lack EIP-7702 set-code transaction decoding, authorization-list validation, delegated EOA execution, event serialization, txpool policy, and RPC/signer support; downgrade can diverge on valid post-Prague transactions.
- **v2.0.26 → earlier rollback:** Safe only before the relevant Shanghai/Cancun seal. After Shanghai seals, v2.0.21 and older lack Shanghai support, v2.0.22-v2.0.24 lack the fixed VinuChain-local Shanghai transaction checks, and v2.0.25 lacks the full event-admission, txpool reset, skipped-transaction accounting, and continuous Cancun-staging hardening. After Cancun seals, older binaries also lack the final Cancun opcode/`SELFDESTRUCT` behavior and downgrade can diverge on valid post-Cancun transactions or gas accounting.
- **v2.0.25 → earlier rollback:** Safe only before the relevant Shanghai/Cancun seal. After Shanghai seals, v2.0.21 and older lack Shanghai support, and v2.0.22-v2.0.24 lack the fixed VinuChain-local Shanghai transaction checks. After Cancun seals, older binaries also lack the final Cancun opcode/`SELFDESTRUCT` behavior and downgrade can diverge on valid post-Cancun transactions or gas accounting.
- **v2.0.21 → v2.0.20 rollback:** Safe only before `SfcV2Patch6` seals. During the pending Patch6 window, v2.0.20 can stage the bytecode re-flash but does **not** perform the automatic testnet delegation backfill, so validators should run v2.0.21 before the Patch6 seal.
- **v2.0.20 → v2.0.19 rollback:** Safe only before `SfcV2Patch6` seals. After the seal, Cycle-162 SFC bytecode persists in chain state, but v2.0.19 lacks the `SfcV2Patch6` rule bit, startup guard, and staging logic; downgrade only as coordinated incident response.
- **v2.0.19 → v2.0.18 rollback:** Safe only before `PaybackV2Patch` seals. After the seal, stored rules point at the corrected V2 contract and v2.0.18 lacks the patch flag plus `unstakeFor(address,uint256)` Payback classification, so downgrade would make Payback accounting observability incomplete.
- **v2.0.14 → v2.0.13 rollback:** v2.0.13 was a same-day scaffolding release with the deadbeef-placeholder Cycle-161 bytecode and both flags defaulted off; the v2.0.13 binary refuses to start with `SfcV2Patch5: true` set against the placeholder, so this rollback path is **not safe** if `SfcV2Patch5` has already sealed on testnet. Rollback further to v2.0.12 instead.
- **v2.0.14 → v2.0.12 rollback:** Loses both `SfcV2Patch5` staging and the `ElemontPubkeyValidation` sealer guard. If `SfcV2Patch5` has already sealed on testnet, the Cycle-161 bytecode at `0xFC00FACE...` persists in chain state (see Testnet note below); the v2.0.12 binary continues to dispatch against it unchanged. If `ElemontPubkeyValidation` has already sealed, validator 16 stays ejected from the active set in stored epoch state regardless of the binary running. `eth_feeHistory` reverts to the hardcoded `gasUsedRatio: 0.99` (the rollback target restores that pre-v2.0.13 behaviour).
- **v2.0.11 → v2.0.10 rollback:** Loses the `SfcV2Patch4` staging logic in binary rules and the `sfc.EnforcePatch4StartupCheck` build guard. If `SfcV2Patch4` has already sealed on testnet, the Cycle-160 bytecode at `0xFC00FACE...` persists in chain state (see Testnet note below); the v2.0.10 binary continues to dispatch against it unchanged. The relock invariant remains `endTime >= ld.endTime` because that logic lives in the deployed bytecode, not the binary.
- **v2.0.10 → v2.0.9 rollback:** Loses the `SfcV2Patch3` staging logic. If `SfcV2Patch3` has already sealed, the Cycle-159 reentrancy-guard-fixed bytecode persists in chain state; all `nonReentrant` entrypoints continue to work because the `_reentrancyGuardCounter < 2` check is in the deployed bytecode.
- **v2.0.9 → v2.0.8 rollback:** Loses the trusted-preset entry for `vitainu-genesis-testnet-20260419.g`. Fresh installs on v2.0.8 from that genesis file again require `--genesis.allowExperimental` and print the `SECURITY WARNING: Genesis file doesn't refer to any trusted preset` line on startup; existing datadirs are unaffected.
- **v2.0.8 → v2.0.7 rollback:** `validatePeerProgress` re-applies its drift caps (`maxPeerEpochDrift=1000`, `maxPeerBlockDrift=5000`). Safe as long as the node is not offline long enough to fall past those caps; an offline stretch beyond ~1,000 epochs on v2.0.7 will lock the node out of re-peering (the bug v2.0.8 fixes).
- **v2.0.7 → v2.0.6 rollback:** The per-peer event-processing quota reverts to its smaller value (200 DAG events / 100 stream items), so the `Peer exceeded event processing quota` warning storm returns during sync.
- **v2.0.6 → v2.0.5 rollback:** The `vc_getPaybackBalance` JSON-RPC method disappears. Clients calling it receive `method not found`.

{% endhint %}

{% hint style="warning" %}
**Testnet note — sealed bytecode persists across rollbacks.** Once an `SfcV2Patch*` upgrade flag has sealed on testnet, the bytecode it flashed at `0xFC00FACE00000000000000000000000000000000` is permanent in chain state. Rolling back the binary does **not** revert the installed bytecode:

| Sealed patch  | Introduced in | Testnet seal                 | Installed bytecode                               |
| ------------- | ------------- | ---------------------------- | ------------------------------------------------ |
| `SfcV2Patch2` | v2.0.5        | Mid-v2.0.5 boot              | Cycle-158 SFC (45,240 bytes)                     |
| `SfcV2Patch3` | v2.0.10       | 2026-04-19 · block 1,424,440 | Cycle-159 SFC — inline reentrancy guard fix      |
| `SfcV2Patch4` | v2.0.11       | 2026-04-23 · block 1,430,436 | Cycle-160 SFC — `_lockStake` / `relockStake` fix |
| `SfcV2Patch5` | v2.0.14       | Active by 2026-05-17         | Cycle-161 SFC — canonical-pubkey validation      |
| `SfcV2Patch6` | v2.0.21       | 2026-05-16 · block 1,460,329 | Cycle-162 SFC — orphan-delegation auto-backfill  |

This is expected behavior — the bytecode update is the intended outcome of each upgrade and cannot be undone by swapping binaries. Reverting installed bytecode would require shipping another epoch-sealed upgrade flag, which is a forward-moving change rather than a rollback.

Mainnet is currently unaffected because no `SfcV2*` flag has sealed there yet. During a future mainnet SfcV2 window, rollback is routine only before the SfcV2 seal; after that seal, bytecode and backfill state persist and downgrade must be coordinated.
{% endhint %}

---

## Troubleshooting

### Node won't start after upgrade

1. Check logs: `journalctl -u opera -f` (systemd) or your terminal / Docker output.
2. Verify the binary: `opera version` must print `2.0.37-elemont`.
3. If the database is reported as corrupted, restore from the chaindata snapshot below.

### Node starts but doesn't produce events

1. Confirm `--validator.password` points to a readable file via absolute path.
2. Confirm `--validator.id` and `--validator.pubkey` match your on-chain registration.
3. Confirm peers are connecting — an isolated node cannot produce events.

<!-- markdownlint-disable-next-line MD033 -->
<a id="warn-incoming-event-rejected-err-wrong-event-epoch-hash"></a>

### `WARN Incoming event rejected ... err="wrong event epoch hash"`

Your locally-computed epoch state hash does not match the network's. The check rejects any event whose `PrevEpochHash` differs from the local store's `EpochState.Hash()`. There is no protocol-level recovery; chaindata must be replaced with a snapshot.

{% hint style="danger" %}
**Do not resync from genesis on testnet.** A fresh replay stages not-yet-sealed upgrade flags at replay time — at a different block from the live chain's historical activations — so the epoch state hash diverges immediately. Use the latest published post-seal snapshot below instead. Snapshots taken before the Prague, Shanghai, Cancun, SfcV2Patch6, PaybackV2Patch, VinuBLS12381, or VinuLatestEVM seals are stale for fresh installs after those upgrades because they can re-fire edges at the wrong replay seal.
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

4. Download the latest post-seal testnet snapshot and extract it in-place over the datadir (the tar is written with relative paths, so extract at the datadir root; published tarballs exclude `nodekey`, `keystore/`, `opera.ipc`, `static-nodes.json`, `trusted-nodes.json` so your identity files are preserved). Always use the latest snapshot — older objects in the bucket are archival.

   ```bash
   cd <datadir>
   SNAPSHOT_URL="https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.31-elemont-20260529T002920Z-clean.tar.gz"
   curl -LO "$SNAPSHOT_URL"
   # verify integrity
   curl -L "$SNAPSHOT_URL.sha256" | sha256sum -c -
   tar -xzf "${SNAPSHOT_URL##*/}"
   rm "${SNAPSHOT_URL##*/}"
   ```

   **Sanity-check the extraction before restarting opera.** Every snapshot published from 2026-04-24 onwards (including this one) includes a `SNAPSHOT_INFO.txt` at the tarball root, so it lands in your datadir automatically on extraction. Read it before starting opera:

   ```bash
   cat <datadir>/SNAPSHOT_INFO.txt
   ```

   The file lists the network, snapshot timestamp, binary version, tip block, tip epoch, and the full set of sealed upgrade flags. The tip block listed there is the minimum block number your first `New block` log line should show after restart. If `cat` returns nothing, the tarball did not extract correctly — do not start opera; re-extract at the datadir root.

   Current snapshot listing (public, no AWS credentials required):

   ```text
   https://vinu-blockchain-genesis.s3.amazonaws.com/?list-type=2&prefix=chaindata-snapshots/
   ```

   The tarball is flat (top-level is `chaindata/`, `go-opera/`, and `SNAPSHOT_INFO.txt` — no `datadir/` prefix to nest) and excludes `nodekey`, `keystore/`, `opera.ipc`, `static-nodes.json`, `trusted-nodes.json`, archived `chaindata.bak.*/`, and shell `history` files. New snapshots are published under `s3://vinu-blockchain-genesis/chaindata-snapshots/`. As of the v2.0.37 rollout, the last public object is `testnet-chaindata-v2.0.31-elemont-20260529T002920Z-clean`; publish a new snapshot after `VinuBLS12381` and again after `VinuLatestEVM` seal, or use a current validator-chaindata copy for internal RPC recovery.

5. Ensure `--nat extip:<your_public_ip>` is set and `<datadir>/go-opera/static-nodes.json` contains the canonical bootnode list from the [Start your node](#start-your-node) section.
6. Restart opera. The node resumes from the snapshot's tip and syncs forward. Expect `New DAG summary age=<few seconds>` within 1-2 minutes of restart.

**Trace/RPC recovery from a current validator datadir.** If no fresh public snapshot exists after a new seal, recover internal trace/RPC nodes from a current validator snapshot instead of replaying an old tarball. Stop one validator cleanly, archive only its active `<validator-datadir>/chaindata` directory, restart that validator, verify the archive checksum on the RPC host, then replace only the RPC node's `chaindata` while preserving `go-opera/nodekey` and static/trusted nodes. The 2026-06-03 trace RPC recovery used this path after an older May snapshot replayed historical forks under v2.0.37 and hit `wrong event epoch hash`; restoring current validator chaindata brought the trace node back at the current head with `eth_syncing=false` and working `trace_block("latest")`.

### Stuck at `net.peerCount == 1` with one stale peer

Symptom: `admin.peers` shows exactly one peer on a prior opera version, frozen at an old epoch. Your node catches up to that single peer's last block and then stops advancing.

This almost always means your enode record is advertising `127.0.0.1` (no peers outside that one random discovery hit can dial you back). Fix:

1. Confirm the startup log line `New local node record  ... ip=…` — if `ip=127.0.0.1`, `--nat extip` is missing.
2. Stop opera, add `--nat extip:<your_public_ipv4>` to the launch command, ensure `static-nodes.json` lists the canonical testnet bootnodes (see the [Start your node](#start-your-node) section), and restart.
3. Within a few minutes `net.peerCount` should be 4+ and `age` on `New DAG summary` lines should drop into the second / millisecond range.

If the peer count stays stuck at 1 after fixing `--nat`, check your host firewall / cloud security group: TCP and UDP on your `--port` (default 3000) must be open to `0.0.0.0/0`.

### Receipt `feeRefund` field is `0x0` after PaybackV2Patch

After the PaybackV2Patch seal, all `feeRefund` calculations resolve against corrected `QuotaContractV2` at `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4`. Existing depositors on the old V1 proxy at `0x824B93dE7221cf8a35FBd29d5202f6eFa3A29C5D` keep their stake balance there but no longer earn fee refunds, because the node stops consulting that contract once `Economy.QuotaCacheAddress` is swapped. To resume earning refunds, withdraw from V1 (`unstake()` then wait `holdTime` then `withdrawStake(wrID)`) and `stake()` on the corrected V2 with the same wallet.

If the transaction is already using corrected V2 and `feeRefund` is still `0x0`, check the sender's V2 Quota stake against `minStake()`. The sender must meet the contract minimum before any refund is available. On the corrected testnet deployment, the initial `minStake()` value is `1000 VC`, but the Quota owner can update it with `setMinStake(uint256)`; for `stakeFor(receiver)`, the receiver must meet the current minimum because the receiver is the refunding sender.

Verify activation:

```bash
curl -s -X POST https://vinufoundation-rpc.com \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getRules","params":["latest"],"id":1}' | jq '{quotaCache: .result.Economy.QuotaCacheAddress, paybackV2: .result.Upgrades.PaybackV2, paybackV2Patch: .result.Upgrades.PaybackV2Patch, sfcV2Patch6: .result.Upgrades.SfcV2Patch6}'
# Expect: {"quotaCache":"0x89d1cbd9deaab4dff6f800a336fbdd9a5c6829e4","paybackV2":true,"paybackV2Patch":true,"sfcV2Patch6":true}
```

### `vc_getPaybackBalance` returns `-32005`

The RPC-safe payback accessor is gated by a process-wide semaphore (8 in-flight, 2 s acquire timeout). Error code `-32005` is the rate-limit rejection. Clients should retry with exponential backoff; operators running high-volume scanners should either spread load across multiple RPC endpoints or reduce concurrent caller count. See [Changelog → Payback Fee Refunds](#payback-fee-refunds).

---

## Coordinated Upgrade Procedure

The recommended rollout:

1. VinuChain team announces the patch window. Date: TBD.
2. Pre-stage the binary on every validator before the window (Upgrade Steps step 2).
3. During the window, each operator performs the binary swap.
4. Confirm in the coordination channel that block production resumed and `opera version` reports `2.0.37-elemont`.

**Missed the window?** Patch6 sealed on testnet at block 1,460,329 in epoch 5801 on 2026-05-16. If your node was not already running v2.0.21 before that seal, a later binary swap will not replay the `SfcV2Patch6` edge and will not apply the automatic backfill. Stop the node, preserve `keystore/` and `go-opera/nodekey`, and restore from the latest post-seal chaindata snapshot in [Troubleshooting](#warn-incoming-event-rejected-err-wrong-event-epoch-hash) before rejoining.

After Shanghai, Cancun, Prague, VinuBLS12381, or VinuLatestEVM seals, the same rule applies to v2.0.37: nodes that missed the activation window should restore from the newest post-seal snapshot instead of replaying the edge at a different block.

---

## Contact

If you encounter issues during the upgrade, reach out to the VinuChain team through the official channels.

---

## Changelog

### Network upgrades

The codebase uses several internal upgrade names. The base SfcV2, Podgorica, and Elemont flags activate together when SfcV2 first fires; later testnet-only patch flags re-flash specific bytecode or operational state at their own epoch seals.

| Name                       | What it covers                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **SfcV2**                  | Replaces the on-chain SFC contract bytecode at `0xFC00FACE...` and turns on the 30% base fee burn.                                                                                                                                                                                                                                                                                                                                                                                                                            |
| **Podgorica**              | Payback fee refund mechanism. Source of the optional `feeRefund` field on receipts and transactions.                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **Elemont**                | Cheater fee zeroing at `SealEpoch` plus the broader v2.0+ release-series naming used in version strings.                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Shanghai**               | EVM execution compatibility with Ethereum Shanghai changes that apply to VinuChain: EIP-3651 warm coinbase, EIP-3855 `PUSH0`, and EIP-3860 initcode metering plus the 49,152-byte initcode limit.                                                                                                                                                                                                                                                                                                                             |
| **Cancun**                 | Selected Cancun/Dencun EVM compatibility that applies without blob transactions: EIP-1153 transient storage (`TLOAD` / `TSTORE`), EIP-5656 `MCOPY`, and EIP-6780 `SELFDESTRUCT` behavior.                                                                                                                                                                                                                                                                                                                                      |
| **Prague**                 | Scoped Prague/EIP-7702 compatibility for abstract-account delegation: set-code transaction type `0x04`, authorization lists, `0xef0100 || address` delegation designators, delegated EOA execution, and Prague-specific sender/txpool/event admission rules. Blob transaction type `0x03` remains unsupported.                                                                                                                                                                                                                 |
| **VinuBLS12381**           | VinuChain-specific EIP-2537/BLS12-381 precompile fork. Adds `BLS12_G1ADD`, `BLS12_G1MSM`, `BLS12_G2ADD`, `BLS12_G2MSM`, `BLS12_PAIRING_CHECK`, `BLS12_MAP_FP_TO_G1`, and `BLS12_MAP_FP2_TO_G2` at `0x0b`-`0x11` without coupling the rollout to upstream Prague/KZG behavior.                                                                                                                                                                                       |
| **VinuLatestEVM**          | VinuChain-specific latest-EVM compatibility fork. Adds P256VERIFY at `0x0100`, CLZ, MODEXP bounds/repricing, and EIP-7825 per-transaction gas-cap enforcement. This flag is intentionally separate from `VinuBLS12381` so BLS can bake first.                                                                                                                                                                                                                                                                                |
| **PaybackV2**              | Binary-level swap of `Economy.QuotaCacheAddress` from the original `TransparentUpgradeableProxy`-based Quota proxy to a freshly-deployed non-proxy `QuotaContractV2` whose owner is a recoverable EOA. Activates at the first epoch seal after the v2.0.18+ binary boots. Designed to escape the lost-ProxyAdmin-key state on the original proxy without losing access to existing depositor stake (V1 `unstake`/`withdrawStake` remain permissionless after activation; only the protocol-side backing balance is orphaned). |
| **PaybackV2Patch**         | One-shot testnet repair edge that rebinds an already-active PaybackV2 chain from the superseded V2 address to corrected `QuotaContractV2` `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4`.                                                                                                                                                                                                                                                                                                                                       |
| **SfcV2Patch6**            | One-shot testnet SFC bytecode re-flash to Cycle-162, adding orphan-delegation registration/backfill and an undelegate-to-zero fix for legacy orphaned stake pairs. v2.0.21 also performs the known live testnet delegation backfill in node state at the seal.                                                                                                                                                                                                                                                                |
| **Mainnet SfcV2 backfill** | Future mainnet `SfcV2` activation installs the latest Cycle-162 bytecode directly and now has a mainnet-only node-state backfill hook for the 82 live mainnet delegation rows audited on 2026-05-17. The list must be refreshed immediately before a mainnet activation release so newly-created missing rows are not missed.                                                                                                                                                                                                 |

Testnet has Shanghai, Cancun, Prague, the earlier SFC re-flashes (`SfcV2Patch2` / `SfcV2Patch3` / `SfcV2Patch4` / `SfcV2Patch5`), the `ElemontPubkeyValidation` sealer guard, PaybackV2, PaybackV2Patch, and the `SfcV2Patch6` edge. As of the v2.0.37 rollout, `VinuBLS12381` is staged on testnet and waiting for the next epoch seal; `VinuLatestEVM` stages after BLS is sealed. Current source enables mainnet SfcV2, Podgorica, ElemontPubkeyValidation, Shanghai, Cancun, and Prague for the planned hard fork and points fresh mainnet rules at the live Quota proxy. Mainnet still has no `SfcV2*` patch flags, no `PaybackV2`, no `VinuBLS12381`, and no `VinuLatestEVM` active in v2.0.37.

Recent execution-layer seal points on testnet:

| Flag       | Introduced | Sealed (testnet)            | Notes                                        |
| ---------- | ---------- | --------------------------- | -------------------------------------------- |
| `Shanghai` | v2.0.22    | 2026-05-17, block 1,461,622 | EIP-3651, EIP-3855, and EIP-3860 active     |
| `Cancun`   | v2.0.24    | 2026-05-18, block 1,461,786 | EIP-1153, EIP-5656, and EIP-6780 active     |
| `Prague`   | v2.0.28    | 2026-05-18, block 1,462,637 | EIP-7702 set-code transactions              |
| `VinuBLS12381` | v2.0.33 | Staged 2026-06-03; seal pending | BLS12-381 precompile fork                   |
| `VinuLatestEVM` | v2.0.34 | Deferred until `VinuBLS12381` seals | P256VERIFY, CLZ, MODEXP updates, tx gas cap |

### Release overview

| Version             | Type                                                                    | What changed                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **v2.0.37-elemont** | **Release hygiene + precompile vectors**                                | Bumps the release to `2.0.37-elemont` and consumes go-vinu `v1.20.24-quota`, carrying the broader precompile and MODEXP vector-test coverage used to validate the BLS12-381 / P256 / CLZ / MODEXP / gas-cap hard-fork surface. Deployed to testnet RPC + V1-V4 on 2026-06-03.                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **v2.0.36-elemont** | **VinuLatestEVM gas-cap enforcement**                                   | Enforces the VinuLatestEVM per-transaction gas cap in txpool, state transition, block execution, and `eth_estimateGas`, with focused tests for each path. This is the consensus-critical release for the latest-EVM gas-cap behavior.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **v2.0.35-elemont** | **Release bump**                                                        | Release hygiene bump after the latest-EVM implementation landed. Functional behavior is the v2.0.34 latest-EVM surface plus dependency/version updates.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **v2.0.34-elemont** | **Vinu latest-EVM fork + `eth_config`**                                  | Adds the `VinuLatestEVM` rule bit, RLP serialization, staged activation after `VinuBLS12381`, P256VERIFY / CLZ / MODEXP latest-EVM behavior via go-vinu, and the public `eth_config` RPC that reports sealed execution configuration and active precompiles.                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **v2.0.33-elemont** | **Vinu BLS12-381 fork**                                                 | Adds the `VinuBLS12381` rule bit, RLP serialization, staged activation after Prague, and BLS12-381 precompile activation at `0x0b`-`0x11`. Mainnet stays false for this flag until a separate activation release.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **v2.0.32-elemont** | **Mainnet hard-fork staging defaults**                                  | Stages the planned mainnet/staging SfcV2, Podgorica, ElemontPubkeyValidation, Shanghai, Cancun, and Prague defaults, and fixes the hardcoded mainnet Quota proxy pointer for fresh mainnet rule construction. Testnet consensus behavior is governed by its already-sealed flags plus later BLS/latest-EVM releases.                                                                                                                                                                                                                                                                                                                                                                                                  |
| **v2.0.31-elemont** | **Unprotected-tx guard hardening (non-consensus)**                      | Extracts the mainnet `AllowUnprotectedTxs` refusal from `NewService` into a tested `checkUnprotectedTxsPolicy` helper with all-network regression coverage so the guard cannot be silently dropped or separated from the flag, adds an `ethapi` call-site test proving the Arachnid carve-out is admitted only on mainnet (NetworkID 207) and refused elsewhere, and corrects the `--rpc.allow-unprotected-txs` usage string. No consensus or persisted-state change; activates no flag. Deployed to testnet RPC + V1-V4 on 2026-05-28.                                                                                                                                                                                                                                                                          |
| **v2.0.30-elemont** | **Mainnet Arachnid deployer allowlist (ERC-4337 enablement)**           | Adds `opera/unprotected_allowlist.go`, allowlisting exactly one pre-EIP-155 transaction on mainnet — the canonical Arachnid deterministic-deployment-proxy tx, pinned by exact hash `0xeddf9e61…033d26` — so the deterministic deployer (`0x4e59b448…4956C`) and, via CREATE2, the canonical ERC-4337 EntryPoint v0.7 (`0x0000000071727De…f37da032`) can eventually land on mainnet. Replay-benign (deploys a stateless, fund-less factory) and independent of `AllowUnprotectedTxs`, which stays refused on mainnet. Not yet deployed to mainnet.                                                                                                                                                                                                                                            |
| **v2.0.29-elemont** | **`--rpc.allow-unprotected-txs` flag (testnet AA enabler)**             | Exposes a `--rpc.allow-unprotected-txs` CLI flag wiring `gossip.Config.AllowUnprotectedTxs`, letting non-mainnet operators admit pre-EIP-155 (chain-id-less) transactions over RPC — the testnet enabler for the Arachnid deployer and the canonical EntryPoint. The existing `gossip/service.go` guard refuses the flag on mainnet (NetworkID 207). This release is what unlocked ERC-4337 account abstraction on testnet; keeps go-vinu at `v1.20.19-quota`.                                                                                                                                                                                                                                                                                                                          |
| **v2.0.28-elemont** | **Prague / EIP-7702 abstract-account release**                          | Adds the Prague upgrade flag on testnet and updates go-vinu to `v1.20.19-quota`. Enables EIP-7702 set-code transaction type `0x04`, authorization lists, delegated EOA execution via `0xef0100 || address`, JSON-RPC and signer round trips, CSER/event admission support, and txpool/light-txpool gates including delegated-sender and authority-reservation safeguards. Explicitly keeps blob transaction type `0x03` unsupported, leaves mainnet Prague disabled, and adds skipped-binary sequencing so Prague stages only after Cancun is active.                                                                                                                                                                                                 |
| **v2.0.26-elemont** | **EIP audit hardening**                                                  | Extends fork-aware Shanghai transaction validation into event admission, drops pre-Shanghai pending/queued contract creations that become invalid when Shanghai activates, keeps skipped intrinsic/initcode failures from mutating sender balance or block gas, and stages Cancun automatically after Shanghai seals on continuous nodes. Keeps go-vinu at `v1.20.17-quota`.                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **v2.0.25-elemont** | **Shanghai/Cancun local execution fix**                                  | Wires Shanghai transaction-level gas checks into VinuChain's local `evmcore` execution and txpool paths, adds regression coverage for local `evmcore`, sequences skipped-binary activation so Cancun cannot seal at the same height as Shanghai, and keeps go-vinu at `v1.20.17-quota`. Superseded by v2.0.26 for event-admission, txpool reset, skipped-transaction accounting, and no-restart Cancun staging hardening.                                                                                                                                                                                                                                                                                                                                                               |
| **v2.0.24-elemont** | **Cancun `SELFDESTRUCT` behavior**                                      | Updates go-vinu to `v1.20.17-quota` for EIP-6780-style `SELFDESTRUCT` behavior. Superseded by v2.0.25 because v2.0.24 did not yet wire the Shanghai transaction-level gas rules into VinuChain's local `evmcore` path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **v2.0.23-elemont** | **Cancun opcode support**                                               | Updates go-vinu to `v1.20.16-quota` and adds the `Cancun` upgrade flag for selected non-blob Cancun behavior: EIP-1153 transient storage and EIP-5656 `MCOPY`. Superseded by v2.0.25 for the local `evmcore` Shanghai gas fix and activation sequencing guard.                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **v2.0.22-elemont** | **Shanghai execution compatibility**                                    | Adds the `Shanghai` upgrade flag on testnet and updates go-vinu to `v1.20.15-quota`. Enables EIP-3651 warm coinbase access, EIP-3855 `PUSH0`, and EIP-3860 initcode metering plus the 49,152-byte initcode limit. Superseded by v2.0.25 because VinuChain's local `evmcore` transaction path also needed the Shanghai transaction-level gas checks. Mainnet remains prepared but disabled until a separately coordinated release flips the mainnet rule.                                                                                                                                                                                                                                                                                 |
| **v2.0.21-elemont** | **SfcV2 automatic delegation backfill**                                 | Keeps the Cycle-162 SFC bytecode and adds activation-time node storage repair for the three known live testnet validator-1 delegation rows missing from `stakes[]`. Also pre-wires mainnet `SfcV2` activation to backfill the 82 live mainnet rows audited on 2026-05-17. The repair runs only if each pair still has non-zero `getStake`, validates whether the row is already present, and handles stale `stakePosition` values that point at a different stake.                                                                                                                                                                                                                                                                                                                    |
| **v2.0.20-elemont** | **Testnet SfcV2Patch6 bytecode release**                                | Adds the `SfcV2Patch6` testnet epoch edge and Cycle-162 SFC bytecode. New SFC version `3.0.5` adds `registerStake(uint256)` for delegator self-registration, owner-only `backfillStakes(address[],uint256[])` for bounded batch remediation, and an orphan-tolerant full undelegate-to-zero path for legacy pairs where `getStake > 0` but `stakePosition == 0`. Superseded by v2.0.21 before testnet Patch6 sealed so the known live missing rows are backfilled automatically.                                                                                                                                                                                                                                                                                                      |
| **v2.0.19-elemont** | **Testnet PaybackV2Patch corrected contract rebind**                    | Deployed corrected `QuotaContractV2` `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4` on 2026-05-16 (tx `0xd99e4111a87dee6b9a16802f9696f5e6663d953ff7de54e43572ab75f8241ce4`, owner = recoverable EOA `0xf9c82B1117e8BeA97843042521B8FBC93044f347`). Adds `Upgrades.PaybackV2Patch = true` on testnet so the next epoch seal rebinds `Economy.QuotaCacheAddress` from the superseded V2 address to the corrected staker-owned withdrawal contract.                                                                                                                                                                                                                                                                                                                                        |
| **v2.0.18-elemont** | **Testnet PaybackV2 activation (binary-level Quota proxy replacement)** | Tagged and deployed to testnet RPC + V1–V4 on 2026-05-15. Flips `Upgrades.PaybackV2 = true` on `VinuChainTestNetRules`. At the first epoch seal after binary boot, the seal-time activation branch in `gossip/block_processor.go::sealEpochIfNeeded` swaps `Economy.QuotaCacheAddress` from the V1 proxy `0x824B93dE7221cf8a35FBd29d5202f6eFa3A29C5D` (lost-ProxyAdmin-key) to `QuotaContractV2` at `0xdEA4687FDBA2528d1b30222e199c90b63AF8c850` (deploy tx `0x3ed6fc5e1f0b6c14aaf74f9cfbc611ee5eae7973f4aa10f608d4605020bb505a`, owner = recoverable EOA `0xf9c82B1117e8BeA97843042521B8FBC93044f347`). Post-release testing on 2026-05-16 found that this deployed V2 address assigns third-party `stakeFor(receiver)` withdrawal ownership to the receiver; v2.0.19 supersedes it. |
| v2.0.17-elemont     | Payback/Quota receiver staking                                          | Deployed to testnet RPC + validators on 2026-05-10. The node PaybackCache recognizes `stakeFor(address)` as Payback quota credit for the receiver, preserving same-epoch duration accounting for the refunding address. The V1 receiver-implementation rollout was **superseded** by v2.0.18-elemont's PaybackV2 binary-level Quota proxy replacement and v2.0.19-elemont's corrected V2 rebind.                                                                                                                                                                                                                                                                                                                                                                                      |
| **v2.0.14-elemont** | Testnet consensus flags (Patch5 + ElemontPubkeyValidation)              | Cycle-161 SFC bytecode. Adds canonical-pubkey validation (`length == 66 && pubkey[0] == 0xc0`) at `createValidator`, `_rawCreateValidator`, and `NodeDriverAuth.updateValidatorPubkey`. Off-chain sealer guard ejects validators with malformed stored pubkeys (testnet validator 16) at the next epoch seal. Also: real `gasUsedRatio` in `eth_feeHistory`.                                                                                                                                                                                                                                                                                                                                                                                                                          |
| v2.0.13-elemont     | Same-day scaffolding (no live activation)                               | Defines flags + ships the deadbeef-placeholder Cycle-161 bytecode; flipped to v2.0.14 same day with the real bytecode and activation. Don't deploy v2.0.13 standalone.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| v2.0.12-elemont     | Diagnostic + tooling                                                    | Multi-`SfcV2Patch*` divergence warn at single seal; chaindata snapshot producer (`scripts/create-chaindata-snapshot.sh` with `SNAPSHOT_INFO.txt`). Non-consensus.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| v2.0.11-elemont     | Testnet consensus flag (Patch4)                                         | Cycle-160 SFC bytecode. Fixes `_lockStake` / `relockStake`: invariant becomes `endTime >= ld.endTime`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| v2.0.10-elemont     | Testnet consensus flag (Patch3)                                         | Cycle-159 SFC bytecode. Fixes inline reentrancy guard (`_reentrancyGuardCounter < 2`); unblocks `delegate`, `undelegate`, `withdraw`, `claimRewards`, `restakeRewards`, `stashRewards`, `createValidator`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| v2.0.9-elemont      | Trusted-preset entry                                                    | Recognizes `vitainu-genesis-testnet-20260419.g` — fresh installs no longer need `--genesis.allowExperimental`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| v2.0.8-elemont      | Hotfix                                                                  | Removes `validatePeerProgress` drift caps so long-offline validators can rejoin.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| v2.0.7-elemont      | Hotfix                                                                  | Raises per-peer event-processing quota to 3,250 (matches `EventsBufferLimit.Num`); kills the warning storm during sync.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| v2.0.6-elemont      | RPC addition                                                            | New `vc_getPaybackBalance` JSON-RPC method (rate-limited).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| v2.0.5-elemont      | Testnet consensus flag (Patch2)                                         | Cycle-158 SFC bytecode re-flash at `0xFC00FACE...`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| v2.0.4-elemont      | Internal                                                                | lachesis-base bumped to `v0.1.6-elemont`: vecengine cap, dagprocessor drain, kvdb flushable race fix, gossip deadlock fix.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| v2.0.3-elemont      | RPC defensive caps                                                      | go-vinu fork `v1.20.14-quota`: batch-size cap (100), in-flight cap (50, configurable), state-override caps.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| v2.0.2-elemont      | Consensus rules                                                         | `feeRefund` receipt field, 30% base fee burn, cheater fee zeroing, payback fee refunds.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |

Mainnet has not yet activated Shanghai, Cancun, Prague, or any `SfcV2*` flag — when it activates `SfcV2`, the latest bytecode (Cycle-162) installs directly and the mainnet-only node hook backfills the audited missing delegation rows; the testnet patch flags do not fire on mainnet.

{% hint style="info" %}
**Activation timing.** Consensus flags and seal-bound rebinding (`SfcV2`, `Podgorica`, `Elemont`, `Shanghai`, `Cancun`, `Prague`, `VinuBLS12381`, `VinuLatestEVM`, `SfcV2Patch2/3/4/5/6`, `ElemontPubkeyValidation`, `PaybackV2`, `PaybackV2Patch`, and v2.0.2 rules) activate at the **next epoch seal** after the binary is first installed or the pending `DirtyRules` edge is staged (up to `MaxEpochDuration = 4h`). On skipped-binary boots, v2.x deliberately stages Shanghai before Cancun, Cancun before Prague, Prague before VinuBLS12381, and VinuBLS12381 before VinuLatestEVM; each follow-up flag is staged by the same continuous node after its predecessor seals, without a restart. RPC caps, RPC additions, peer-quota resize, drift-cap removal, `eth_feeHistory.gasUsedRatio` fix, lachesis-base internals, and non-consensus release hygiene are **immediate on restart**, no epoch-seal wait.
{% endhint %}

### `feeRefund` receipt field

Transaction receipts include an optional `feeRefund` field (hex-encoded wei) for transactions where the sender received a gas refund. The field is **omitted** when there is no refund — receipts for ineligible senders look identical to pre-upgrade receipts.

```json
{
  "transactionHash": "0x...",
  "gasUsed": "0x5208",
  "feeRefund": "0x2386f26fc10000"
}
```

The same field also appears on the transaction object returned by `eth_getTransactionByHash`, `eth_getTransactionByBlockHashAndIndex`, and `eth_getTransactionByBlockNumberAndIndex`.

**Consumer impact.** Most JSON parsers ignore unknown fields → non-breaking. Strict-schema validators must allow optional `feeRefund` (hex string). Off-chain receipt-hash computers must include it when present.

### SFC V2 contract upgrade

When `SfcV2` activates, the on-chain SFC contract at `0xfc00face00000000000000000000000000000000` is rewritten with V2 bytecode. Existing function selectors remain stable — dApps and on-chain contracts calling pre-existing SFC methods continue to work without modification. Cycle-162 only extends the ABI with new orphan-delegation recovery helpers. All existing delegations, stakes, and validator registrations remain valid.

Subsequent testnet patches re-flash the same address with newer bytecode at additional epoch seals:

| Patch         | Introduced | Sealed (testnet)            | Bytecode                                     |
| ------------- | ---------- | --------------------------- | -------------------------------------------- |
| `SfcV2Patch2` | v2.0.5     | Mid-v2.0.5 boot             | Cycle-158 (45,240 bytes)                     |
| `SfcV2Patch3` | v2.0.10    | 2026-04-19, block 1,424,440 | Cycle-159 — inline reentrancy guard fix      |
| `SfcV2Patch4` | v2.0.11    | 2026-04-23, block 1,430,436 | Cycle-160 — `_lockStake` / `relockStake` fix |
| `SfcV2Patch5` | v2.0.14    | Active by 2026-05-17        | Cycle-161 — canonical-pubkey validation      |
| `SfcV2Patch6` | v2.0.21    | 2026-05-16, block 1,460,329 | Cycle-162 — orphan-delegation auto-backfill  |

Cycle-162 extends the ABI with `RegisteredStake`, `registerStake(uint256)`, and `backfillStakes(address[],uint256[])`; earlier Cycle-158/159/160/161 selectors remain stable. Binary startup guards (`sfc.EnforcePatch4StartupCheck`, `sfc.EnforcePatch5StartupCheck`, and `sfc.EnforcePatch6StartupCheck`) refuse to start a build with invalid embedded SFC patch bytecode.

**Blockscout verification.** Bytecode swaps via the evmwriter precompile bypass Blockscout's normal contract-discovery path. After each seal, re-verify with: `DELETE` the stale `smart_contracts` row, `UPDATE addresses.contract_code` with fresh `eth_getCode`, then `POST /api/v2/smart-contracts/.../verification/via/flattened-code`. Solc settings: `0.5.17+commit.d19bba13`, `--optimize --optimize-runs=10000 --evm-version=istanbul`. Source: [`vinuchain-lists/contracts/vinuchain/SFC.sol`](https://github.com/VinuChain/vinuchain-lists/blob/main/contracts/vinuchain/SFC.sol).

### EIP-7702 set-code transactions

When `Prague` is active, VinuChain accepts EIP-7702 set-code transactions (`type: 0x04`). These transactions carry an `authorizationList`; each authorization can install or clear a delegation designator on an EOA. The installed code shape is `0xef0100` followed by the 20-byte target address. Contract calls to the delegated EOA execute one level of target code while preserving the delegated EOA as the account being called.

Important boundaries:

- Blob transactions (`type: 0x03`) remain unsupported and are rejected.
- Set-code transactions must have a non-empty `authorizationList` and a concrete `to` address; they cannot be contract creations.
- Authorization `chainId`, `r`, and `s` fields must fit uint256 bounds. Invalid authorization signatures are skipped according to EIP-7702, but malformed over-width tuple values are rejected before execution.
- EIP-3607 sender validation is relaxed only after Prague and only for accounts whose code is a valid EIP-7702 delegation designator.
- JSON-RPC transaction objects include `authorizationList` for set-code transactions. Existing non-set-code transaction responses are unchanged.
- No contracts, ABIs, token lists, SFC bytecode, or deployed-address registries change for this upgrade.

### BLS12-381 and latest-EVM surfaces

`VinuBLS12381` and `VinuLatestEVM` are intentionally separate VinuChain fork flags. BLS activates first; latest-EVM activates only after BLS is already sealed. This avoids bundling every new precompile, opcode, and gas-rule change into one epoch seal.

After `VinuBLS12381` is active:

- `eth_config.current.precompiles` includes `BLS12_G1ADD`, `BLS12_G1MSM`, `BLS12_G2ADD`, `BLS12_G2MSM`, `BLS12_PAIRING_CHECK`, `BLS12_MAP_FP_TO_G1`, and `BLS12_MAP_FP2_TO_G2`.
- The active precompile addresses are `0x0b` through `0x11`.
- Mainnet remains false for this flag in v2.0.37.

After `VinuLatestEVM` is active:

- `eth_config.current.precompiles` includes `P256VERIFY` at `0x0000000000000000000000000000000000000100`.
- CLZ and MODEXP bounds/repricing are active through the go-vinu EVM.
- Transactions above the per-transaction gas cap are rejected consistently in txpool, state transition, and block execution; `eth_estimateGas` caps estimates at the same limit.
- Mainnet remains false for this flag in v2.0.37.

Before either flag seals, `eth_config` continues to show the last sealed configuration. Use `vc_getRules("latest")` after each epoch seal to verify the rule bit, then re-run precompile/opcode smoke checks.

### 30% base fee burn

When `SfcV2` is active, 30% of each transaction's **base fee** is burned. The remaining 70% of the base fee plus **all priority tips** continue to flow to the validator.

```text
baseFeeUsed = baseFee × gasUsed
burnAmount = baseFeeUsed × 30%   (capped at the validator's fee share)
validatorEarnings = transactionFee - feeRefund - burnAmount
```

- Priority tips are never burned.
- Refunds are calculated first, then the burn is applied to what remains.
- Burned funds accumulate at the zero address `0x0000…0000`. There is no separate burn counter — indexers tracking circulating supply should subtract the zero-address balance.

### Cheater fee zeroing

When Elemont is active, validators flagged as cheaters in an epoch lose **all** their accumulated transaction fees for that epoch at `SealEpoch` time — including fees from blocks they produced before being flagged.

### Payback fee refunds

Stakers meeting the minimum V2 Quota stake threshold automatically receive gas refunds. **No new VC is created** — refunds redistribute fees from validator earnings to eligible stakers. On the corrected 2026-05-16 testnet deployment, the initial `QuotaContractV2.minStake()` value is `1000 VC`; the Quota owner can update this parameter later if protocol economics change.

1. User submits a transaction; full `gasUsed × gasPrice` is debited as before.
2. Full fee is credited to the validator pre-refund.
3. After epoch seal, the payback system queries the sender's stake. If eligible, a refund is returned from the validator's earned fees.
4. Validator earnings decrease by the refund; sender balance increases by it.

With PaybackV2, a funding wallet may call `QuotaContractV2.stakeFor(receiver)` instead of `stake()`. The receiver receives Payback quota credit, so refunds still follow the transaction sender: the receiver gets refunds for transactions the receiver signs, while the funding wallet does not gain refund eligibility from that delegated stake. The funding wallet keeps ownership of the VC it funded and must use `unstakeFor(receiver, amount)` to begin withdrawing that stake back to itself. The receiver's total V2 Quota stake must be at least `minStake()` before those signed transactions can receive refunds.

The minimum stake is only an eligibility floor, not a spam throttle that grows automatically. Each refund is capped by the sender's available Payback quota, and every refunded transaction consumes quota for that epoch. If an eligible wallet sends enough transactions to exhaust its quota, later transactions receive smaller refunds or `feeRefund: 0x0`; they still pay normal gas. When network congestion pushes the base fee above the chain-configured floor, Payback refunds are suppressed so fee escalation can still deter spam.

The `feeRefund` receipt field reports the refund amount. dApps showing "gas spent" should subtract `feeRefund` from `gasUsed × effectiveGasPrice`.

#### `vc_getPaybackBalance`

| Field      | Value                                                                                                  |
| ---------- | ------------------------------------------------------------------------------------------------------ |
| Namespace  | `vc` (not `eth`)                                                                                       |
| Method     | `vc_getPaybackBalance`                                                                                 |
| Params     | `[address]` (20-byte hex). Optional second param: block tag (default `"latest"`).                      |
| Returns    | Hex-encoded wei. Returns `0x0` for the zero address, when Podgorica is inactive, or sub-minimum stake. |
| Rate limit | 8 in-flight, 2 s acquire timeout. Rejection error `-32005` `payback query rate-limited`.               |

```bash
curl -s -X POST http://localhost:18545/ \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"vc_getPaybackBalance","params":["0xABCDEF0123456789ABCDEF0123456789ABCDEF01"],"id":1}'
```

The `vc` namespace is intentionally separate from `eth` — the accessor is RPC-safe (never reads/writes `PaybackCache.blkCtx`, never mutates `StakesMap`), so concurrent RPC traffic cannot corrupt block-processing state.

### JSON-RPC defensive caps

| Cap                               | RPC method(s)                                    | Limit                                                           | Error on exceed                       |
| --------------------------------- | ------------------------------------------------ | --------------------------------------------------------------- | ------------------------------------- |
| Batch size                        | Any batched call                                 | 100 messages per batch                                          | `invalid request: batch too large`    |
| In-flight concurrency             | All HTTP & WS RPC                                | 50 concurrent (`--rpc.maxconcurrent N` to tune; `0` to disable) | HTTP 503                              |
| `StateOverride.code` size         | `eth_call`, `eth_estimateGas`, `debug_traceCall` | 24,576 bytes per account                                        | `code size exceeds MaxCodeSize`       |
| `StateOverride.stateDiff` entries | same as above                                    | 1,000 entries per account                                       | `stateDiff size exceeds 1000 entries` |
| `feeRefund` P2P ingress           | Internal (peer RLP decoding)                     | 32 bytes / 256 bits                                             | Peer drops the receipt                |
| Graceful shutdown                 | Any RPC method during shutdown                   | Handler returns proper JSON-RPC error                           | `handler is stopping`                 |

Indexers batching block-range queries should paginate at ≤100 messages. Heavy analytics workloads can raise concurrency with `--rpc.maxconcurrent N` or distribute across endpoints.

### Pruning

Operator-facing controls for managing chaindata size on long-lived nodes.

| Surface                         | Purpose                                                                                                                                                                     |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--prune-keep-epochs <N>`       | Retain the last N sealed epochs of state; prune older. Negative values are rejected with a clear error (previously wrapped to large unsigned values and pruned everything). |
| `--prune-keep-blocks <N>`       | Same semantics, applied to receipt/log retention.                                                                                                                           |
| `opera snapshot prune-receipts` | One-shot subcommand for fine-grained receipt retention control outside the live retention flags.                                                                            |

**Crash-safe.** If a prune operation is interrupted (node crash, OOM kill), the next startup automatically resumes the interrupted prune — no manual intervention. The `Snapshots count=128` default produces enough snapshot density for prune to find recoverable boundaries on restart.

### Other reliability fixes

- **Peer-progress drift caps removed (v2.0.8).** `validatePeerProgress` no longer rejects peers more than 1,000 epochs / 5,000 blocks ahead. The deeper acceptance gate (`lightCheck`, `epochcheck.ErrNotRelevant`) already prevents abuse.
- **Per-peer event quota raised (v2.0.7).** `peerEventQuota` and `peerStreamQuota` raised from 200/100 to 3,250 (matches `EventsBufferLimit.Num`). DoS guarantee preserved by `Config.Validate()` — a single peer is bounded to ≤50% of capacity.
- **Tracing.** `trace_filter` with `Count==0` caps at 10,000 entries (was unbounded). Span-leak fix on tracing on/off. `traceBlock` bounds-checks malformed receipts.
- **`eth_feeHistory`** copies the tips slice per entry (was sharing backing array — mutations cross-contaminated).
- **Gas accounting.** Block-vote gas calc uses overflow-safe addition. Gas oracle guards against `MaxAllocPeriod=0`. `MinGasPrice=0` is rejected.
- **EVM.** `eth_call` enforces `MaxCodeSize` even when code comes from `stateOverride`.

---

_Last updated: 2026-06-03 · latest guide target `v2.0.37-elemont` · ERC-4337 account abstraction live on testnet · latest public pre-v2.0.37 snapshot `testnet-chaindata-v2.0.31-elemont-20260529T002920Z-clean.tar.gz` · corrected PaybackV2 address `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4` · `VinuBLS12381` staged and `VinuLatestEVM` pending after BLS seal · SFC Cycle-162 `version() = 3.0.5` · go-vinu `v1.20.24-quota` · lachesis-base `v0.1.6-elemont`_
