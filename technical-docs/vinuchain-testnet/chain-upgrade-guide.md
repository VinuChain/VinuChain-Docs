<!-- markdownlint-disable MD013 -->

# Chain Upgrade Guide (v2-elemont)

## Latest release

| Version           | Network | Status                                      |
| ----------------- | ------- | ------------------------------------------- |
| `v2.0.28-elemont` | Testnet | Deployed; Prague staged for next epoch seal |

## What's new

- Adds the Prague execution-layer upgrade flag on testnet.
- Enables EIP-7702 set-code transactions (`type: 0x04`) with authorization lists and EOA delegation designators (`0xef0100 || address`).
- Keeps blob transactions (`type: 0x03`) unsupported; this is a scoped Prague/EIP-7702 release, not a full Pectra/blob rollout.
- Wires EIP-7702 through go-vinu transaction types/signing, VinuChain `evmcore`, txpool, event admission, CSER event serialization, JSON-RPC transaction input/output, light txpool, and signer paths.
- Sequences skipped-binary activation so a node booting from pre-Shanghai state stages Shanghai first, Cancun after Shanghai, and Prague after Cancun.
- Keeps the v2.0.21 Cycle-162 SFC / Patch6 backfill behavior and the corrected PaybackV2 address from v2.0.19: `QuotaContractV2` at `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4`.
- Does not deploy or re-flash any contracts. `vinuchain-lists` does not need a companion contract, ABI, or registry update for EIP-7702.
- Leaves mainnet Shanghai, Cancun, and Prague disabled until a separately scheduled mainnet release flips the hardcoded mainnet rule.

## Current Testnet Rollout State

`v2.0.28-elemont` was built on the testnet hosts and deployed to the public trace RPC plus validators V1-V4 on 2026-05-18 between 18:01 UTC and 18:05 UTC. The deployed client string is `go-opera/v2.0.28-elemont-d62ab5a0-1779127036/linux-amd64/go1.26.2`.

Post-deploy verification confirmed the trace RPC still serves `trace_block`, all four validator services are active, and the RPC log contains:

```text
Staged Prague upgrade from binary rules; will activate at next epoch seal
```

At 2026-05-18 18:16 UTC, `vc_getRules("latest")` still reported `Upgrades.Prague = false` at epoch `0x16b6`, which is expected until the pending epoch seals. After the seal, update this guide with the Prague activation block and publish the post-Prague snapshot before using v2.0.28 for fresh testnet nodes.

---

## Network Details

| Network | Chain ID   | RPC                              | Status          |
| ------- | ---------- | -------------------------------- | --------------- |
| Mainnet | 207 (0xcf) | `https://vinuchain-rpc.com`      | Upgrade pending |
| Testnet | 206 (0xce) | `https://vinufoundation-rpc.com` | v2.0.28 deployed; Prague pending seal |

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
**Fresh install?** This guide covers binary swaps on existing validator nodes. If you're bootstrapping a brand-new testnet node, replay from genesis is **not supported under v2.0.28** — follow the snapshot-restore procedure in [Troubleshooting → Wrong event epoch hash](#warn-incoming-event-rejected-err-wrong-event-epoch-hash) instead. Do not use this v2.0.28 guide as a routine pre-activation mainnet genesis-replay path: the binary hardcodes the future mainnet `SfcV2` activation and stages that transition at the next epoch seal when run on a pre-SfcV2 mainnet datadir.
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
git checkout v2.0.28-elemont
make opera
# Binary is at $HOME/vinuchain-upgrade/build/opera
```

{% endcode %}

Substitute `/opt/vinuchain-upgrade` (or any other path) if `$HOME` is not the right partition for your setup — every later command in this guide that references `$HOME/vinuchain-upgrade` should be adjusted to match.

{% hint style="info" %}
**Dependency pins.** `v2.0.28-elemont` uses go-vinu `v1.20.19-quota` for Shanghai, selected Cancun execution support, Prague/EIP-7702 set-code transactions, and txpool authority reservation safeguards. It keeps lachesis-base at `v0.1.6-elemont`. `make opera` fetches dependencies on first build.
{% endhint %}
{% endstep %}

{% step %}

#### Verify the new binary

The newly-built binary is at `vinuchain-upgrade/build/opera`. Move into that directory so the rest of the steps can use a relative `./opera` path:

```bash
cd $HOME/vinuchain-upgrade/build
./opera version
# Expected: Version: 2.0.28-elemont
```

{% hint style="info" %}
`opera version` prints `2.0.28-elemont` — this matches the git tag `v2.0.28-elemont`. See the note at the top of this page.
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

**Startup banner.** Every v2.x build prints the VinuChain banner. This is the first visual confirmation that you are running v2.0.28-elemont and not the previous binary:

```text
 ██╗   ██╗██╗███╗   ██╗██╗   ██╗ ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
 ██║   ██║██║████╗  ██║██║   ██║██╔════╝██║  ██║██╔══██╗██║████╗  ██║
 ██║   ██║██║██╔██╗ ██║██║   ██║██║     ███████║███████║██║██╔██╗ ██║
 ╚██╗ ██╔╝██║██║╚██╗██║██║   ██║██║     ██╔══██║██╔══██║██║██║╚██╗██║
  ╚████╔╝ ██║██║ ╚████║╚██████╔╝╚██████╗██║  ██║██║  ██║██║██║ ╚████║
   ╚═══╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

                        v2.0  -  ELEMONT

  Version: 2.0.28-elemont
```

**Staging logs (testnet only, first-time Shanghai/Cancun/Prague install).** On the first v2.0.28 boot of a node that has not yet sealed Shanghai, you will see Shanghai staged while Cancun and Prague are deferred:

```text
INFO Staged Shanghai upgrade from binary rules; will activate at next epoch seal
INFO Deferring Cancun upgrade from binary rules until Shanghai is active
INFO Deferring Prague upgrade from binary rules until Cancun is active
```

This confirms EIP-3651, EIP-3855, and EIP-3860 are pending for the next epoch seal, while Cancun is intentionally held back so skipped-binary nodes do not collapse Shanghai and Cancun into the same activation height.

After `vc_getRules` reports `Upgrades.Shanghai = true`, v2.0.28 stages Cancun automatically on the same continuous process:

```text
INFO Staged Cancun upgrade from binary rules; will activate at next epoch seal
INFO Deferring Prague upgrade from binary rules until Cancun is active
```

This confirms EIP-1153, EIP-5656, and EIP-6780 behavior are pending for the next epoch seal.

After `vc_getRules` reports `Upgrades.Cancun = true`, v2.0.28 stages Prague automatically on the same continuous process:

```text
INFO Staged Prague upgrade from binary rules; will activate at next epoch seal
```

On current post-Cancun testnet datadirs, Prague is the only new first-boot staging line expected. It confirms EIP-7702 set-code transaction handling is pending for the next epoch seal. If you do not see a staging line, you may be running the wrong binary (`opera version` check), the flag may already be pending in `DirtyRules` from an earlier v2.0.28 boot, or the flag may already be sealed on this datadir. Absence of the staging line by itself is not proof that the fork has sealed; confirm with `vc_getRules`. Mainnet and staging nodes do not show these lines because `VinuChainMainNetRules` keeps Shanghai, Cancun, and Prague disabled until coordinated mainnet releases.

**Older staging logs (testnet only, first-time SfcV2Patch6 install).** Nodes upgrading from before v2.0.21 that have not yet sealed SfcV2Patch6 can also see this older staging line:

```text
INFO Staged SfcV2Patch6 upgrade from binary rules; will activate at next epoch seal
```

This confirms the Cycle-162 SFC bytecode re-flash and automatic testnet delegation backfill are pending. Mainnet nodes never show this line because SfcV2Patch6 is testnet-only. Nodes upgrading directly from v2.0.18 or earlier may also see the older `Staged PaybackV2Patch ...` line if that edge has not yet sealed on their datadir.

**Seal-time activation (testnet only).** At the next epoch seal after Shanghai staging, `vc_getRules` must report `Upgrades.Shanghai = true`. At the next epoch seal after Cancun staging, it must also report `Upgrades.Cancun = true`. At the next epoch seal after Prague staging, it must also report `Upgrades.Prague = true`. There is no SFC bytecode re-flash, contract address change, or registry update for these EVM fork flags.

If SfcV2Patch6 is also still pending, the same seal can include the older SFC Patch6 re-flash:

```text
INFO Re-applying SFC V2 bytecode upgrade (patch 6) block=<N>
```

If the node writes SFC storage, you will also see the backfill log:

```text
INFO Backfilled SFC Patch6 testnet delegations block=<N> appended=3 repaired=0
```

If every listed pair is already visible in `stakes[]` or has dropped to zero stake, the re-flash log can appear without a `Backfilled ...` line. After it fires, `vc_getRules` must report `Upgrades.SfcV2Patch6 = true`, and `eth_call` to SFC `version()` must return `0x333035` (`"305"`). The `Backfilled ...` counts are lower if a listed pair already became visible or dropped to zero stake before the seal; `repaired` may be non-zero if a pair is present in `stakes[]` but its `stakePosition` points at a stale row. `Economy.QuotaCacheAddress` remains the corrected PaybackV2 address `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4`.

**Future mainnet SfcV2 activation.** When mainnet activation is explicitly scheduled, the first v2.0.28+ boot on a pre-SfcV2 mainnet datadir stages `SfcV2`, not `SfcV2Patch6`:

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
| `opera version`                                           | `Version: 2.0.28-elemont`                                                                                                                             |
| Block production                                          | Resumes within seconds of startup; block numbers advance                                                                                              |
| Peer count                                                | Returns to prior steady-state within minutes                                                                                                          |
| Shanghai staging logs (testnet, first pre-Shanghai v2.0.28 boot) | 1× `Staged Shanghai upgrade …`; Cancun and Prague may log as deferred until predecessors are active                                                    |
| Shanghai rule after seal                                  | `vc_getRules` reports `Upgrades.Shanghai = true`                                                                                                      |
| Cancun staging logs (testnet, post-Shanghai v2.0.28 process) | 1× `Staged Cancun upgrade …` after Shanghai seals; no restart required                                                                                 |
| Cancun rule after seal                                    | `vc_getRules` reports `Upgrades.Cancun = true`                                                                                                        |
| Prague staging logs (testnet, post-Cancun v2.0.28 process) | 1× `Staged Prague upgrade …` after Cancun seals; current post-Cancun testnet nodes should see this on first boot                                      |
| Prague rule after seal                                    | `vc_getRules` reports `Upgrades.Prague = true`                                                                                                        |
| EIP-7702 transaction support after Prague seal             | Set-code transactions (`type: 0x04`) accepted; blob transactions (`type: 0x03`) remain rejected                                                        |
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

Before Prague seals, rollback is a normal binary swap back to the previous testnet binary. After Prague seals, do not roll back below v2.0.28 without operator coordination: older binaries do not know the `Prague` upgrade bit, set-code transaction type `0x04`, EIP-7702 authorization lists, or delegated EOA execution rules. The earlier Shanghai/Cancun rollback constraints still apply: after Shanghai seals, do not roll back below v2.0.26 without operator coordination, and after Cancun seals do not roll back below the release that sealed Cancun on that datadir.

The earlier SfcV2Patch6 rollback constraints still apply. After SfcV2Patch6 seals, do not roll back below v2.0.21 without operator coordination: the Cycle-162 bytecode and automatic testnet delegation backfill persist in chain state, and older binaries do not contain the activation-time backfill logic. The corrected PaybackV2 v2.0.19 rollback constraints still apply if PaybackV2Patch was also part of the node's upgrade path.

For the future mainnet `SfcV2` release, rollback before the mainnet SfcV2 seal is a normal coordinated binary rollback. After mainnet SfcV2 seals, do not roll below the activation binary without operator coordination: Cycle-162 SFC bytecode and the mainnet delegation backfill persist in chain state. Fresh or recovering mainnet nodes should use a post-SfcV2 snapshot once that activation has happened; replaying from a pre-activation genesis/datadir under a different binary can re-stage the transition at the wrong seal.

1. Stop the node (clean shutdown).
2. Replace `opera` with a prior elemont release binary (e.g., v2.0.10-elemont, v2.0.9-elemont, or earlier).
3. Start the node.

No datadir changes are needed for a pre-seal rollback. A post-seal rollback must be treated as a coordinated incident response, not a routine downgrade.

{% hint style="info" %}
**Per-version rollback deltas.** Each bullet describes the only functional difference between the two versions.

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
2. Verify the binary: `opera version` must print `2.0.28-elemont`.
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
**Do not resync from genesis on testnet.** A fresh replay stages not-yet-sealed upgrade flags at replay time — at a different block from the live chain's historical activations — so the epoch state hash diverges immediately. Use the latest published post-seal snapshot below instead. Snapshots taken before the Prague, Shanghai, Cancun, SfcV2Patch6, or PaybackV2Patch seals are stale for fresh installs after those upgrades because they can re-fire edges at the wrong replay seal.
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

4. Download the latest testnet snapshot and extract it in-place over the datadir (the tar is written with relative paths, so extract at the datadir root; the tar excludes `nodekey`, `keystore/`, `opera.ipc`, `static-nodes.json`, `trusted-nodes.json` so your identity files are preserved). Use the latest post-Prague snapshot after Prague seals. Until that snapshot is published, the exact post-Cancun snapshot below remains valid only for nodes joining before the Prague seal.

   ```bash
   cd <datadir>
   SNAPSHOT_URL="https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.24-elemont-20260518T005603Z-clean.tar.gz"
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

   Current snapshot listing (public, no AWS credentials required). If the listing still contains older objects, treat them as archival and use the exact v2.0.24 URL above:

   ```text
   https://vinu-blockchain-genesis.s3.amazonaws.com/?list-type=2&prefix=chaindata-snapshots/
   ```

   The tarball is flat (top-level is `chaindata/`, `go-opera/`, and `SNAPSHOT_INFO.txt` — no `datadir/` prefix to nest) and excludes `nodekey`, `keystore/`, `opera.ipc`, `static-nodes.json`, `trusted-nodes.json`, archived `chaindata.bak.*/`, and shell `history` files. New snapshots are published under `s3://vinu-blockchain-genesis/chaindata-snapshots/`; the current published object is `testnet-chaindata-v2.0.24-elemont-20260518T005603Z-clean`.

5. Ensure `--nat extip:<your_public_ip>` is set and `<datadir>/go-opera/static-nodes.json` contains the canonical bootnode list from the [Start your node](#start-your-node) section.
6. Restart opera. The node resumes from the snapshot's tip (epoch 5810 / block 1,461,789 at snapshot time) and syncs forward. Expect `New DAG summary age=<few seconds>` within 1-2 minutes of restart.

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
4. Confirm in the coordination channel that block production resumed and `opera version` reports `2.0.28-elemont`.

**Missed the window?** Patch6 sealed on testnet at block 1,460,329 in epoch 5801 on 2026-05-16. If your node was not already running v2.0.21 before that seal, a later binary swap will not replay the `SfcV2Patch6` edge and will not apply the automatic backfill. Stop the node, preserve `keystore/` and `go-opera/nodekey`, and restore from the latest post-seal chaindata snapshot in [Troubleshooting](#warn-incoming-event-rejected-err-wrong-event-epoch-hash) before rejoining.

After Shanghai, Cancun, or Prague seals, the same rule applies to v2.0.28: nodes that missed the activation window should restore from the newest post-seal snapshot instead of replaying the edge at a different block.

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
| **PaybackV2**              | Binary-level swap of `Economy.QuotaCacheAddress` from the original `TransparentUpgradeableProxy`-based Quota proxy to a freshly-deployed non-proxy `QuotaContractV2` whose owner is a recoverable EOA. Activates at the first epoch seal after the v2.0.18+ binary boots. Designed to escape the lost-ProxyAdmin-key state on the original proxy without losing access to existing depositor stake (V1 `unstake`/`withdrawStake` remain permissionless after activation; only the protocol-side backing balance is orphaned). |
| **PaybackV2Patch**         | One-shot testnet repair edge that rebinds an already-active PaybackV2 chain from the superseded V2 address to corrected `QuotaContractV2` `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4`.                                                                                                                                                                                                                                                                                                                                       |
| **SfcV2Patch6**            | One-shot testnet SFC bytecode re-flash to Cycle-162, adding orphan-delegation registration/backfill and an undelegate-to-zero fix for legacy orphaned stake pairs. v2.0.21 also performs the known live testnet delegation backfill in node state at the seal.                                                                                                                                                                                                                                                                |
| **Mainnet SfcV2 backfill** | Future mainnet `SfcV2` activation installs the latest Cycle-162 bytecode directly and now has a mainnet-only node-state backfill hook for the 82 live mainnet delegation rows audited on 2026-05-17. The list must be refreshed immediately before a mainnet activation release so newly-created missing rows are not missed.                                                                                                                                                                                                 |

Testnet has Shanghai, Cancun, Prague, the earlier SFC re-flashes (`SfcV2Patch2` / `SfcV2Patch3` / `SfcV2Patch4` / `SfcV2Patch5`), the `ElemontPubkeyValidation` sealer guard, PaybackV2, PaybackV2Patch, and the `SfcV2Patch6` edge. Mainnet has Shanghai/Cancun/Prague disabled and no `SfcV2*` patch flags active yet — when it activates `SfcV2`, the latest Cycle-162 bytecode is installed directly without separate `Patch*` events, and the mainnet-only activation hook backfills the audited missing delegation rows. Mainnet `PaybackV2` is staged for a separate release after testnet bake-in completes.

Recent execution-layer seal points on testnet:

| Flag       | Introduced | Sealed (testnet)            | Notes                                        |
| ---------- | ---------- | --------------------------- | -------------------------------------------- |
| `Shanghai` | v2.0.22    | 2026-05-17, block 1,461,622 | EIP-3651, EIP-3855, and EIP-3860 active     |
| `Cancun`   | v2.0.24    | 2026-05-18, block 1,461,786 | EIP-1153, EIP-5656, and EIP-6780 active     |
| `Prague`   | v2.0.28    | Staged 2026-05-18; pending next seal | EIP-7702 set-code transactions              |

### Release overview

| Version             | Type                                                                    | What changed                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
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
**Activation timing.** Consensus flags and seal-bound rebinding (`SfcV2`, `Podgorica`, `Elemont`, `Shanghai`, `Cancun`, `Prague`, `SfcV2Patch2/3/4/5/6`, `ElemontPubkeyValidation`, `PaybackV2`, `PaybackV2Patch`, and v2.0.2 rules) activate at the **next epoch seal** after the binary is first installed or the pending `DirtyRules` edge is staged (up to `MaxEpochDuration = 4h`). On skipped-binary boots, v2.0.28 deliberately stages Shanghai before Cancun and Cancun before Prague; each follow-up flag is staged by the same continuous node after its predecessor seals, without a restart. All other changes — RPC caps, RPC additions, peer-quota resize, drift-cap removal, `eth_feeHistory.gasUsedRatio` fix, lachesis-base internals — are **immediate on restart**, no epoch-seal wait.
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

_Last updated: 2026-05-19 · latest guide target `v2.0.28-elemont` · Prague/EIP-7702 set-code transactions · corrected PaybackV2 address `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4` · SFC Cycle-162 `version() = 3.0.5` · go-vinu `v1.20.19-quota` · lachesis-base `v0.1.6-elemont`_
