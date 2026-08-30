<!-- markdownlint-disable MD013 -->

# Mainnet Upgrade Guide (ELEMONT)

{% hint style="danger" %}
**Upgrade window: Saturday 29 August 2026 at 10:00 UTC.**

Every VinuChain mainnet validator and RPC/API node must move from
`v2.0.0-rc.1` to `v2.0.49-elemont`. A node still using the old binary when the
first activation epoch seals will leave the canonical chain.
{% endhint %}

## Outcome

Use this runbook for an **existing, synced native linux/amd64 mainnet node**
managed by systemd or an existing script. You are finished when:

- the local client reports `v2.0.49-elemont`;
- the node is advancing with its normal peer count;
- all five activation seals have completed, ending with `VinuLatestEVM`;
- the local block hash matches the public mainnet RPC at the same height.

This is one in-place binary upgrade. Do not create a new datadir, replay the
original genesis under `v2.0.49-elemont`, or change working network flags during
the cutover. For the
feature and user-impact summary, see [ELEMONT Upgrade](elemont-upgrade.md).

| Item | Required value |
| --- | --- |
| Network | VinuChain Mainnet |
| Chain ID | `207` (`0xcf`) |
| Existing client | `v2.0.0-rc.1` |
| Target release | [`v2.0.49-elemont`](https://github.com/VinuChain/VinuChain/releases/tag/v2.0.49-elemont) |
| Release commit | `8b88cc49d11e56635385413fe8f9eaec1969c1ac` |
| Published linux/amd64 SHA256 | `678040e9f88a98331a8cc32b7bf5b9e0ae4acdf84919390465eeee584b7f56c1` |
| Public comparison RPC | `https://rpc.vinuchain.org` |

## Before you start

You need shell access as the node operator, permission through `sudo` or root to
stop the service and replace its executable, Bash, `curl`, Python 3, `awk`,
`sed`, GNU `sha256sum` and `timeout`, the existing stop/start method, and the
exact current datadir.
The published binary requires x86-64 Linux with glibc `2.34` or newer; Ubuntu
22.04 and later satisfy this requirement. Validators also need to be present in
the upgrade coordination channel. If you do not have that channel, contact the
VinuChain team through the [official Discord](https://discord.gg/vinu) before
the window opens.

Run every command block on this page in Bash. Your login shell may remain
`sh`; start a temporary Bash session before the first command and return to
`sh` afterwards:

```bash
bash
test -n "$BASH_VERSION"
```

Do not run these blocks directly under `sh`; they use Bash features such as
`pipefail`, here-strings, and brace expansion. After completing the guide, type
`exit` once to return to the original `sh` session.

This is not a container deployment procedure. If the binary lives inside a
container, do not improvise from the native commands: require a
deployment-specific runbook with the exact image digest, stop/start commands,
health checks, and pre-seal rollback. The configuration, seal, and canonical
chain checkpoints on this page still apply.

In the commands below, replace:

- `<OPERA>` with the absolute path of the binary the current process uses;
- `<STAGED>` with the absolute path of the downloaded new binary;
- `<UPGRADE_DIR>` with an absolute working directory such as
  `/home/node/vinuchain-upgrade-20260829`;
- `<DATADIR>` with the exact current datadir;
- `<LOCAL_RPC>` with the node's existing local RPC endpoint. Prefer its actual
  IPC path; the default is `<DATADIR>/opera.ipc`;
- `<NODE_USER>` with the OS account that runs the node;
- `<NODE_HOME>` with the running process's `HOME` value, or that account's home
  directory when `HOME` is absent;
- `<SERVICE>` with the current systemd unit, if applicable;
- `<EXISTING_CONFIG_STORAGE_RPC_FLAGS>` with the recorded `--config`,
  `--datadir`, IPC, HTTP, WebSocket, and legacy RPC flags from the current
  process, or nothing when none are present;
- `<EXACT_EXISTING_START_COMMAND_OR_SCRIPT>` with the recorded command or
  script, unchanged;
- `<EXPECTED_SHA256>` with the published checksum above, or the checksum of a
  source-built binary;
- `<HEIGHT>` with a decimal block height a few blocks behind the local tip;
  choose a fresh value for each canonical-chain check.

Run attach commands as the same OS user that runs the node. Do not enable or
expose HTTP/WS solely for this guide.

### 1. Record the current launch and health state

Record the process, executable, working directory, full arguments, datadir,
peer count, and P2P ports before stopping anything.

For a process managed by an existing script, list exact-name matches and select
only the PID whose executable, arguments, and datadir match this node:

```bash
pgrep -a -x opera
OPERA_PID=<PID_FOR_THIS_NODE>
```

For systemd, take the PID from the unit:

```bash
systemctl show <SERVICE> -p FragmentPath -p User -p WorkingDirectory \
  -p ExecStart -p MainPID -p KillSignal -p TimeoutStopUSec -p Restart
systemctl cat <SERVICE>
OPERA_PID=$(systemctl show <SERVICE> --property MainPID --value)
```

Then record the selected process:

```bash
ps -o user= -p "$OPERA_PID"
readlink -f "/proc/$OPERA_PID/exe"
readlink -f "/proc/$OPERA_PID/cwd"
tr '\0' ' ' < "/proc/$OPERA_PID/cmdline"; printf '\n'
tr '\0' '\n' < "/proc/$OPERA_PID/environ" | sed -n 's/^HOME=/HOME=/p'
```

Record the old binary's effective storage and RPC configuration with the same
OS user, `HOME`, `--config`, and `--datadir` flags as the running process:

```bash
set -euo pipefail
sudo -u <NODE_USER> -- env HOME="<NODE_HOME>" \
  <OPERA> <EXISTING_CONFIG_STORAGE_RPC_FLAGS> dumpconfig \
  | grep -E '^(DataDir|IPCPath|HTTPHost|HTTPPort|WSHost|WSPort|TxIndex) ='
```

Omit `sudo -u <NODE_USER> -- env HOME="<NODE_HOME>"` if this shell already runs
as the node user with the same `HOME`. Set `<DATADIR>` to the reported
`DataDir`. When `IPCPath` is `"opera.ipc"`, set `<LOCAL_RPC>` to
`<DATADIR>/opera.ipc`. If IPC is disabled, use an already configured loopback
RPC endpoint; if none exists, stop and ask the upgrade coordinator for a local
verification route.

Then record the local baseline:

```bash
<OPERA> attach --exec 'web3.version.node' <LOCAL_RPC>
<OPERA> attach --exec 'net.version' <LOCAL_RPC>
<OPERA> attach --exec 'vc.blockNumber' <LOCAL_RPC>
<OPERA> attach --exec 'net.peerCount' <LOCAL_RPC>
<OPERA> attach --exec 'admin.nodeInfo.ports' <LOCAL_RPC>
```

Expected before the upgrade: the client contains `v2.0.0-rc.1`, network is
`207`, height is above `14551915` and advancing, and peer count is at its
normal level.

Prove the existing node is on the canonical chain before changing it:

```bash
<OPERA> attach --exec 'vc.getBlock(<HEIGHT>).hash' <LOCAL_RPC>
<OPERA> attach --exec 'vc.getBlock(<HEIGHT>).hash' https://rpc.vinuchain.org
```

Expected: identical non-null hashes. Stop here if they differ.

{% hint style="info" %}
`18545` and `18546` are optional HTTP and WebSocket RPC ports. HTTP is enabled
with `--http` or the legacy `--rpc` alias. A validator-only node normally has
nothing listening on either RPC port. Local IPC is the recommended verification
route. The P2P listener is `5050` by default, or the effective configured value,
and uses TCP and UDP.
{% endhint %}

### 2. Confirm historical transaction indexing

The new binary rebuilds its Payback cache from stored receipts at startup and
fails closed if historical transaction data is missing. `TxIndex` is enabled
by default; VinuChain has no `--txindex` or `--txlookuplimit` flag to add.

First ask the existing node for a known indexed transaction:

```bash
<OPERA> attach --exec \
  'vc.getTransaction("0xfa3cbe1ec4220bee33a30d7f922ff4274489503f6c48729abce40e71589988f0")' \
  <LOCAL_RPC>
```

Expected: a transaction object with `blockNumber: 14551915`. An explicit
transaction-index-disabled error proves indexing is off. `null` is not proof by
itself: check that this is the recorded datadir, the node is above block
`14551915`, and its history has not been pruned. If the object still does not
appear, the node is not ready. Enabling indexing now does not recreate old
receipts; stop here and ask the VinuChain upgrade coordinator for a verified
indexed snapshot and recovery plan.

### 3. Download and verify the published binary

The published linux/amd64 binary is the recommended path. It does not require a
Go installation.

```bash
set -euo pipefail
test "$(uname -m)" = x86_64
ELEMONT_GLIBC_VERSION=$(getconf GNU_LIBC_VERSION | awk '{print $2}')
printf 'glibc %s\n' "$ELEMONT_GLIBC_VERSION"
python3 -c 'import sys; sys.exit(tuple(map(int,sys.argv[1].split("."))) < (2,34))' \
  "$ELEMONT_GLIBC_VERSION"

mkdir -p "<UPGRADE_DIR>"
cd "<UPGRADE_DIR>"

curl --fail --location --remote-name --retry 3 \
  https://github.com/VinuChain/VinuChain/releases/download/v2.0.49-elemont/opera-v2.0.49-elemont-linux-amd64
printf '%s  %s\n' \
  '678040e9f88a98331a8cc32b7bf5b9e0ae4acdf84919390465eeee584b7f56c1' \
  'opera-v2.0.49-elemont-linux-amd64' \
  | sha256sum -c -
chmod 0755 opera-v2.0.49-elemont-linux-amd64
ELEMONT_STAGED_VERSION=$(./opera-v2.0.49-elemont-linux-amd64 version)
printf '%s\n' "$ELEMONT_STAGED_VERSION"
grep -Fq 'Version: 2.0.49-elemont' <<<"$ELEMONT_STAGED_VERSION"
grep -Fq 'Git Commit: 8b88cc49d11e56635385413fe8f9eaec1969c1ac' \
  <<<"$ELEMONT_STAGED_VERSION"
```

Expected: `x86_64`, glibc `2.34` or newer, checksum `OK`, and
`Version: 2.0.49-elemont`. Run these commands on the target host so an
incompatible system is found before downtime. Set `<STAGED>` to this file's
absolute path.

Now inspect the **effective new-binary configuration** without starting the
node:

```bash
set -euo pipefail
sudo -u <NODE_USER> -- env HOME="<NODE_HOME>" \
  <STAGED> <EXISTING_CONFIG_STORAGE_RPC_FLAGS> dumpconfig \
  | grep -E '^(DataDir|IPCPath|HTTPHost|HTTPPort|WSHost|WSPort|TxIndex) ='
```

Use no flags in `<EXISTING_CONFIG_STORAGE_RPC_FLAGS>` if the current command
uses none. Do not copy validator credentials or unrelated flags into this
placeholder. Omit the `sudo ... env` prefix if this shell already runs as the
node user with the same `HOME`. Ensure that user can execute `<STAGED>`. The
exact home directory matters because it determines a default datadir. Expected:

- `TxIndex = true`;
- `DataDir` and `IPCPath` match the old effective configuration;
- HTTP/WS enablement is unchanged.

On Linux, an old flagless node normally uses `~/.opera`. `v2.0.49-elemont`
continues using a populated `~/.opera` when `~/.vinuchain` is absent or only an
unused shell. If both directories contain chain state, `dumpconfig` reports
`~/.vinuchain`. If that differs from the old effective `DataDir`, add
`--datadir "<DATADIR>"` to both the staged check and the recorded launch method,
then rerun `dumpconfig`. This explicit pin is the only permitted launch change.
Abort if the old and staged effective values still differ.

Keep a verified copy of the currently running binary:

```bash
set -euo pipefail
if ! sudo test -e "<OPERA>.v2.0.0-rc.1.bak"; then
  sudo cp -a "<OPERA>" "<OPERA>.v2.0.0-rc.1.bak"
fi
ELEMONT_OLD_VERSION=$(sudo "<OPERA>.v2.0.0-rc.1.bak" version)
printf '%s\n' "$ELEMONT_OLD_VERSION"
grep -Fq 'Version: 2.0.0-rc.1' <<<"$ELEMONT_OLD_VERSION"
sudo sha256sum "<OPERA>.v2.0.0-rc.1.bak" \
  | tee "<UPGRADE_DIR>/opera-v2.0.0-rc.1.bak.sha256"
sudo sha256sum -c "<UPGRADE_DIR>/opera-v2.0.0-rc.1.bak.sha256"
```

Expected: the backup reports `v2.0.0-rc.1` and its recorded checksum verifies.

#### Alternative: build from source

Use this only when the published linux/amd64 binary cannot run on the target.
It requires Git, a C compiler, Go `1.25.13` or newer, and several gigabytes of
free build space.

```bash
set -euo pipefail
git clone --branch v2.0.49-elemont --depth 1 \
  https://github.com/VinuChain/VinuChain.git vinuchain-v2.0.49
cd vinuchain-v2.0.49
test "$(git rev-parse HEAD)" = 8b88cc49d11e56635385413fe8f9eaec1969c1ac
test -z "$(git status --porcelain)"
go version
ELEMONT_GO_VERSION=$(go env GOVERSION | sed 's/^go//')
python3 -c 'import sys; sys.exit(tuple(map(int,sys.argv[1].split("."))) < (1,25,13))' \
  "$ELEMONT_GO_VERSION"
make opera
ELEMONT_BUILD_VERSION=$(./build/opera version)
printf '%s\n' "$ELEMONT_BUILD_VERSION"
grep -Fq 'Version: 2.0.49-elemont' <<<"$ELEMONT_BUILD_VERSION"
grep -Fq 'Git Commit: 8b88cc49d11e56635385413fe8f9eaec1969c1ac' \
  <<<"$ELEMONT_BUILD_VERSION"
sha256sum ./build/opera
```

Expected: Go is at least `1.25.13` and the binary reports
`Version: 2.0.49-elemont`. Build on a system compatible with the target host;
`CGO_ENABLED=0` is not supported by this source tree. Record the checksum from
this build, set `<STAGED>` to the absolute path of `./build/opera`, and use the
recorded checksum instead of the published checksum in the install step.

### 4. Confirm identity backups and the safety window

Confirm that the validator keystore and P2P `nodekey` already have a protected,
offline backup. Never put either secret in the public upgrade directory,
snapshot, logs, or support messages. The official post-activation snapshot
will deliberately exclude identity files.

- Before the first validator stop, a named coordinator must post a timestamped
  **GO** in the designated validator channel. The message must confirm that the
  ready/online validator IDs represent more than two-thirds of active stake,
  name the recovery owner, and identify where stage-matched snapshot manifests,
  checksums, and restore instructions will be posted. Save the message link and
  do not proceed without it.
- Validators must coordinate a staggered restart and keep more than two-thirds
  of active stake participating. Restart one validator at a time and wait for
  its immediate canonical-hash checkpoint before moving to the next.
- A live filesystem copy is not a valid LevelDB backup. A non-validator RPC
  node may use a storage-level snapshot taken while fully stopped. A validator
  must never restore a pre-swap datadir after it has emitted again; preserve its
  identity backup and old binary instead.
- Freeze every fresh mainnet node start during activation. After seal 5, new
  nodes may start only from the verified post-activation snapshot and only when
  the coordinator opens snapshot-based onboarding. Original-genesis replay
  under `v2.0.49-elemont` remains prohibited until the team publishes a
  compatible maintenance binary and regenerated genesis.
- Leave the new process running between seals. In particular, **do not restart
  a validator from seal 1 until seal 3 is observed**. Seal 1 changes the
  Payback contract address, and the two-epoch cache replay window makes a
  validator restart in that interval unsafe.

## Upgrade day

Start these steps at **2026-08-29 10:00 UTC**, after recording the required
coordinator **GO** message.

### 1. Stop the existing node cleanly

Use the node's existing supervisor. For systemd:

```bash
set -euo pipefail
timeout 5m sudo systemctl stop <SERVICE>
if systemctl is-active --quiet <SERVICE>; then
  echo 'ABORT: service is still active' >&2
  exit 1
fi
test "$(systemctl show <SERVICE> --property MainPID --value)" = 0
```

For an existing script/manual process, revalidate the current PID against the
executable, arguments, and datadir recorded in pre-flight. Do not blindly reuse
an old PID:

```bash
set -euo pipefail
pgrep -a -x opera
OPERA_PID=<CURRENT_PID_FOR_THIS_NODE>
kill -TERM "$OPERA_PID"
for ELEMONT_WAIT_SECOND in {1..300}; do
  if ! kill -0 "$OPERA_PID" 2>/dev/null; then
    break
  fi
  sleep 1
done
if kill -0 "$OPERA_PID" 2>/dev/null; then
  echo 'ABORT: node did not stop within five minutes' >&2
  exit 1
fi
```

Finally, prove that no process still executes the binary before overwriting it:

```bash
set -euo pipefail
for ELEMONT_PROC_EXE in /proc/[0-9]*/exe; do
  if [ "$(readlink -f "$ELEMONT_PROC_EXE" 2>/dev/null || true)" = "<OPERA>" ]; then
    echo "ABORT: $ELEMONT_PROC_EXE still executes <OPERA>" >&2
    exit 1
  fi
done
```

`SIGINT` and `SIGTERM` allow LevelDB to close cleanly. Do not use `SIGKILL`; if
shutdown does not complete, stop the procedure and ask the upgrade coordinator.

### 2. Install the verified binary atomically

```bash
set -euo pipefail
sudo cp "<STAGED>" "<OPERA>.new"
sudo chown --reference="<OPERA>" "<OPERA>.new"
sudo chmod --reference="<OPERA>" "<OPERA>.new"
printf '%s  %s\n' \
  '<EXPECTED_SHA256>' \
  '<OPERA>.new' \
  | sudo sha256sum -c -
ELEMONT_NEW_VERSION=$(sudo "<OPERA>.new" version)
printf '%s\n' "$ELEMONT_NEW_VERSION"
grep -Fq 'Version: 2.0.49-elemont' <<<"$ELEMONT_NEW_VERSION"
grep -Fq 'Git Commit: 8b88cc49d11e56635385413fe8f9eaec1969c1ac' \
  <<<"$ELEMONT_NEW_VERSION"
sudo mv -f "<OPERA>.new" "<OPERA>"
stat -c '%U:%G %a %n' "<OPERA>"
"<OPERA>" version
```

Expected: checksum `OK` and `Version: 2.0.49-elemont`.

For the published binary, replace `<EXPECTED_SHA256>` with
`678040e9f88a98331a8cc32b7bf5b9e0ae4acdf84919390465eeee584b7f56c1`.
For a source build, use the checksum recorded immediately after the build.

### 3. Start with the unchanged launch method

Use the same service or script recorded in pre-flight:

```bash
# systemd
sudo systemctl start <SERVICE>
systemctl is-active <SERVICE>
sudo journalctl -u <SERVICE> -n 100 --no-pager

# script/nohup
<EXACT_EXISTING_START_COMMAND_OR_SCRIPT>
```

Set `--bootnodes` to the canonical mainnet list below. Older launch commands
may carry a bootnode hostname that no longer resolves, and opera refuses to
start on an unresolvable bootnode:

```text
CRIT Bootstrap URL invalid ... err="lookup <host>: no such host"
```

```bash
--bootnodes "enode://678f242c2d60ed433c23bba0f9ea00982ea9bc5eb1d7f91337c23ccec5f41c9634705fa79994ba8f62ee893574451631a10f694cfa684f75524de79a7e50f890@54.244.138.80:3000,enode://e0d777bf4ef6318a748ffbd2c58d3b664f5132a02d711567a6df378504c49edbc3145b8f0105ea100988bd1bb57ac574a783d255b2b57abd65a5f0ae13954e77@35.161.54.139:3000"
```

| Bootnode | Address |
|---|---|
| Mainnet validator | `54.244.138.80:3000` |
| Mainnet RPC (`rpc.vinuchain.org`) | `35.161.54.139:3000` |

Apart from `--bootnodes`, do not add `--port`, `--http`, `--ws`, or `--nat`
during the cutover. Do not change `--datadir` or the working directory. If the
old command omitted `--datadir` and both effective configurations matched, keep
it omitted. If pre-flight required the explicit datadir pin, use that one
recorded change.

Expected startup logs include:

```text
Staged SfcV2 upgrade from binary rules; will activate at next epoch seal
Staged Shanghai upgrade from binary rules; will activate at next epoch seal
Deferring Cancun upgrade from binary rules until Shanghai is active
```

The Cancun deferral is normal. It advances automatically after Shanghai seals;
no restart is needed.

### 4. Verify the immediate restart checkpoint

```bash
<OPERA> attach --exec 'web3.version.node' <LOCAL_RPC>
<OPERA> attach --exec 'net.version' <LOCAL_RPC>
<OPERA> attach --exec 'vc.blockNumber' <LOCAL_RPC>
<OPERA> attach --exec 'net.peerCount' <LOCAL_RPC>
<OPERA> attach --exec 'admin.nodeInfo.ports' <LOCAL_RPC>
```

Expected: the client contains `v2.0.49-elemont`, network is `207`, height
advances from the pre-flight baseline, peer count returns toward its normal
value, and the P2P port is unchanged.

Repeat the canonical-chain check with a fresh height a few blocks behind the
local tip:

```bash
<OPERA> attach --exec 'vc.getBlock(<HEIGHT>).hash' <LOCAL_RPC>
<OPERA> attach --exec 'vc.getBlock(<HEIGHT>).hash' https://rpc.vinuchain.org
```

Expected: identical non-null hashes. If they differ, stop the node immediately.
Do not move to the next validator or allow this validator to continue emitting
until the coordinator approves recovery.

{% hint style="danger" %}
If the node starts near genesis or far below the recorded height, stop it
immediately. It opened the wrong datadir. Do not delete either `.opera` or
`.vinuchain`; restore the recorded launch configuration and point it at the
known current datadir.
{% endhint %}

## Verify the five activation seals

Activation is driven by epoch seals, not the wall clock. The first seal
activates the main ELEMONT transition; four later seals activate the remaining
EVM stages. The complete sequence can take up to roughly 20 hours after the
swap.

`vc_getEpochStats("latest")` returns the latest **sealed** epoch. Its `end`
timestamp is therefore the current epoch's start. Use it to calculate the
four-hour sealing boundary:

```bash
curl --fail --max-time 15 -sS -X POST https://rpc.vinuchain.org \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getEpochStats","params":["latest"],"id":1}' \
  | python3 -c 'import json,sys; from datetime import datetime,timedelta,timezone; p=json.load(sys.stdin); r=p.get("result"); r or sys.exit(str(p.get("error","missing result"))); sealed=int(r["epoch"],16); start=datetime.fromtimestamp(int(r["end"],16)/1e9,timezone.utc); print("latest sealed epoch:",sealed); print("current epoch:",sealed+1); print("current epoch started:",start.isoformat()); print("four-hour sealing boundary:",(start+timedelta(hours=4)).isoformat())'
```

This is a consensus boundary, not a scheduled seal time. If the public chain
remains on the same epoch after the boundary and seal progress stalls, stop
further validator restarts and escalate to the upgrade coordinator.

Confirm each seal locally:

```bash
<OPERA> attach --exec \
  'var r=web3.currentProvider.send({jsonrpc:"2.0",method:"vc_getRules",params:["latest"],id:1}).result; console.log(JSON.stringify(r,null,2))' \
  <LOCAL_RPC>
```

| Checkpoint | Newly active flags |
| --- | --- |
| Seal 1 | `SfcV2`, `Elemont`, `ElemontPubkeyValidation`, `Shanghai`, `PaybackV2` |
| Seal 2 | `Cancun` |
| Seal 3 | `Prague` |
| Seal 4 | `VinuBLS12381` |
| Seal 5 | `VinuLatestEVM` |

After seal 1, also confirm the contract transition:

```bash
# "305" encoded as bytes32
<OPERA> attach --exec \
  'vc.call({to:"0xFC00FACE00000000000000000000000000000000",data:"0x54fd4d50"},"latest")' \
  <LOCAL_RPC>

# Exact Cycle-165 SFC runtime keccak
<OPERA> attach --exec \
  'web3.sha3(vc.getCode("0xFC00FACE00000000000000000000000000000000","latest"))' \
  <LOCAL_RPC>
```

Expected:

```text
0x3330350000000000000000000000000000000000000000000000000000000000
0x29b88152209fe22bef409376aa7f137d0e0f571f46afa1385f32320765e49e50
```

The seal-1 rules must also show:

```text
Economy.QuotaCacheAddress = 0x5D989A2d65d049e2198D91d8ddc31C918f2544AB
```

Leave the process running throughout. Validators must not restart between
seal 1 and seal 3. If a validator crashes in that interval, keep it from
emitting and contact the upgrade coordinator before attempting recovery.

## Final verification

After seal 5, rerun `vc_getRules` and confirm all of these are `true`:

```text
Berlin London Shanghai Cancun Prague VinuBLS12381 VinuLatestEVM
Llr Podgorica SfcV2 Elemont ElemontPubkeyValidation PaybackV2
```

All `SfcV2Patch*` flags and `PaybackV2Patch` must remain absent or `false`;
they are testnet repair flags, not missing mainnet features.

Then compare the same block height locally and publicly. Choose a height a few
blocks behind the local tip and replace `<HEIGHT>` in both commands:

```bash
<OPERA> attach --exec 'vc.blockNumber' <LOCAL_RPC>

<OPERA> attach --exec 'vc.getBlock(<HEIGHT>).hash' <LOCAL_RPC>
<OPERA> attach --exec 'vc.getBlock(<HEIGHT>).hash' https://rpc.vinuchain.org
```

Expected: the two hashes are identical. Also confirm the local height and peer
count continue to advance. This is the observable completion state.

## Rollback and recovery

### Before seal 1

First prove from the public chain that seal 1 has not happened:

```bash
curl --fail --max-time 15 -sS -X POST https://rpc.vinuchain.org \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getRules","params":["latest"],"id":1}' \
  | python3 -c 'import json,sys; p=json.load(sys.stdin); r=p.get("result"); r or sys.exit(str(p.get("error","missing result"))); active=r.get("Upgrades",{}).get("SfcV2",False); print("SfcV2 active:",active); sys.exit(1 if active else 0)'
```

Proceed only when it prints `SfcV2 active: False`. Coordinate the rollback,
repeat the clean stop procedure above, verify the saved checksum, and restore
the old binary atomically:

```bash
set -euo pipefail
sudo sha256sum -c "<UPGRADE_DIR>/opera-v2.0.0-rc.1.bak.sha256"
sudo cp -a "<OPERA>.v2.0.0-rc.1.bak" "<OPERA>.rollback"
sudo mv -f "<OPERA>.rollback" "<OPERA>"
```

Restart with the same launch method, then rerun the immediate restart and
same-height block-hash checks. Expected: `v2.0.0-rc.1`, advancing blocks, and a
matching canonical block hash. Use the current datadir. A validator must not
restore an older datadir copy, because re-emitting an already-seen event
sequence can double-sign.

### After seal 1

Do **not** restore the old binary or an older datadir. The new rules are
persisted, and a validator restored to old state can diverge or double-sign.

Stop the affected node and contact the VinuChain upgrade coordinator. Recovery
must use `v2.0.49-elemont` plus a verified snapshot from a healthy upgraded
peer at the correct activation stage. Neither the old binary nor a pre-seal
datadir backup is reusable. Unless the coordinator supplies a stage-matched
recovery artifact, wait for the official post-activation snapshot and SHA256
published after seal 5; there is no safe improvised post-seal rollback.

Do not use a snapshot unless its coordinator-published manifest names the exact
activation stage, download location, SHA256, datadir root layout, ownership,
and restore commands. Keep the old datadir quarantined rather than deleting it.
For a validator, restore its own backed-up keystore and `nodekey` only to the
recorded paths and permissions; never copy identity files from a snapshot.
Keep validation disabled until version `v2.0.49-elemont`, chain ID `207`,
advancing height, and a same-height canonical hash all verify and the
coordinator authorizes emission.

## Troubleshooting

### Startup reports missing transaction data or Payback cache warm-up failure

**Symptom:** startup stops with a transaction-index or Payback-cache critical
error.

**Cause:** historical receipts needed by the warm-up are absent.

**Correction:** do not repeatedly restart or only flip `TxIndex`. With the
upgrade coordinator, restore a stage-matched indexed snapshot whose manifest
meets the recovery requirements above, using `v2.0.49-elemont`.

**Verify:** the known transaction returns block `14551915`, warm-up completes,
and the node matches a public block hash at the same height.

### `wrong event epoch hash`

**Symptom:** `WARN Incoming event rejected ... err="wrong event epoch hash"`.

**Cause:** the node sealed or replayed an upgrade at a different epoch from
mainnet, commonly because it missed the activation or replayed the original
genesis under the new binary.

**Correction:** stop the node. Do not resync from the original genesis and do
not downgrade. Restore a coordinator-approved, stage-matched snapshot on
`v2.0.49-elemont` using its verified manifest.

**Verify:** local and public hashes match at the same height before a validator
is allowed to emit again.

### The version is new but the height does not advance

**Symptom:** `web3.version.node` is correct, but height or peers stay below the
recorded baseline.

**Cause:** the wrong datadir was opened, the existing P2P configuration was not
preserved, or the node cannot reach peers.

**Correction:** compare the current process arguments, working directory,
datadir, P2P port, and firewall with the pre-flight record. Restore the exact
existing values; do not enable HTTP/WS RPC or add unrelated network flags.

**Verify:** the local height advances and `net.peerCount` returns toward its
pre-upgrade level.

### Rules still show the old flags

**Symptom:** the node is healthy on `v2.0.49-elemont`, but `vc_getRules` still
shows the pre-upgrade rule set.

**Cause:** the next epoch has not sealed yet, or the validator quorum did not
upgrade.

**Correction:** confirm the staging log and the current epoch boundary. If the
four-hour boundary passes without a seal, escalate to the upgrade coordinator;
do not restart individual validators speculatively.

**Verify:** seal 1 adds the five flags in the activation table.

### Startup reports backtrace or smartcard messages

**Symptom:** startup logs show `backtrace parse failed` and
`Smartcard socket not found, disabling`.

**Cause:** `v2.0.49-elemont` tries to parse the empty optional backtrace setting,
and disables optional smartcard-wallet support when the `pcscd` socket is not
installed. Neither message affects a validator that uses its normal keystore
and did not configure `--log.backtrace` or `--backtrace`.

**Correction:** do nothing. Do not add logging flags, install `pcscd`, or change
the launch command during the cutover. If the recorded command explicitly uses
a backtrace flag or the validator intentionally signs through a smartcard, stop
and ask the coordinator before proceeding.

**Verify:** the immediate restart checkpoint passes: the process stays active,
height advances, peers return toward their baseline, and the fixed-height block
hash matches the public RPC.

## See also

- [ELEMONT Upgrade](elemont-upgrade.md) — features, user actions, and breaking changes
- [Connect to Mainnet](connect-to-mainnet.md) — wallet configuration
- [Network Details](../network-details.md) — chain IDs, endpoints, and contracts
- [Become a Validator](../nodes-and-validators/become-a-validator.md) — new validator setup outside the upgrade window
- [Troubleshooting](../nodes-and-validators/troubleshooting.md) — general node recovery
