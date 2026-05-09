# Chain Upgrade Guide (v2-elemont)

{% hint style="info" %}
**Latest node release:** v2.0.17-elemont (tagged and deployed to the testnet trace RPC + 4 validators on 2026-05-10). This release adds Payback receiver accounting for `QuotaContract.stakeFor(address)` and aligns fresh testnet defaults with the live Quota proxy address. The v2.0.14 release notes below still describe the consensus state of the chain (`SfcV2Patch5` + `ElemontPubkeyValidation` activated at the v2.0.14 epoch seal).
{% endhint %}

{% hint style="info" %}
**Payback receiver rollout status:** The v2.0.17 node binary is deployed on testnet. The current testnet Quota proxy is `0x824B93dE7221cf8a35FBd29d5202f6eFa3A29C5D`; its implementation still needs to be upgraded and verified before the frontend receiver selector is deployed. After that proxy upgrade, `QuotaContract.stakeFor(address)` lets a funding wallet supply VC while the receiver address owns the Quota stake and receives refunds for transactions it signs.

`v2.0.16-elemont` was tagged but superseded before deployment; use `v2.0.17-elemont` for Payback receiver rollout because it also aligns fresh testnet defaults with the live Quota proxy address.

The guarded contract-side commands live in `vinu-quotacontract`: `yarn preflight:testnet:quota` checks the signer and live proxy state without deploying, `yarn upgrade:testnet:quota` deploys and upgrades through ProxyAdmin, and `QUOTA_IMPLEMENTATION_ADDRESS=<address> yarn verify:testnet:quota` verifies the new implementation on VinuExplorer. The same path is available as the manual GitHub Actions workflow `Quota Testnet Upgrade`; it requires the ProxyAdmin owner key in the repository secret `PRIVATE_TEST`, an explicit proxy-address confirmation when dispatching, and supports `preflight_only=true` before the mutating upgrade run.
{% endhint %}

{% hint style="warning" %}
**Operators stuck on v2.0.14 with `peerCount=0`:** v2.0.14's default-bootnodes table was keyed only on the legacy `main`/`test` aliases, so any node booting without `--bootnodes` and without a populated `static-/trusted-nodes.json` got an empty bootstrap list and never discovered peers. **Upgrade to v2.0.17-elemont** for the current durable fix, or pass the four testnet bootnodes explicitly as a transitional workaround:

```
--bootnodes enode://e2a95c1b8d85b018b8e88133bec342801b42e19b59a52e030462d04a5549f02fc57215b4ca97771ec6b3a0d30a78603fdccd2b5091c44f6ac439d6c8be8bc539@44.239.129.39:3000,enode://7a45d086b9c82bd3677a76d36e003b9490066d56b612f33d05cb4d242212acd4e5cab4abbcb15a0df9aa499e41b4b4e868d82ba1c509c1990c9217dfe4607775@44.239.129.39:3001,enode://d8e37eeba79b2c52dcba6e396ff907f27a6a8f7db34528cb8636bc3271291657a01c5649bff53429cea8a23b03fac13a178813c34c6d17d14f7b810a988393b5@44.239.129.39:3002,enode://3f15b5ac22dea3e37a90cd9378cf0cd4ed9ea122851846c8108fcc7d2c7e709ea4a089cf3da93c0d3d3053250417cf0ea9ad9eff0aa77ff07d76b6cf267a2937@44.239.129.39:3003
```
{% endhint %}

{% hint style="info" %}
**v2.0.17 binary (current testnet node target):** Built byte-identical on both AWS build hosts at sha256 `b96651d8f0403bf57a3f6b124669f574b1b10082ddc6f8dacb42fc1b96811106` (HEAD `bbc34e6`). Build via `git fetch --tags origin && git checkout v2.0.17-elemont && make opera`. Drop-in binary swap from v2.0.15 — no chaindata work required, no flag activation, no migration. Roll-forward is the same `systemctl restart vinu-validator-v{1..4}.service` (or equivalent) staggered with 20 s spacing.
{% endhint %}

{% hint style="info" %}
**TL;DR**

* **Target tag:** `v2.0.14-elemont` (cut 2026-05-03; contains the real 45,496-byte Cycle-161 SFC runtime bytecode compiled from `VinuChain/vinuchain-lists@9b9c280` with solc `0.5.17+commit.d19bba13 --optimize --optimize-runs=10000 --evm-version=istanbul`. Hex-string sha256 `d3a6c816fb6b56464b463d074a08d27b82d61742d2bccdc784ff9844af1f4a2b`; raw-bytes sha256 `8276a8f3854e4c5a0aa6e23f511ae9028d0074ecec2f4c1368713ab877e640e1`.)
* **Binary version string:** `2.0.14-elemont`
* **Build requirements:** Go 1.25+, C compiler, \~50 GB free disk
* **Fresh testnet genesis:** [vitainu-genesis-testnet-20260419.g](https://vinu-blockchain-genesis.s3.amazonaws.com/vitainu-genesis-testnet-20260419.g) (SHA256 `a541d761e5db846b84c5bf0eef9aa09f45246254a2876ab0f8caf0b47b32e0d9`, ~450 MB, history baked through epoch ~5637 / block ~1.42M — recognized as trusted preset under v2.0.9+, no `--genesis.allowExperimental` required). **Fresh-install operators should restore from the latest published post-seal chaindata snapshot** (current artefact: [testnet-chaindata-v2.0.15-20260506T141559Z-clean.tar.gz](https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.15-20260506T141559Z-clean.tar.gz), SHA256 `f4bd1abe02b216695c100a3271ea245e4a8b96b8dcb94dc3201ab9be91376870`, 1.18 GiB, taken from the testnet trace node after `SfcV2Patch5` + `ElemontPubkeyValidation` sealed; tip block 1,446,860 / epoch 5741). The tarball is flat — top-level is `chaindata/`, `go-opera/`, and `SNAPSHOT_INFO.txt` with no `datadir/` prefix, so `cd <your_datadir> && tar -xzf <snapshot>.tar.gz` drops the directories directly where opera expects them. Fresh replay from genesis is not supported under v2.0.15 because all five `SfcV2Patch*` flags plus `ElemontPubkeyValidation` would fire at the first replay seal and produce a `wrong event epoch hash` divergence against the live chain.
* **New on testnet (v2.0.14):** two coordinated upgrade flags activating at the same epoch seal —
  * **`SfcV2Patch5`** — one-shot re-flash of the SFC bytecode at `0xFC00FACE...` with the Cycle-161 build. The Cycle-161 delta adds canonical-pubkey validation (`length == 66 && pubkey[0] == 0xc0`) at three on-chain ingress points: `SFC.createValidator`, `SFC._rawCreateValidator` (which also covers `setGenesisValidator`), and `NodeDriverAuth.updateValidatorPubkey`. Existing stored pubkeys (notably testnet validator 16's malformed 65-byte 0x04-prefixed pubkey) are not modified by the bytecode swap; only **new** admissions are subject to the check.
  * **`ElemontPubkeyValidation`** — off-chain sealer guard that skips validators whose stored pubkey fails `validatorpk.Validate()` at epoch seal. Ejects testnet validator 16 from the active set with the log line `Skipping validator with malformed pubkey at epoch seal id=16` at the first post-activation seal — that is **expected behaviour**, not a divergence.
* **Also in v2.0.14:** `eth_feeHistory` returns the real `block.GasUsed / block.GasLimit` ratio instead of a hardcoded `0.99`, so wallets compute correct fee suggestions. `go vet` warnings cleared on `utils/fast/buffer.go` (`WriteByte`/`ReadByte` renamed to `WriteByteFast`/`ReadByteFast`).
{% endhint %}

{% hint style="info" %}
**Version string vs git tag.** The release is cut from git tag `v2.0.14-elemont`, but the binary reports `2.0.14-elemont`. Both refer to the same release; the leading `v` only appears on the git tag.
{% endhint %}

## Network Details

| Network | Chain ID   | RPC                              | Status          |
| ------- | ---------- | -------------------------------- | --------------- |
| Mainnet | 207 (0xcf) | `https://vinuchain-rpc.com`      | Upgrade pending |
| Testnet | 206 (0xce) | `https://vinufoundation-rpc.com` | Upgrade first   |

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

{% hint style="info" %}
**Fresh install?** This guide covers binary swaps on existing validator nodes. If you're bootstrapping a brand-new testnet node, replay from genesis is **not supported under v2.0.14** — follow the snapshot-restore procedure in [Troubleshooting → Wrong event epoch hash](#warn-incoming-event-rejected-err-wrong-event-epoch-hash) instead. Mainnet operators bootstrapping fresh can replay from the standard mainnet genesis as no `SfcV2*` flag has activated there yet.
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
git checkout v2.0.14-elemont
make opera
# Binary is at $HOME/vinuchain-upgrade/build/opera
```

{% endcode %}

Substitute `/opt/vinuchain-upgrade` (or any other path) if `$HOME` is not the right partition for your setup — every later command in this guide that references `$HOME/vinuchain-upgrade` should be adjusted to match.

{% hint style="info" %}
**`go.mod` pins unchanged across the elemont series.** `v2.0.14-elemont` uses the same go-vinu `v1.20.14-quota` and lachesis-base `v0.1.6-elemont` pins as earlier elemont releases. `make opera` fetches dependencies on first build.
{% endhint %}
{% endstep %}

{% step %}

#### Verify the new binary

The newly-built binary is at `vinuchain-upgrade/build/opera`. Move into that directory so the rest of the steps can use a relative `./opera` path:

```bash
cd $HOME/vinuchain-upgrade/build
./opera version
# Expected: Version: 2.0.14-elemont
```

{% hint style="info" %}
`opera version` prints `2.0.14-elemont` — this matches the git tag `v2.0.14-elemont`. See the note at the top of this page.
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

**Startup banner.** Every v2.x build prints the VinuChain banner. This is the first visual confirmation that you are running v2.0.14-elemont and not the previous binary:

```text
 ██╗   ██╗██╗███╗   ██╗██╗   ██╗ ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
 ██║   ██║██║████╗  ██║██║   ██║██╔════╝██║  ██║██╔══██╗██║████╗  ██║
 ██║   ██║██║██╔██╗ ██║██║   ██║██║     ███████║███████║██║██╔██╗ ██║
 ╚██╗ ██╔╝██║██║╚██╗██║██║   ██║██║     ██╔══██║██╔══██║██║██║╚██╗██║
  ╚████╔╝ ██║██║ ╚████║╚██████╔╝╚██████╗██║  ██║██║  ██║██║██║ ╚████║
   ╚═══╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

                        v2.0  -  ELEMONT

  Version: 2.0.14-elemont
```

**Staging logs (testnet only, first-time `SfcV2Patch5` + `ElemontPubkeyValidation` install).** On the first v2.0.14 boot of a node that hasn't yet sealed both flags, you will see TWO staging lines (one per flag):

```text
INFO Staged SfcV2Patch5 upgrade from binary rules; will activate at next epoch seal
INFO Staged ElemontPubkeyValidation upgrade from binary rules; will activate at next epoch seal
```

These confirm both flags are pending. If you do not see either line, you are likely running a pre-v2.0.14 binary (`opera version` check) or both flags have already sealed on this datadir from a prior v2.0.14 boot. Mainnet nodes never show these lines — both flags are testnet-only.

**Seal-time activation (testnet only).** At the next epoch seal after the staging logs appear, you will see the bytecode re-flash and the validator-set ejection:

```text
INFO Re-applying SFC V2 bytecode upgrade (patch 5)              block=<N>
WARN Skipping validator with malformed pubkey at epoch seal     id=16  err="malformed pubkey"
```

The first line is the one-time bytecode installation. After it fires, the SFC contract at `0xFC00FACE00000000000000000000000000000000` contains the Cycle-161 bytecode and can be verified on the testnet explorer using the current SFC source at [`vinuchain-lists/contracts/vinuchain/SFC.sol`](https://github.com/VinuChain/vinuchain-lists/blob/main/contracts/vinuchain/SFC.sol) (ABI alongside at `SFC_abi.json`).

The second line is the **expected** ejection of testnet validator 16 (admitted at epoch 5682 with a malformed 65-byte 0x04-prefixed pubkey lacking the canonical `0xc0` Secp256k1 type-byte). The validator-set hash will change at this block; do **not** investigate it as a divergence — the line is the on-the-wire signal that `ElemontPubkeyValidation` activated correctly.

#### Verification checklist

| Check                                                     | Expected                                                                             |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Startup banner                                            | `VINUCHAIN v2.0 - ELEMONT` ASCII art printed to stderr                               |
| `opera version`                                           | `Version: 2.0.14-elemont`                                                            |
| Block production                                          | Resumes within seconds of startup; block numbers advance                             |
| Peer count                                                | Returns to prior steady-state within minutes                                         |
| Staging logs (testnet, first v2.0.14 boot)                | 1× `Staged SfcV2Patch5 …` AND 1× `Staged ElemontPubkeyValidation …`                  |
| Staging log — all other cases (mainnet or sealed testnet) | None                                                                                 |
| Seal-time logs (testnet, first epoch seal after staging)  | 1× `Re-applying SFC V2 bytecode upgrade (patch 5) block=<N>` AND 1× `Skipping validator with malformed pubkey at epoch seal id=16` |
| SFC verification on testnet explorer (after seal)         | `vinuchain-lists/contracts/vinuchain/SFC.sol` with solc 0.5.17 verifies successfully |
| Block hash vs peer                                        | Identical                                                                            |
| `rpc_modules` returns                                     | Includes `"vc":"1.0"` (`vc_getPaybackBalance`)                                       |
| `vc_getPaybackBalance` call                               | Returns hex-encoded wei (or `0x0` for ineligible addresses / Podgorica inactive)     |

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

***

## Setting Up a New Validator

{% hint style="info" %}
New validator setup is **not** covered on this page. If you are installing a fresh validator for the first time rather than upgrading an existing one, follow the dedicated guide: [Become a Validator](../nodes-and-validators/become-a-validator.md).

That guide uses the correct `opera validator new` command for generating a validator key. A plain `opera account new` creates a regular externally-owned account, not a validator key.
{% endhint %}

***

## Rollback

Because v2.0.14-elemont is a patch release and not a hard fork, rollback is straightforward:

1. Stop the node (clean shutdown).
2. Replace `opera` with a prior elemont release binary (e.g., v2.0.10-elemont, v2.0.9-elemont, or earlier).
3. Start the node.

No datadir changes are needed. Consensus state, receipts, and block hashes are identical across every adjacent pair of elemont releases listed below.

{% hint style="info" %}
**Per-version rollback deltas.** Each bullet describes the only functional difference between the two versions.

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

| Sealed patch  | Introduced in | Testnet seal                 | Installed bytecode                                |
| ------------- | ------------- | ---------------------------- | ------------------------------------------------- |
| `SfcV2Patch2` | v2.0.5        | Mid-v2.0.5 boot              | Cycle-158 SFC (45,240 bytes)                      |
| `SfcV2Patch3` | v2.0.10       | 2026-04-19 · block 1,424,440 | Cycle-159 SFC — inline reentrancy guard fix       |
| `SfcV2Patch4` | v2.0.11       | 2026-04-23 · block 1,430,436 | Cycle-160 SFC — `_lockStake` / `relockStake` fix  |
| `SfcV2Patch5` | v2.0.14       | 2026-05-03 · pending seal    | Cycle-161 SFC — canonical-pubkey validation       |

This is expected behavior — the bytecode update is the intended outcome of each upgrade and cannot be undone by swapping binaries. Reverting installed bytecode would require shipping another epoch-sealed upgrade flag, which is a forward-moving change rather than a rollback.

Mainnet is currently unaffected — no `SfcV2*` flag has sealed on mainnet, so mainnet operators can freely roll back to any elemont binary.
{% endhint %}

***

## Troubleshooting

### Node won't start after upgrade

1. Check logs: `journalctl -u opera -f` (systemd) or your terminal / Docker output.
2. Verify the binary: `opera version` must print `2.0.14-elemont`.
3. If the database is reported as corrupted, restore from the chaindata snapshot below.

### Node starts but doesn't produce events

1. Confirm `--validator.password` points to a readable file via absolute path.
2. Confirm `--validator.id` and `--validator.pubkey` match your on-chain registration.
3. Confirm peers are connecting — an isolated node cannot produce events.

### `WARN Incoming event rejected ... err="wrong event epoch hash"`

Your locally-computed epoch state hash does not match the network's. The check rejects any event whose `PrevEpochHash` differs from the local store's `EpochState.Hash()`. There is no protocol-level recovery; chaindata must be replaced with a snapshot.

{% hint style="danger" %}
**Do not resync from genesis on testnet.** A fresh replay stages every not-yet-sealed `SfcV2Patch*` flag plus `ElemontPubkeyValidation` and fires them at the first replay seal — at a different block from the live chain's historical activations — so the epoch state hash diverges immediately. Use the latest published post-seal snapshot below instead. The prior v2.0.10 and v2.0.11 snapshots are stale under v2.0.15 rules and **must not be used**: they pre-date `SfcV2Patch5` + `ElemontPubkeyValidation` activation and will re-fire those flags at first restore seal, reproducing the same `wrong event epoch hash` divergence. The current canonical snapshot is `testnet-chaindata-v2.0.15-20260506T141559Z-clean.tar.gz` (post-Patch5, post-ElemontPubkeyValidation).
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
   curl -LO https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.15-20260506T141559Z-clean.tar.gz
   # verify integrity
   curl -L https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.15-20260506T141559Z-clean.tar.gz.sha256 | sha256sum -c -
   tar -xzf testnet-chaindata-v2.0.15-20260506T141559Z-clean.tar.gz
   rm testnet-chaindata-v2.0.15-20260506T141559Z-clean.tar.gz
   ```

   **Sanity-check the extraction before restarting opera.** Every snapshot published from 2026-04-24 onwards (including this one) includes a `SNAPSHOT_INFO.txt` at the tarball root, so it lands in your datadir automatically on extraction. Read it before starting opera:

   ```bash
   cat <datadir>/SNAPSHOT_INFO.txt
   ```

   The file lists the network, snapshot timestamp, binary version, tip block, tip epoch, and the full set of sealed upgrade flags. The tip block listed there is the minimum block number your first `New block` log line should show after restart. If `cat` returns nothing, the tarball did not extract correctly — do not start opera; re-extract at the datadir root.

   Direct HTTPS URL (public, no AWS credentials required):

   ```text
   https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.15-20260506T141559Z-clean.tar.gz
   ```

   SHA256: `f4bd1abe02b216695c100a3271ea245e4a8b96b8dcb94dc3201ab9be91376870`. Size: 1.18 GiB compressed (1,265,663,855 bytes). Published 2026-05-06 from the canonical testnet trace node at block 1,446,860 / epoch 5741, taken **after** `SfcV2Patch5` + `ElemontPubkeyValidation` sealed so it is the correct bootstrap for v2.0.15 binaries. The tarball is flat (top-level is `chaindata/`, `go-opera/`, and `SNAPSHOT_INFO.txt` — no `datadir/` prefix to nest) and excludes `nodekey`, `keystore/`, `opera.ipc`, `static-nodes.json`, `trusted-nodes.json`, the archived `chaindata.bak.*/` from the pre-LevelDB-FSH migration, and any shell `history` file. New snapshots are published under `s3://vinu-blockchain-genesis/chaindata-snapshots/` — pick the most recent `-clean` snapshot for the shortest catch-up. The bucket is public-read; `aws s3 ls s3://vinu-blockchain-genesis/chaindata-snapshots/` works with any AWS credentials or via `curl https://vinu-blockchain-genesis.s3.amazonaws.com/?list-type=2&prefix=chaindata-snapshots/` with none.

5. Ensure `--nat extip:<your_public_ip>` is set and `<datadir>/go-opera/static-nodes.json` contains the canonical bootnode list from the [Start your node](#start-your-node) section.
6. Restart opera. The node resumes from the snapshot's tip (epoch 5741 / block 1,446,860 at snapshot time) and syncs forward. Expect `New DAG summary age=<few seconds>` within 1-2 minutes of restart.

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

The recommended rollout:

1. VinuChain team announces the patch window. Date: TBD.
2. Pre-stage the binary on every validator before the window (Upgrade Steps step 2).
3. During the window, each operator performs the binary swap.
4. Confirm in the coordination channel that block production resumed and `opera version` reports `2.0.14-elemont`.

**Missed the window?** No fork — upgrading later is a plain binary swap (rerun Upgrade Steps). On testnet, a node still on v2.0.13 or earlier cannot validate post-`SfcV2Patch5`-seal or post-`ElemontPubkeyValidation`-seal events (validator-set hash mismatches); if the node also fell behind tip, restore from the chaindata snapshot in [Troubleshooting](#warn-incoming-event-rejected-err-wrong-event-epoch-hash) before restarting on v2.0.14.

***

## Contact

If you encounter issues during the upgrade, reach out to the VinuChain team through the official channels.

***

## Changelog

### Network upgrades

The codebase uses three internal upgrade names. They activate at the same epoch seal when SfcV2 first fires, so consumers usually treat them as one event.

| Name        | What it covers                                                                                              |
| ----------- | ----------------------------------------------------------------------------------------------------------- |
| **SfcV2**   | Replaces the on-chain SFC contract bytecode at `0xFC00FACE...` and turns on the 30% base fee burn.          |
| **Podgorica** | Payback fee refund mechanism. Source of the optional `feeRefund` field on receipts and transactions.       |
| **Elemont** | Cheater fee zeroing at `SealEpoch` plus the broader v2.0+ release-series naming used in version strings.   |

Testnet has all three plus the trailing `SfcV2Patch2` / `SfcV2Patch3` / `SfcV2Patch4` / `SfcV2Patch5` bytecode re-flashes and the `ElemontPubkeyValidation` sealer guard sealed. Mainnet has none active yet — when it activates `SfcV2`, the latest Cycle-161 bytecode is installed directly without separate `Patch*` events.

### Release overview

| Version             | Type                                          | What changed                                                                                                        |
| ------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| v2.0.17-elemont | Payback/Quota receiver staking          | Deployed to testnet RPC + validators on 2026-05-10. The node PaybackCache recognizes `stakeFor(address)` as stake owned by the receiver, preserving same-epoch duration accounting for the refunding address. Quota proxy implementation upgrade and source verification are still pending. |
| **v2.0.14-elemont** | Testnet consensus flags (Patch5 + ElemontPubkeyValidation) | Cycle-161 SFC bytecode. Adds canonical-pubkey validation (`length == 66 && pubkey[0] == 0xc0`) at `createValidator`, `_rawCreateValidator`, and `NodeDriverAuth.updateValidatorPubkey`. Off-chain sealer guard ejects validators with malformed stored pubkeys (testnet validator 16) at the next epoch seal. Also: real `gasUsedRatio` in `eth_feeHistory`. |
| v2.0.13-elemont     | Same-day scaffolding (no live activation)     | Defines flags + ships the deadbeef-placeholder Cycle-161 bytecode; flipped to v2.0.14 same day with the real bytecode and activation. Don't deploy v2.0.13 standalone. |
| v2.0.12-elemont     | Diagnostic + tooling                          | Multi-`SfcV2Patch*` divergence warn at single seal; chaindata snapshot producer (`scripts/create-chaindata-snapshot.sh` with `SNAPSHOT_INFO.txt`). Non-consensus. |
| v2.0.11-elemont     | Testnet consensus flag (Patch4)               | Cycle-160 SFC bytecode. Fixes `_lockStake` / `relockStake`: invariant becomes `endTime >= ld.endTime`.              |
| v2.0.10-elemont     | Testnet consensus flag (Patch3) | Cycle-159 SFC bytecode. Fixes inline reentrancy guard (`_reentrancyGuardCounter < 2`); unblocks `delegate`, `undelegate`, `withdraw`, `claimRewards`, `restakeRewards`, `stashRewards`, `createValidator`. |
| v2.0.9-elemont      | Trusted-preset entry            | Recognizes `vitainu-genesis-testnet-20260419.g` — fresh installs no longer need `--genesis.allowExperimental`.       |
| v2.0.8-elemont      | Hotfix                          | Removes `validatePeerProgress` drift caps so long-offline validators can rejoin.                                     |
| v2.0.7-elemont      | Hotfix                          | Raises per-peer event-processing quota to 3,250 (matches `EventsBufferLimit.Num`); kills the warning storm during sync. |
| v2.0.6-elemont      | RPC addition                    | New `vc_getPaybackBalance` JSON-RPC method (rate-limited).                                                          |
| v2.0.5-elemont      | Testnet consensus flag (Patch2) | Cycle-158 SFC bytecode re-flash at `0xFC00FACE...`.                                                                  |
| v2.0.4-elemont      | Internal                        | lachesis-base bumped to `v0.1.6-elemont`: vecengine cap, dagprocessor drain, kvdb flushable race fix, gossip deadlock fix. |
| v2.0.3-elemont      | RPC defensive caps              | go-vinu fork `v1.20.14-quota`: batch-size cap (100), in-flight cap (50, configurable), state-override caps.          |
| v2.0.2-elemont      | Consensus rules                 | `feeRefund` receipt field, 30% base fee burn, cheater fee zeroing, payback fee refunds.                              |

Mainnet has not yet activated any `SfcV2*` flag — when it does, the latest bytecode (Cycle-161) installs directly; the testnet patch flags do not fire on mainnet.

{% hint style="info" %}
**Activation timing.** Consensus flags (`SfcV2Patch2/3/4/5`, `ElemontPubkeyValidation`, and v2.0.2 rules) activate at the **next epoch seal** after the binary is first installed (up to `MaxEpochDuration = 4h`). All other changes — RPC caps, RPC additions, peer-quota resize, drift-cap removal, `eth_feeHistory.gasUsedRatio` fix, lachesis-base internals — are **immediate on restart**, no epoch-seal wait.
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

When `SfcV2` activates, the on-chain SFC contract at `0xfc00face00000000000000000000000000000000` is rewritten with V2 bytecode. Function selectors and ABI are unchanged — dApps and on-chain contracts calling SFC continue to work without modification. All existing delegations, stakes, and validator registrations remain valid.

Subsequent testnet patches re-flash the same address with newer bytecode at additional epoch seals:

| Patch         | Introduced | Sealed (testnet)              | Bytecode                                       |
| ------------- | ---------- | ----------------------------- | ---------------------------------------------- |
| `SfcV2Patch2` | v2.0.5     | Mid-v2.0.5 boot               | Cycle-158 (45,240 bytes)                       |
| `SfcV2Patch3` | v2.0.10    | 2026-04-19, block 1,424,440   | Cycle-159 — inline reentrancy guard fix         |
| `SfcV2Patch4` | v2.0.11    | 2026-04-23, block 1,430,436   | Cycle-160 — `_lockStake` / `relockStake` fix    |

ABI is byte-identical across Cycle-158/159/160 (123 functions + 39 events; no selector changes). A binary startup guard (`sfc.EnforcePatch4StartupCheck`) refuses to start a v2.0.11 build with an invalid Patch4 asset.

**Blockscout verification.** Bytecode swaps via the evmwriter precompile bypass Blockscout's normal contract-discovery path. After each seal, re-verify with: `DELETE` the stale `smart_contracts` row, `UPDATE addresses.contract_code` with fresh `eth_getCode`, then `POST /api/v2/smart-contracts/.../verification/via/flattened-code`. Solc settings: `0.5.17+commit.d19bba13`, `--optimize --optimize-runs=10000 --evm-version=istanbul`. Source: [`vinuchain-lists/contracts/vinuchain/SFC.sol`](https://github.com/VinuChain/vinuchain-lists/blob/main/contracts/vinuchain/SFC.sol).

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

Stakers meeting the minimum stake threshold automatically receive gas refunds. **No new VC is created** — refunds redistribute fees from validator earnings to eligible stakers.

1. User submits a transaction; full `gasUsed × gasPrice` is debited as before.
2. Full fee is credited to the validator pre-refund.
3. After epoch seal, the payback system queries the sender's stake. If eligible, a refund is returned from the validator's earned fees.
4. Validator earnings decrease by the refund; sender balance increases by it.

In the unreleased Payback receiver flow, a funding wallet may call `QuotaContract.stakeFor(receiver)` instead of `stake()`. The receiver owns that Quota stake, so refunds still follow the transaction sender: the receiver gets refunds for transactions the receiver signs, while the funding wallet does not gain refund eligibility from that delegated stake.

The `feeRefund` receipt field reports the refund amount. dApps showing "gas spent" should subtract `feeRefund` from `gasUsed × effectiveGasPrice`.

#### `vc_getPaybackBalance`

| Field         | Value                                                                                              |
| ------------- | -------------------------------------------------------------------------------------------------- |
| Namespace     | `vc` (not `eth`)                                                                                   |
| Method        | `vc_getPaybackBalance`                                                                             |
| Params        | `[address]` (20-byte hex). Optional second param: block tag (default `"latest"`).                  |
| Returns       | Hex-encoded wei. Returns `0x0` for the zero address, when Podgorica is inactive, or sub-minimum stake. |
| Rate limit    | 8 in-flight, 2 s acquire timeout. Rejection error `-32005` `payback query rate-limited`.           |

```bash
curl -s -X POST http://localhost:18545/ \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"vc_getPaybackBalance","params":["0xABCDEF0123456789ABCDEF0123456789ABCDEF01"],"id":1}'
```

The `vc` namespace is intentionally separate from `eth` — the accessor is RPC-safe (never reads/writes `PaybackCache.blkCtx`, never mutates `StakesMap`), so concurrent RPC traffic cannot corrupt block-processing state.

### JSON-RPC defensive caps

| Cap                                | RPC method(s)                                              | Limit                                                          | Error on exceed                       |
| ---------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------- |
| Batch size                         | Any batched call                                           | 100 messages per batch                                         | `invalid request: batch too large`    |
| In-flight concurrency              | All HTTP & WS RPC                                          | 50 concurrent (`--rpc.maxconcurrent N` to tune; `0` to disable) | HTTP 503                              |
| `StateOverride.code` size          | `eth_call`, `eth_estimateGas`, `debug_traceCall`           | 24,576 bytes per account                                       | `code size exceeds MaxCodeSize`       |
| `StateOverride.stateDiff` entries  | same as above                                              | 1,000 entries per account                                      | `stateDiff size exceeds 1000 entries` |
| `feeRefund` P2P ingress            | Internal (peer RLP decoding)                               | 32 bytes / 256 bits                                            | Peer drops the receipt                |
| Graceful shutdown                  | Any RPC method during shutdown                             | Handler returns proper JSON-RPC error                          | `handler is stopping`                 |

Indexers batching block-range queries should paginate at ≤100 messages. Heavy analytics workloads can raise concurrency with `--rpc.maxconcurrent N` or distribute across endpoints.

### Pruning

Operator-facing controls for managing chaindata size on long-lived nodes.

| Surface                              | Purpose                                                                                       |
| ------------------------------------ | --------------------------------------------------------------------------------------------- |
| `--prune-keep-epochs <N>`            | Retain the last N sealed epochs of state; prune older. Negative values are rejected with a clear error (previously wrapped to large unsigned values and pruned everything). |
| `--prune-keep-blocks <N>`            | Same semantics, applied to receipt/log retention.                                             |
| `opera snapshot prune-receipts`      | One-shot subcommand for fine-grained receipt retention control outside the live retention flags. |

**Crash-safe.** If a prune operation is interrupted (node crash, OOM kill), the next startup automatically resumes the interrupted prune — no manual intervention. The `Snapshots count=128` default produces enough snapshot density for prune to find recoverable boundaries on restart.

### Other reliability fixes

- **Peer-progress drift caps removed (v2.0.8).** `validatePeerProgress` no longer rejects peers more than 1,000 epochs / 5,000 blocks ahead. The deeper acceptance gate (`lightCheck`, `epochcheck.ErrNotRelevant`) already prevents abuse.
- **Per-peer event quota raised (v2.0.7).** `peerEventQuota` and `peerStreamQuota` raised from 200/100 to 3,250 (matches `EventsBufferLimit.Num`). DoS guarantee preserved by `Config.Validate()` — a single peer is bounded to ≤50% of capacity.
- **Tracing.** `trace_filter` with `Count==0` caps at 10,000 entries (was unbounded). Span-leak fix on tracing on/off. `traceBlock` bounds-checks malformed receipts.
- **`eth_feeHistory`** copies the tips slice per entry (was sharing backing array — mutations cross-contaminated).
- **Gas accounting.** Block-vote gas calc uses overflow-safe addition. Gas oracle guards against `MaxAllocPeriod=0`. `MinGasPrice=0` is rejected.
- **EVM.** `eth_call` enforces `MaxCodeSize` even when code comes from `stateOverride`.

***

_Last updated: 2026-05-10 · latest released VinuChain tag `v2.0.17-elemont` · Quota proxy upgrade pending · go-vinu `v1.20.14-quota` · lachesis-base `v0.1.6-elemont`_
