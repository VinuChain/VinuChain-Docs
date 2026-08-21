<!-- markdownlint-disable MD013 -->

# Mainnet Upgrade Guide (ELEMONT)

{% hint style="danger" %}
**Scheduled consensus upgrade — Saturday 29 August 2026, 10:00 UTC.**

Every VinuChain **mainnet** validator and RPC/API node operator must swap to `v2.0.47-elemont` in this window. This is a **consensus** upgrade: a node still running the old binary when the activation epoch seals will stop following the chain and log `wrong event epoch hash`. It cannot be caught up by waiting — it has to be upgraded and, if it already diverged, restored from a post-activation snapshot.

If you run a mainnet validator, read [Before upgrade day](#before-upgrade-day) now, not on the 29th. Two of the pre-flight items (transaction indexing and the Go toolchain) can take **more than a day** to remedy.
{% endhint %}

## What is happening

Mainnet is being brought up to the **ELEMONT** feature set that VinuChain testnet has been running since early 2026. In a single coordinated binary swap, mainnet moves from `v2.0.0-rc.1` to `v2.0.47-elemont` and activates the **entire** testnet feature set: the modern EVM (Shanghai, Cancun, Prague/EIP-7702), the **V2 staking contract (SfcV2)**, the Elemont consensus correctness fixes, canonical validator-pubkey validation, the **BLS12-381** and **latest-EVM** precompiles, and **PaybackV2** (a new fee-refund contract).

| | Value |
| --- | --- |
| **Network** | VinuChain Mainnet |
| **Chain ID** | `207` (`0xcf`) |
| **Upgrade window opens** | **2026-08-29 10:00 UTC** |
| **Target release** | [`v2.0.47-elemont`](https://github.com/VinuChain/VinuChain/releases/tag/v2.0.47-elemont) — the mainnet full-parity release. **Published.** Prebuilt linux/amd64 binary attached to the release, sha256 `2525435e918e3690a6e197b359df5a78b628a6e6ef8554022cb19434addf3ec6`. |
| **Upgrading from** | `v2.0.0-rc.1` (the binary mainnet has run to date) |
| **Type** | **Consensus.** Non-upgraded nodes diverge at the activation seal. |
| **Activation** | At the **first epoch seal** after the validator set is running the new binary — not at restart. See [When activation actually happens](#when-activation-actually-happens). |
| **Public RPC** | `https://rpc.vinuchain.org` |

{% hint style="warning" %}
**This page describes a future event.** Until the activation seals, mainnet still reports the pre-ELEMONT rule set, and pages describing ELEMONT features on mainnet describe the *post-upgrade* state. You can always check what mainnet is running right now with the [`vc_getRules` probe below](#confirm-the-current-mainnet-state-yourself).
{% endhint %}

---

## Why every validator has to act

VinuChain's consensus needs **more than 2/3 of active stake** to be emitting in order to
advance and seal an epoch — and an epoch seal is exactly what activates this upgrade.

That has a consequence worth being blunt about: this is not a case where slow operators simply
fall behind while the rest of the network moves on. If the validators running the new binary
add up to **less than** 2/3 of active stake, **nothing seals** — the upgrade does not activate
and the chain stops producing blocks until enough of the set is on the new binary.

As of 2026-08-19, mainnet has **16 active validators** securing roughly **178 million VC**, and
the stake is concentrated: a single validator currently holds **more than a third** of it. So
the upgrade depends on specific operators participating in the window, not on a majority by
headcount.

If you operate a mainnet validator, please confirm to the team **before 29 August** that you
will be upgrading in the window. If you cannot make the window, say so in advance — that is far
better than being discovered as missing on the day.

---

## Confirm the current mainnet state yourself

Do not take any page's word for what mainnet runs — including this one. Ask the chain:

```bash
curl -s -X POST https://rpc.vinuchain.org \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getRules","params":["latest"],"id":1}' \
  | python3 -m json.tool
```

**Before the upgrade** the `Upgrades` object contains exactly four flags — `Berlin`, `London`, `Llr`, `Podgorica` — and the SFC contract is still V1:

```bash
# SFC contract version: "304" = V1, "305" = V2
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"0xFC00FACE00000000000000000000000000000000","data":"0x54fd4d50"},"latest"],"id":1}'
# Pre-upgrade  -> 0x3330340...  ("304")
# Post-upgrade -> 0x3330350...  ("305")
```

`version()` flipping from `"304"` to `"305"` is the single clearest signal that the upgrade activated.

---

## What activates

| Feature | What it means for mainnet |
| --- | --- |
| **SfcV2** | The staking contract at `0xFC00FACE…0000` is replaced with V2 bytecode (48,336 bytes, "Cycle-164"). Adds the **30% burn of the validator base-fee share**, self-service `reactivateValidator`, and the corrected reward-cursor accounting. `version()` returns `"305"`. |
| **Shanghai** | `PUSH0`, warm coinbase, Shanghai transaction rules. |
| **Cancun** | Selected (non-blob) Cancun: transient storage (`TLOAD`/`TSTORE`), `MCOPY`, EIP-6780 `SELFDESTRUCT` semantics. **Blob transactions (EIP-4844) and `BLOBBASEFEE` are not enabled.** |
| **Prague** | **EIP-7702 set-code transactions** (type `0x04`). |
| **Elemont** | Consensus correctness fixes: merged no-cheaters view, full ABI decode of epoch advances, cheater-fee zeroing, deterministic vector-clock tie-breaking, stable median-time sort, empty-pubkey validator skip at epoch seal. |
| **ElemontPubkeyValidation** | Validator pubkeys must be the canonical 66-byte `0xc0`-prefixed Secp256k1 form at every on-chain ingress (`createValidator`, `_rawCreateValidator`, `updateValidatorPubkey`). Malformed keys are rejected from the activation seal onward. |
| **VinuBLS12381** | The EIP-2537 BLS12-381 precompile family at `0x0b`–`0x11`. |
| **VinuLatestEVM** | `P256VERIFY` at `0x0100`, `CLZ`, MODEXP bounds/repricing, and the **EIP-7825 per-transaction gas cap**. The gas cap is a live-traffic behaviour change — see [Breaking changes](#breaking-changes-to-check-before-the-29th). |
| **PaybackV2** | Moves the Payback / fee-refund system off the original Quota proxy `0x1c4269fb…0acda6` onto the newly deployed non-proxy `QuotaContractV2` at `0x5D989A2d65d049e2198D91d8ddc31C918f2544AB`. `Economy.QuotaCacheAddress` **changes** at this activation. **Fee-refund stakers must migrate** — see [If you stake in the Payback contract](#if-you-stake-in-the-payback-fee-refund-contract). |

`Berlin`, `London` (EIP-1559 base fee), `Llr` and `Podgorica` (the Payback / fee-refund system) are already active on mainnet and are unaffected.

The node binary also brings the branded `vc_*` JSON-RPC surface, `vc_getPaybackBalance`, and `eth_config` to mainnet — none of which exist on the current mainnet binary.

### What is *not* in this upgrade

This upgrade brings mainnet to full feature parity with testnet. The only flags testnet carries
that mainnet will not set are the **re-flash / repair** flags, which are not features:

| Not set | Why |
| --- | --- |
| **`SfcV2Patch1`–`SfcV2Patch9`** | These exist only to **re-flash** SFC bytecode on a chain that already activated SfcV2 with older bytecode. Testnet needed nine of them because it activated SfcV2 early and then corrected the bytecode repeatedly. Mainnet's *first* SfcV2 activation installs the latest corrected bytecode directly, so it reaches the same on-chain result without them — see the note below. |
| **`PaybackV2Patch`** | Same shape: it re-runs the PaybackV2 address rebinding for a chain that crossed that edge with a wrong address. Mainnet crosses it once, with the correct address, so there is nothing to repair. |

Mainnet therefore ends up with **identical on-chain state** to testnet — the same SFC bytecode
and the same style of Payback contract — reached in one step instead of nine.

{% hint style="info" %}
**Why mainnet needs no `SfcV2Patch*` flags.** Testnet activated SfcV2 early and then re-flashed the contract nine times as bytecode fixes landed. Mainnet activates for the first time, and the fresh-activation path installs the newest V2 bytecode in one step — the 48,336-byte Cycle-164 blob, which is byte-identical (sha256 `b25a749fe4fa4191bafc2f48d62f046176e1c9ba8fb914fa4a6f81651c4344af`) to what testnet arrived at after all nine patches. Mainnet therefore lands on fully-patched V2 immediately rather than replaying testnet's patch history.
{% endhint %}

---

## Before upgrade day

Work through this list **this week**. Items 1 and 2 have multi-day remediation paths.

{% stepper %}
{% step %}

### 1. Confirm transaction indexing is enabled — this can block boot

`v2.0.47-elemont` rebuilds its in-memory Payback cache at startup by replaying recently-sealed blocks from stored receipts, so a restarted node seals the same fee-refund values as its peers. That warm-up is **fail-closed**: if it cannot read a transaction-bearing block inside the replay window, the node **refuses to start** rather than risk silently diverging.

In practice: **a node that has been running with transaction indexing disabled will not boot on the new binary.**

Check your node's launch command for any flag that disables indexing (e.g. `--txlookuplimit` set in a way that prunes the window, or an explicitly disabled index):

```bash
# systemd
systemctl cat vinu-opera.service | grep -A20 ExecStart
# or, for a nohup/script launch
cat run_node.sh
ps -o args= -C opera
```

A more direct check than reading flags — ask your own node to look a transaction up **by hash**,
which is the path that needs the index. Pick a transaction from a block well behind head, then:

```bash
# 1. grab a tx hash from an older block on YOUR node
curl -s -X POST http://localhost:18545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0xDE0B6B",true],"id":1}' \
  | python3 -c 'import sys,json;t=json.load(sys.stdin)["result"]["transactions"];print(t[0]["hash"] if t else "no txs in that block, try another")'

# 2. look it up by hash — this is the indexed path
curl -s -X POST http://localhost:18545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_getTransactionByHash","params":["0xYOUR_TX_HASH"],"id":1}'
```

A non-null result means the index covers that height. A `null` for a transaction you know exists
means indexing is missing there. For reference, the public mainnet RPC resolves by-hash lookups
and receipts correctly as far back as 10 million blocks, so a healthy node should too.

If indexing is off, you must re-sync that node **with indexing on**, from a snapshot — plan for this now, not on the 29th.

{% endstep %}
{% step %}

### 2. Install Go 1.25.12 or newer

The current mainnet binary was built with **Go 1.19.13**. `v2.0.47-elemont` pins Go `1.25.12` in `go.mod` (for [GO-2026-5856](https://pkg.go.dev/vuln/GO-2026-5856), an Encrypted Client Hello privacy leak in `crypto/tls`) and will not build on an older toolchain.

```bash
go version   # must report go1.25.12 or newer
```

`make opera` fetches the pinned toolchain automatically if your Go is new enough to honour the `toolchain` directive; otherwise install Go 1.25.12+ from [go.dev/dl](https://go.dev/dl/).

{% endstep %}
{% step %}

### 3. Build and verify the binary ahead of the window

Build **before** upgrade day and keep the binary staged. Do not plan to compile during the swap window — a build failure at 10:00 UTC costs you the window.

**Option A — download the published binary** (linux/amd64):

```bash
mkdir -p $HOME/vinuchain-upgrade/build && cd $HOME/vinuchain-upgrade/build
curl -LO https://github.com/VinuChain/VinuChain/releases/download/v2.0.47-elemont/opera-v2.0.47-elemont-linux-amd64
sha256sum -c <<< "2525435e918e3690a6e197b359df5a78b628a6e6ef8554022cb19434addf3ec6  opera-v2.0.47-elemont-linux-amd64"
mv opera-v2.0.47-elemont-linux-amd64 opera && chmod +x opera

./opera version
# Expected: Version: 2.0.47-elemont
```

The published binary is built against **GLIBC_2.34**, so it runs on Ubuntu 22.04 (glibc 2.35)
and newer. Run `./opera version` on the **target host** — a binary that cannot exec there is
something you want to discover now, not after `systemctl stop`.

**Option B — build from source:**

```bash
git clone https://github.com/VinuChain/VinuChain.git $HOME/vinuchain-upgrade
cd $HOME/vinuchain-upgrade
git checkout v2.0.47-elemont
make opera

./build/opera version
# Expected: Version: 2.0.47-elemont
```

If you build on a host newer than your fleet, the result can require a newer glibc than the
target has and will not exec there. Build on a machine matching your servers, or use Option A.
`CGO_ENABLED=0` is **not** a workaround — `go-duktape` has no non-cgo fallback and the build
fails.

Pick a path with ~2 GB free for the source tree, module cache, and the ~38 MB binary. Avoid `/tmp` — some distributions clear it on reboot and would wipe your pre-staged build. The build directory is independent of your `--datadir`; the build never reads or writes chain data.

**Dependency pins:** go-vinu `v1.20.25-quota`, lachesis-base `v0.1.6-elemont`.

{% endstep %}
{% step %}

### 4. Check disk headroom for a pre-swap backup

Take a copy of your chaindata (or an EBS/volume snapshot) before the swap. That is your fast rollback path if anything goes wrong. A fully-synced mainnet validator datadir is on the order of tens of GB; a trace/API node is substantially larger. Confirm you have room for a copy, or use a volume-level snapshot instead:

```bash
df -h /            # free space on the datadir volume
du -sh /path/to/your/datadir
```

{% endstep %}
{% step %}

### 5. Keep the old binary

Copy your current `opera` binary somewhere safe and name it for what it is:

```bash
cp /path/to/opera /path/to/opera.v2.0.0-rc.1.bak
```

Rollback **before** the activation seal is a plain binary swap back. After the seal it is not (see [Rollback](#rollback)).

{% endstep %}
{% step %}

### 6. Confirm your ports are open

| Port | Protocol | Purpose |
| --- | --- | --- |
| 3000 | **TCP and UDP** | P2P networking. UDP is not optional — opera's peer discovery is UDP, and a TCP-only firewall leaves you with a couple of bootnode peers and no working discovery. |
| 18545 | TCP | HTTP JSON-RPC (only if you expose RPC) |
| 18546 | TCP | WebSocket JSON-RPC (only if you expose WS) |

{% endstep %}
{% endstepper %}

### Pre-flight checklist

| Check | Command | Required |
| --- | --- | --- |
| Transaction indexing on | inspect `ExecStart` / `run_node.sh` | **Yes — blocks boot** |
| Go 1.25.12+ | `go version` | Yes |
| New binary built and staged | `./build/opera version` → `2.0.47-elemont` | Yes |
| Old binary kept | `ls opera.v2.0.0-rc.1.bak` | Yes |
| Chaindata backup / volume snapshot | `df -h`, provider snapshot | Strongly recommended |
| P2P 3000 TCP **and** UDP open | firewall / security group | Yes |
| `--nat extip:<your public IPv4>` in your launch command | `ps -o args= -C opera` | Yes |

---

## Upgrade day — 2026-08-29 10:00 UTC

{% hint style="info" %}
**Validators: stagger your restarts.** Do not restart the whole validator set simultaneously. Leave ~20 seconds between validators so the network keeps quorum throughout the swap, and confirm each node is back and gossiping before moving to the next.
{% endhint %}

{% stepper %}
{% step %}

### Stop your node cleanly

{% hint style="warning" %}
**Clean shutdown required.** Do **not** force-kill. A hard kill during block processing can corrupt the LevelDB chaindata and force a full re-sync. `SIGINT`/`SIGTERM` only.
{% endhint %}

{% tabs %}
{% tab title="Systemd" %}

```bash
sudo systemctl stop vinu-opera.service
```

Confirm the unit uses `KillSignal=SIGINT` (a plain `systemctl stop` otherwise sends `SIGTERM`, which opera also handles, but `SIGKILL` on timeout is what corrupts the database):

```bash
systemctl cat vinu-opera.service | grep -E 'KillSignal|TimeoutStopSec|Restart='
```

{% endtab %}
{% tab title="nohup / script" %}

```bash
pkill -TERM opera
```

Wait for the process to exit — up to a minute is normal on a large datadir. Use `pkill -KILL` only as a genuine last resort.
{% endtab %}
{% tab title="Docker" %}

```bash
docker stop opera
```

Make sure your container's stop timeout is long enough for a clean flush.
{% endtab %}
{% tab title="Manual (foreground)" %}
Send `Ctrl+C` (SIGINT) and wait for it to exit cleanly. In tmux/screen, attach first.
{% endtab %}
{% endtabs %}

Verify it is gone:

```bash
pgrep -f opera || echo "Stopped"
```

{% endstep %}
{% step %}

### Swap the binary

Copy the pre-built, pre-verified binary into place. Do **not** build on the box during the window.

```bash
# verify what you are about to install, then install it
$HOME/vinuchain-upgrade/build/opera version   # Version: 2.0.47-elemont
sha256sum $HOME/vinuchain-upgrade/build/opera

cp $HOME/vinuchain-upgrade/build/opera /path/to/your/opera
```

{% endstep %}
{% step %}

### Start your node

Start with **exactly the flags you used before**, plus `--nat extip:` if it was missing. Do not add or remove upgrade-related flags — the activation is driven by the binary's built-in mainnet rules, not by a command-line switch.

{% tabs %}
{% tab title="Systemd" %}

```bash
sudo systemctl start vinu-opera.service
sudo journalctl -u vinu-opera.service -f
```

{% endtab %}
{% tab title="nohup / script" %}

```bash
cd /path/to/build

nohup ./opera \
  --nat extip:YOUR_PUBLIC_IPV4 \
  --validator.id YOUR_VALIDATOR_ID \
  --validator.pubkey 0xYOUR_PUBKEY \
  --validator.password /absolute/path/to/password.txt \
  > validator.log &

tail -f validator.log
```

{% hint style="warning" %}
**Always use absolute paths for file flags.** `--validator.password`, `--datadir` and `--genesis` are resolved against opera's working directory, not your home directory. A bare `pw.txt` is the fastest way to lose an upgrade window to `Failed to unlock validator key: open pw.txt: no such file or directory`.
{% endhint %}
{% endtab %}
{% tab title="Docker" %}

```bash
docker start opera
docker logs -f opera
```

Confirm the datadir volume mount and port mappings are unchanged.
{% endtab %}
{% endtabs %}

{% hint style="danger" %}
**`--nat extip:YOUR_PUBLIC_IPV4` is effectively required.** Without it, opera advertises `ip=127.0.0.1` in the discovery table. The failure looks like a successful start: the process runs, logs scroll, and then the node sits at `net.peerCount == 1` on a single stale peer and never advances. Confirm the startup line shows your real address:

```text
INFO New local node record  seq=… id=… ip=<YOUR_PUBLIC_IP> udp=3000 tcp=3000
```

`curl -s ifconfig.me` from the node host gives you the value to use.
{% endhint %}

### Bootnodes

The binary has exactly **one** mainnet bootnode compiled in. That is a single point of failure
during an upgrade window, so pass both seeds explicitly rather than relying on the default:

```bash
--bootnodes "enode://0281626c7d7fc8696300688cbb19f3781aabd981d74cd16f3f5cd7885a32da4d1d9d64afbb2416b93654935a3088afbe1a4a05d823ff2146e5d1d0c2cbdeca46@188.165.195.122:3000,enode://e0d777bf4ef6318a748ffbd2c58d3b664f5132a02d711567a6df378504c49edbc3145b8f0105ea100988bd1bb57ac574a783d255b2b57abd65a5f0ae13954e77@35.161.54.139:3000"
```

The first is the built-in mainnet bootnode; the second is a public VinuChain mainnet RPC node.
Both were verified listening on TCP 3000. One reachable seed is enough — discovery finds the
rest over UDP 3000.

{% hint style="warning" %}
**UDP 3000 must be open both inbound and outbound.** Peer discovery is UDP. A firewall that
allows only TCP 3000 gets you a peer or two from the bootnode and no discovery walk-through,
which looks exactly like a healthy node that never catches up.
{% endhint %}

{% hint style="danger" %}
**Do not use the testnet bootnodes.** The binary also carries four enodes at
`44.239.129.39:3000-3003` — those are **testnet (NetworkID 206)**. Pointing a mainnet validator
at them yields zero peers.
{% endhint %}

{% endstep %}
{% step %}

### Confirm the new binary booted and staged the upgrade

You should see the ELEMONT banner:

```text
 ██╗   ██╗██╗███╗   ██╗██╗   ██╗ ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
 ██║   ██║██║████╗  ██║██║   ██║██╔════╝██║  ██║██╔══██╗██║████╗  ██║
 ██║   ██║██║██╔██╗ ██║██║   ██║██║     ███████║███████║██║██╔██╗ ██║
 ╚██╗ ██╔╝██║██║╚██╗██║██║   ██║██║     ██╔══██║██╔══██║██║██║╚██╗██║
  ╚████╔╝ ██║██║ ╚████║╚██████╔╝╚██████╗██║  ██║██║  ██║██║██║ ╚████║
   ╚═══╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

                        v2.0  -  ELEMONT

```

On a pre-SfcV2 mainnet datadir the node then logs that it has **staged** the upgrade — staging happens at boot, activation happens at the next seal:

```text
INFO Staged SfcV2 upgrade …
INFO Staged Shanghai upgrade …
```

Cancun and Prague may log as deferred until their predecessor is active; that is expected and needs no restart.

Then confirm the node is alive and following:

```bash
curl -s -X POST http://localhost:18545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'
# Expect a version string containing v2.0.47-elemont

curl -s -X POST http://localhost:18545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

{% endstep %}
{% step %}

### Wait for the activation seals, then verify

The **first** epoch seal after the validator set is on the new binary activates SfcV2, Elemont,
ElemontPubkeyValidation, Shanghai and PaybackV2 — expect it within **4 hours** of the swap
(mainnet's `MaxEpochDuration`), in the 10:50–11:15 UTC window.

**That is seal 1 of 5.** Cancun, Prague, VinuBLS12381 and VinuLatestEVM each need their own
subsequent seal, roughly four hours apart, so the upgrade is not complete until the
**02:50–03:15 UTC window on 30 August**. See [This upgrade activates across five epoch seals](#this-upgrade-activates-across-five-epoch-seals-not-one)
for the full schedule and the no-restart constraint — read that section before the window.

Leave the node running throughout; no restart is needed between seals.

Watch for the seal-1 log line:

```text
INFO Applying SFC V2 bytecode upgrade …
```

Between seals you will also see lines like `Deferring Cancun upgrade from binary rules until
Shanghai is active`, then `Staged Cancun upgrade …` once Shanghai seals. Both are normal.

Then verify the rules and the contract:

```bash
# 1. Upgrade flags
curl -s -X POST http://localhost:18545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getRules","params":["latest"],"id":1}' | python3 -m json.tool

# 2. SFC version: "304" (V1) must have become "305" (V2)
curl -s -X POST http://localhost:18545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"0xFC00FACE00000000000000000000000000000000","data":"0x54fd4d50"},"latest"],"id":1}'

# 3. SFC bytecode size: 24168 (V1) must have become 48336 (V2 Cycle-164)
curl -s -X POST http://localhost:18545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_getCode","params":["0xFC00FACE00000000000000000000000000000000","latest"],"id":1}' \
  | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["result"][2:])//2, "bytes")'
```

{% endstep %}
{% step %}

### Confirm you are on the same chain as everyone else

This is the step that catches a divergence early.

```bash
curl -s -X POST http://localhost:18545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' \
  | python3 -c 'import sys,json;r=json.load(sys.stdin)["result"];print(int(r["number"],16), r["hash"])'
```

Run the identical request against the public RPC and compare:

```bash
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' \
  | python3 -c 'import sys,json;r=json.load(sys.stdin)["result"];print(int(r["number"],16), r["hash"])'
```

Same height, same hash → you are on the canonical chain. Different hash at the same height → you diverged; go to [Troubleshooting](#wrong-event-epoch-hash).

{% endstep %}
{% endstepper %}

### Post-upgrade verification checklist

Run this after **each** seal, not once — several rows only become true at later seals.

| Check | Expected after activation |
| --- | --- |
| `opera version` | `Version: 2.0.47-elemont` |
| Startup banner | `VINUCHAIN v2.0 - ELEMONT` |
| Staging log (pre-SfcV2 datadir) | 1× `Staged SfcV2 upgrade …` at boot |
| Seal-time log | 1× `Applying SFC V2 bytecode upgrade …` |
| `vc_getRules` → `Upgrades` | `Shanghai`, `Cancun`, `Prague`, `SfcV2`, `Elemont`, `ElemontPubkeyValidation` all `true` (on top of `Berlin`, `London`, `Llr`, `Podgorica`) |
| `vc_getRules` → `Economy.QuotaCacheAddress` | **Changes at seal 1** from `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6` (V1 proxy) to `0x5D989A2d65d049e2198D91d8ddc31C918f2544AB` (`QuotaContractV2`) |
| SFC `version()` | `0x3330350…` (`"305"`) |
| `eth_getCode(0xFC00FACE…)` length | 48,336 bytes |
| `vc_getRules` → `PaybackV2` | `true` after seal 1 |
| `vc_getRules` → `VinuBLS12381` | `true` after seal 4; `eth_config` lists `BLS12_G1ADD` through `BLS12_MAP_FP2_TO_G2` |
| `vc_getRules` → `VinuLatestEVM` | `true` after seal 5; `eth_config` lists `P256VERIFY` at `0x…0100` |
| `vc_getRules` → `SfcV2Patch*`, `PaybackV2Patch` | **`false`** — re-flash flags, deliberately not set (mainnet reaches the same state without them) |
| `eth_getCode(<QuotaContractV2>)` | Non-empty. If this is `0x`, **stop** — the baked address is wrong and every fee refund will silently be zero |
| Block production | Resumes within seconds of restart; height advances |
| Peer count | Back to prior steady state within minutes |
| Block hash vs public RPC | Identical at the same height |
| `rpc_modules` | Includes `"vc":"1.0"` |
| `eth_config` | Available (it does not exist on the old binary) |
| EIP-7702 | Set-code transactions (type `0x04`) accepted; blob transactions (type `0x03`) still rejected |

---

## When activation actually happens

Three distinct moments, often confused:

1. **Restart** — you boot the new binary. The node reads its built-in mainnet rules, sees flags its datadir has not activated, and **stages** them. Nothing has changed on-chain yet.
2. **Activation seal** — at an epoch seal, staged flags transition. This is the consensus event.
3. **Sealed** — the new rules and bytecode are persisted in chaindata. From here, older binaries cannot follow the chain.

A validator that restarts after a seal is not "late" in a dangerous way — it simply needs the new binary to follow the sealed chain. A validator that is *still on the old binary* at a seal diverges.

### This upgrade activates across five epoch seals, not one

The EVM forks are deliberately **sequential**: each one only stages once its predecessor is
already active. `Cancun` waits for `Shanghai` to seal, `Prague` waits for `Cancun`,
`VinuBLS12381` waits for `Prague`, and `VinuLatestEVM` waits for `VinuBLS12381`. Before that
happens the node logs, for example, `Deferring Cancun upgrade from binary rules until Shanghai
is active` — which is normal, not an error.

That means **one fork activates per epoch seal**, and the full upgrade takes five consecutive
seals to complete.

Mainnet epoch seals are highly regular. Measured over the twelve seals before 2026-08-19, every
one landed at the 4-hour `MaxEpochDuration` cap (median 240.3 minutes, range 237.2–240.5) —
mainnet traffic does not fill the epoch gas budget, so epochs always run to the time cap. Recent
seals landed at roughly **02:48, 06:48, 10:48, 14:48, 18:48 and 22:48 UTC** — though that
boundary creeps later over time, which is why the projections below are given as windows.

Applying that cadence to a 10:00 UTC swap on 29 August, the expected sequence is:

| Seal | Expected window (UTC) | Activates |
| --- | --- | --- |
| 1 | 29 Aug **10:50 – 11:15** | `SfcV2`, `Elemont`, `ElemontPubkeyValidation`, `Shanghai`, `PaybackV2` |
| 2 | 29 Aug **14:50 – 15:15** | `Cancun` |
| 3 | 29 Aug **18:50 – 19:15** | `Prague` |
| 4 | 29 Aug **22:50 – 23:15** | `VinuBLS12381` |
| 5 | 30 Aug **02:50 – 03:15** | `VinuLatestEVM` |

**The upgrade is not complete until the fifth seal — roughly 17 hours after the window opens.**
Treat 29 August 10:00 UTC as the start of a day-long activation sequence spanning two calendar
days, not a single event.

{% hint style="info" %}
**Why a window rather than a time.** Epochs run slightly *over* the 4-hour cap — measured 240.3
minutes median against a 240.0 cap. That ~20 seconds compounds across the ~61 epochs between
mid-August and the 29th, so the seal boundary drifts by roughly 25 minutes. The table above
brackets it rather than pretending to a precision the chain does not offer.

**Do not key your runbook to these clock times.** Re-probe the real boundary about two hours
before the window and work from that:

```bash
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getEpochStats","params":["latest"],"id":1}'
```

Confirm each activation from `vc_getRules` rather than from the clock.
{% endhint %}

{% hint style="info" %}
**No restarts are needed between seals.** Staging re-runs automatically after each seal, so the
node stages the next fork on its own. Leave it running.
{% endhint %}

{% hint style="danger" %}
**Do not restart a validator within two epochs (up to 8 hours) after seal 1.** Seal 1 changes
`Economy.QuotaCacheAddress` (the PaybackV2 activation). The node's fee-refund cache warm-up
replays a window of recent blocks under a single rules snapshot, so a restart whose replay
window contains the address-changing block can reconstruct fee-refund state differently from a
never-restarted peer — and seal a different block root. Practically: **no validator restarts
between seal 1 and seal 3 on 29 August — roughly 10:50 through 19:15 UTC.**

If a restart in that window is unavoidable, compare the node's state root against a healthy peer
before letting it emit again, or restore from a snapshot taken after the window closes.
{% endhint %}

The times above are projections from the observed cadence, not guarantees. Confirm each
activation from the chain rather than the clock — poll `vc_getRules` after each expected seal.

---

## Rollback

{% hint style="warning" %}
**Before seal 1:** rollback is a routine coordinated binary swap. Stop the node cleanly, restore
`opera.v2.0.0-rc.1.bak`, start. No datadir changes needed. This is the only clean rollback window,
and it closes at the first epoch seal after the swap — expected in the 10:50–11:15 UTC window.
{% endhint %}

{% hint style="danger" %}
**After seal 1 there is no binary to roll back to.** Mainnet is jumping from `v2.0.0-rc.1`
directly to full parity, so there is no intermediate release that understands *some* of the
sealed flags. Every sealed flag persists in chain state, and the old binary does not know any of
the new rule bits — nor the V2 SFC bytecode, nor the new Quota address.

A node that must be recovered after seal 1 is recovered **from a post-activation chaindata
snapshot on the new binary**, not by downgrading. Treat any post-seal downgrade as a coordinated
incident response involving the whole validator set, never as routine maintenance.

Each subsequent seal raises the floor further: after `VinuBLS12381` seals, a binary without the
BLS rule bit and precompile set cannot follow; after `VinuLatestEVM` seals, one without the
latest-EVM execution rules and gas-cap enforcement cannot either.
{% endhint %}

---

## Troubleshooting

### Node refuses to start, complaining about transaction indexing or the Payback cache

Expected and intentional. The PaybackCache restart warm-up is fail-closed: it replays recently-sealed blocks from stored receipts so a restarted node computes the same fee-refund values as its peers. If transaction indexing was disabled, those receipts are unreadable and the node **refuses to start** rather than diverge silently.

Fix: re-sync the node from a post-activation snapshot **with transaction indexing enabled**. There is no in-place fix — the data is not there.

### `wrong event epoch hash`

```text
WARN Incoming event rejected ... err="wrong event epoch hash"
```

Your node applied a different rule set than the network at an epoch boundary. On this upgrade the overwhelmingly likely cause is that your node was on the **old binary** when the activation sealed, or it replayed history from a **pre-activation genesis** under the new binary's rules.

{% hint style="danger" %}
Do **not** try to fix this by restarting, re-syncing from genesis, or rolling the binary back and forth. A fresh or pre-activation mainnet datadir replayed under the post-ELEMONT binary re-stages the SfcV2 and EVM transitions at the wrong epoch seal and reproduces the same divergence.
{% endhint %}

Recovery: stop the node, move the diverged datadir aside, and restore from a **post-activation mainnet chaindata snapshot**, then start on `v2.0.47-elemont`. The snapshot URL and its SHA256 will be published here once the activation has sealed.

### Node starts but does not produce events

Check, in order:

1. `--nat extip:<public IPv4>` present, and the `New local node record` line shows your real IP (not `127.0.0.1`).
2. P2P port 3000 open for **both** TCP and UDP.
3. Peer count above 1: `./opera attach --exec net.peerCount <datadir>/opera.ipc`.
4. Validator flags unchanged and the password file reachable at an **absolute** path.

### Stuck at `net.peerCount == 1` with one stale peer

Classic `--nat` symptom — see above. If `--nat` is correct and discovery is still not populating, add a `static-nodes.json` in `<datadir>/go-opera/` listing the mainnet bootnode enode so opera dials it directly on every start:

```bash
mkdir -p <datadir>/go-opera
cat > <datadir>/go-opera/static-nodes.json <<'EOF'
[
  "enode://0281626c7d7fc8696300688cbb19f3781aabd981d74cd16f3f5cd7885a32da4d1d9d64afbb2416b93654935a3088afbe1a4a05d823ff2146e5d1d0c2cbdeca46@188.165.195.122:3000"
]
EOF
```

### `vc_getRules` still shows the old four flags after restart

Expected until the activation seal. Staging happens at boot; activation happens at the next epoch seal (up to 4 hours). Confirm you saw `Staged SfcV2 upgrade …` in the boot log — that is the proof the new binary is doing its job. If that line is absent and `web3_clientVersion` still reports `v2.0.0-rc.1`, the binary swap did not take effect.

### Fresh install rather than an upgrade

{% hint style="warning" %}
**Do not bootstrap a new mainnet node from the original genesis around this upgrade.** The mainnet genesis presets pre-date the ELEMONT activations, so a replay under the new binary re-stages SfcV2 and the EVM forks at the wrong epoch seal and diverges with `wrong event epoch hash`.

Bootstrap new mainnet nodes from a **post-activation chaindata snapshot** instead. Avoid starting a fresh mainnet install during the upgrade window itself.
{% endhint %}

Setting up a brand-new validator is out of scope here — see [Become a Validator](../nodes-and-validators/become-a-validator.md). Note that from the activation seal onward, `createValidator` requires a canonical 66-byte `0xc0`-prefixed pubkey; malformed keys are rejected.

---

## For stakers and delegators

No action is required from stakers for this upgrade, and no balances, addresses, or the chain ID change.

What does change once SfcV2 activates:

- Staking, delegation, lockups, and rewards are governed by the **V2** SFC contract. If you integrate against the SFC ABI directly, re-check your bindings against V2 after the seal.
- **30% of the validator base-fee share is burned.**
- `reactivateValidator` becomes self-service for a validator's own `auth` key after an anti-flap cooldown. Doublesign/cheater validators remain permanently un-reactivatable.
- Payback / fee-refund staking **moves to a new contract** — see the next section. If you stake for fee refunds (as opposed to delegating to a validator), you must migrate.

---

## Claiming staking rewards after the upgrade — expect multiple transactions

**This affects most mainnet delegators and is the likeliest source of support questions.**

The V2 staking contract settles rewards in bounded chunks: each call advances your reward cursor
by at most **100 epochs** (`_stashRewards` clamps it via `_safeCursorPosition`).
`pendingRewards()` is *not* bounded the same way — it computes across the whole outstanding range
and keeps reporting the full total. So after the upgrade you can see a large `pendingRewards`
figure and have a single `claimRewards` transaction pay only a fraction of it.

Nothing is lost. The remainder stays claimable; it just needs further calls.

**How many calls: `ceil(cursor_gap / 100)`.** That is exact — it depends only on how far behind
your cursor is, not on reward amounts. Read the cursor with
`stashedRewardsUntilEpoch(you, validatorID)` and subtract it from the current sealed epoch.

Measured against live mainnet at sealed epoch **7,835** (2026-08-21), over **226** delegations
enumerated from `Delegated` logs holding non-zero `getStake`:

| | |
|---|---|
| Delegations with a cursor more than 100 epochs behind | **143 of 226** |
| Median gap *among those affected* | **3,919 epochs** |
| Largest gap | **7,640 epochs** — **77** calls to settle fully |
| Affected positions needing more than 40 calls | about half |

**What fraction does the first claim pay?** Not a fixed percentage — it depends on how rewards
fell across your gap, not just its length. Computed exactly from the per-epoch accumulated reward
rate, for the 82 affected positions whose validator has a non-zero rate across the range:

| First `claimRewards` settles | Positions |
|---|---|
| Median | **5.67%** of the displayed figure |
| Under 10% | 60 of 82 |
| Under 5% | 33 of 82 |
| Best case | 94.91% |

A first claim paying a few percent of what your wallet displays is therefore the **normal** case,
not a fault. Two measured positions settle **0.00%** on the first call — their first 100-epoch
window holds no reward at all, which is exactly the `"zero rewards"` revert described below.

What to do:

- **Claim repeatedly** until `pendingRewards()` reaches zero. Each call is an ordinary
  transaction and advances the cursor another 100 epochs.
- **Check `stashedRewardsUntilEpoch(delegator, validatorID)`** to watch the cursor advance, and
  compare it against the current epoch from `eth_currentEpoch`.
- **A claim may revert `"zero rewards"` partway through a sequence** if the next 100-epoch window
  happens to contain no reward. That is not the end of your rewards — it means that particular
  window is empty. `undelegate`, `lockStake` and `unlockStake` also advance the cursor and can be
  used to move past an empty window.

{% hint style="info" %}
**Claiming before the upgrade settles the whole range in one transaction.** The current V1
contract has no 100-epoch bound. If you have a large outstanding balance and would rather not
send a long sequence of transactions, claim **before 29 August**.
{% endhint %}

{% hint style="success" %}
**Locked positions are safe — this was fixed before the upgrade shipped.** An earlier revision of
the V2 contract (Cycle-164) cleared a delegator's lockup record the first time rewards were
settled after the lockup expired, judged on wall-clock alone. Combined with chunked settlement,
that applied the lockup bonus to only the first 100-epoch window and paid the remainder at the
lower unlocked rate.

Mainnet does **not** activate that revision. It activates **Cycle-165**, which deletes the lockup
record only once the cursor has settled every payable epoch — reproducing the pre-chunking
single-sweep accounting exactly. You receive the same total whether you claim in one V1
transaction beforehand or in a long V2 sequence afterwards; only the number of transactions
differs. Verified on a forked chain to the wei: 47 chunked claims summed to the unclamped
`pendingRewards` total with a residual of zero.
{% endhint %}

---

## If you stake in the Payback (fee-refund) contract <a href="#if-you-stake-in-the-payback-fee-refund-contract" id="if-you-stake-in-the-payback-fee-refund-contract"></a>

**Action required.** This is the one part of the upgrade that asks something of ordinary users.

VinuChain's fee-refund ("Payback") system reads your stake from a Quota contract. Today that is
an upgradeable proxy at `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6`, whose administrative key is
not recoverable — which is why it cannot be upgraded in place. At **seal 1** the protocol switches
to a newly deployed, non-proxy `QuotaContractV2` with a recoverable owner.

**Your VC is safe.** `unstake` and `withdrawStake` on the old contract are permissionless and are
not affected by the upgrade — you can always get your own funds out. What changes is that the
protocol stops reading the old contract, so **stake left there stops earning fee refunds.**

The new contract keeps the same parameters as the old one: `feeRefundBlockCount` 75, `minStake`
10 VC, `quotaFactor` 21,000, and a 1-day withdrawal hold.

### Migrating

1. **Unstake from the old contract** — call `unstake(uint256 amount)` on
   `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6`. This returns a withdrawal-request ID and starts
   a **1-day** hold. You can do this before or after 29 August.
2. **Wait out the 1-day hold**, then call `withdrawStake(uint256 wrID)` on the same contract with
   that ID. Your VC returns to your wallet.
3. **Stake on the new contract** — call `stake()` on
   **`0x5D989A2d65d049e2198D91d8ddc31C918f2544AB`** with your VC as the transaction
   value. Minimum 10 VC. Do this only **after** seal 1; staking earlier is safe but earns
   nothing until the protocol switches over.

Doing steps 1 and 2 **before 29 August** gives the shortest gap in refund eligibility. Migrating
later is fine too; you simply earn no fee refunds in the meantime.

### Confirming the switch

```bash
# Economy.QuotaCacheAddress should be the new contract, and Upgrades.PaybackV2 true
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getRules","params":["latest"],"id":1}' | python3 -m json.tool

# your available fee-refund quota on the new contract
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getPaybackBalance","params":["0xYOUR_ADDRESS","latest"],"id":1}'
```

**`QuotaContractV2` — mainnet**

| | |
|---|---|
| Address | `0x5D989A2d65d049e2198D91d8ddc31C918f2544AB` |
| Deployed | 2026-08-21, block 14,616,227 |
| Deploy tx | `0x0456aab6fe358da173bf8fa93ec5772de18937008fd201d828adee9dd678b506` |
| Source | [verified on VinuExplorer](https://mainnet.vinuexplorer.org/address/0x5D989A2d65d049e2198D91d8ddc31C918f2544AB/contracts) — solc `v0.8.19+commit.7dd6d404`, optimizer on, 200 runs |

Read the source before you stake into it. Until seal 1 the protocol still reads the V1 proxy, so
the new contract holding no stake before the upgrade is expected, not a fault.

---

## Breaking changes to check before the 29th <a href="#breaking-changes-to-check-before-the-29th" id="breaking-changes-to-check-before-the-29th"></a>

Full parity turns on rules that mainnet has never enforced. These can reject transactions or
deployments that succeed today:

| Change | Seals at | What breaks |
| --- | --- | --- |
| **EIP-7825 per-transaction gas cap** (`VinuLatestEVM`) | Seal 5 | Transactions above **16,777,216** gas (2^24) are rejected — by the txpool, at state transition, and in block execution. `eth_estimateGas` caps its result at the same limit. Note the cap is *below* mainnet's 20,500,000 block gas limit, so there is a real band of transactions that succeed today and would not afterwards. **Measured risk is low:** across 400 recent mainnet blocks (842 transactions) the largest per-transaction gas limit observed was 21,000 — a plain transfer, 0.13% of the cap — and nothing came close. If you submit high-gas batch operations, check them against the cap anyway. |
| **EIP-3860 initcode limit, 49,152 bytes** (`Shanghai`) | Seal 1 | Contract deployments whose initcode exceeds the limit fail. The same 400-block sample contained no contract deployments at all, so current mainnet activity is unaffected — but check any large contract you plan to deploy. |
| **SFC ABI V1 → V2** (`SfcV2`) | Seal 1 | The staking contract at `0xFC00FACE00000000000000000000000000000000` is replaced. `version()` goes `"304"` → `"305"`. Re-check any direct SFC integration. |
| **Quota contract replaced** (`PaybackV2`) | Seal 1 | `Economy.QuotaCacheAddress` changes; fee-refund stake must be migrated (above). Indexers reading the `feeRefund` receipt field should re-verify against the new contract. |
| **Canonical validator pubkeys** (`ElemontPubkeyValidation`) | Seal 1 | `createValidator` rejects pubkeys that are not the canonical 66-byte `0xc0`-prefixed form. |

If you operate a bridge, exchange integration, indexer, or bot against mainnet, test against
**testnet** (chain 206) before the 29th — testnet has been running this exact feature set for
months and is the accurate preview.

---

## For dApp developers

As the seals progress, mainnet accepts Solidity compiled for the `shanghai`, `cancun`, and
`prague` EVM versions — `PUSH0`, transient storage, `MCOPY`, and EIP-7702 set-code transactions
all become available — and then gains the BLS12-381 precompiles (`0x0b`–`0x11`) and
`P256VERIFY` (`0x0100`). Blob transactions (EIP-4844) remain unsupported.

Each capability only works once **its** seal lands, so check `eth_config` / `vc_getRules` rather
than assuming everything is live at 10:00 UTC. `P256VERIFY` is last, in the 30 August 02:50–03:15 UTC window.

Until the seal, mainnet is still a London-era EVM. Do not deploy Shanghai-or-later bytecode to mainnet before the activation is confirmed.

---

## See also

- [ELEMONT Upgrade](elemont-upgrade.md) — what ELEMONT changes, in feature terms
- [Connect to Mainnet](connect-to-mainnet.md) — wallet quick-add
- [Network Details](../network-details.md) — chain IDs, RPC/WS, explorers, key contracts
- [Chain Upgrade Guide (v2-elemont)](../vinuchain-testnet/chain-upgrade-guide.md) — the testnet equivalent, including the full per-release changelog
- [Become a Validator](../nodes-and-validators/become-a-validator.md)
- [Troubleshooting](../nodes-and-validators/troubleshooting.md)
