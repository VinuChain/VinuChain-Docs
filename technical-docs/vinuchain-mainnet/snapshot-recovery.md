# Recovering a Node That Missed the ELEMONT Upgrade

This guide is for mainnet nodes that did **not** upgrade during the 2026-08-29
activation window and can no longer follow the chain.

Mainnet activated `SfcV2`, `Elemont`, `ElemontPubkeyValidation`, `Shanghai` and
`PaybackV2` at the epoch seal on **2026-08-29 13:38:26 UTC** (block `14,701,167`),
then `Cancun`, `Prague`, `VinuBLS12381` and `VinuLatestEVM` across four further seals,
finishing **2026-08-30 05:38:56 UTC**. A node that was not running
`v2.0.49-elemont` when its epoch sealed computed a different result and is now on a
chain the network rejects.

## Do you need this guide?

You need it if **any** of these are true:

- your logs repeat `wrong event epoch hash`;
- `eth_currentEpoch` on your node is behind the public RPC and not catching up;
- `eth_getCode` for the SFC on your node is **not** 48,757 bytes;
- your node ran an older binary through the 2026-08-29 window.

Check quickly:

```bash
# your node
<OPERA> attach --exec 'vc.currentEpoch()' <YOUR_IPC>
# the network
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_currentEpoch","params":[],"id":1}'
```

If the two match and your node is advancing, you do **not** need this guide — just
upgrade the binary normally per the
[Mainnet Upgrade Guide](chain-upgrade-guide.md).

---

## ⚠️ Read this before you touch anything

**If your validator emitted events on the diverged chain, restoring a snapshot and
validating again in the same epoch can produce a doublesign — and a doublesign
permanently deactivates your validator.**

A doublesign is two differently-signed events from your key at the same epoch and
sequence number. After restoring, your node's event history is replaced by the
network's; if it then emits at sequence numbers it already used on the fork, both
versions exist and are provable.

This guide avoids that by having you **re-sync with validation switched off first**,
and only re-enable validation once your node is demonstrably on the canonical chain in
a **later** epoch than the one you diverged in.

Do not skip that. Losing a few hours of rewards is recoverable. A deactivated
validator is not.

Before starting, note the last event your node emitted:

```bash
grep "New event emitted" <your opera log> | tail -1
```

Record the epoch and sequence — e.g. `7888:29`. You will confirm the chain has moved
past that epoch before validating again.

---

## What you keep and what you replace

The published snapshot is deliberately **identity-free**. It contains chain data only.

| Keep — these are yours, never in the snapshot | Replace from the snapshot |
|---|---|
| `keystore/` (your validator's consensus key) | `chaindata/` |
| `go-opera/nodekey` (your node's network identity) | the rest of the datadir |
| `validator.env` / your `--validator.*` flags | |
| your password file | |

**Back these up off the machine before you begin.** If you lose `keystore/`, your
validator cannot be recovered by anyone.

---

## Step 1 — Stop the node cleanly

```bash
sudo systemctl stop <your-service>       # or: pkill -INT -x opera
```

**Never `SIGKILL` (`kill -9`) opera.** A hard kill corrupts LevelDB and turns this into
a multi-day resync. Wait for the process to exit on its own; give it up to 2 minutes.

```bash
pidof opera || echo "stopped"
```

## Step 2 — Back up your identity

```bash
DD=<your datadir>
mkdir -p ~/vinu-identity-backup
cp -a "$DD/keystore"          ~/vinu-identity-backup/ 2>/dev/null
cp -a "$DD/go-opera/nodekey"  ~/vinu-identity-backup/ 2>/dev/null
cp -a <your validator.env / password file> ~/vinu-identity-backup/ 2>/dev/null
ls -la ~/vinu-identity-backup
```

Copy that directory somewhere off the machine as well.

## Step 3 — Install `v2.0.49-elemont`

If you have not already:

```bash
curl -fsSLO https://github.com/VinuChain/VinuChain/releases/download/v2.0.49-elemont/opera-v2.0.49-elemont-linux-amd64
sha256sum opera-v2.0.49-elemont-linux-amd64
# must be: 678040e9f88a98331a8cc32b7bf5b9e0ae4acdf84919390465eeee584b7f56c1
chmod +x opera-v2.0.49-elemont-linux-amd64
./opera-v2.0.49-elemont-linux-amd64 version     # must print 2.0.49-elemont
```

Requires x86-64 Linux with glibc `2.34` or newer.

## Step 4 — Download and verify the snapshot

**Do not extract an unverified archive over your datadir.**

```bash
BASE=https://vinu-blockchain-mainnet-genesis.s3.amazonaws.com/chaindata-snapshots/elemont-20260829/seal-5
F=mainnet-chaindata-elemont-seal5-20260830T103737Z.tar.zst

curl -fL -O "$BASE/$F"
curl -fL -O "$BASE/$F.sha256"
sha256sum -c "$F.sha256"        # must print: OK
```

| | |
|---|---|
| Size | `75,284,772,274` bytes (70.1 GiB compressed) |
| sha256 | `969fb6acc86f1cfbc29ceed77224c25046f410c6e78726d5078c04a07afd7b31` |
| Taken at | epoch `7894`, block `14,709,230` — after all five seals |
| Client | `v2.0.49-elemont` |

You need roughly **180 GB free**: ~70 GB for the archive plus ~110 GB extracted.

## Step 5 — Replace the chain data

Move the old datadir aside rather than deleting it, until you are sure recovery worked.

```bash
DD=<your datadir>                       # e.g. /home/ubuntu/.opera
mv "$DD" "${DD}.diverged.$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$(dirname "$DD")"
tar -I zstd -xf "$F" -C "$(dirname "$DD")"
```

The archive expands to a `datadir/` directory. Rename or move it so it matches the path
your launch command expects:

```bash
ls "$(dirname "$DD")"                   # you should see: datadir
mv "$(dirname "$DD")/datadir" "$DD"     # only if your datadir has a different name
du -sh "$DD"                            # expect ~110 GB
```

## Step 6 — Put your identity back

```bash
cp -a ~/vinu-identity-backup/keystore  "$DD/"
mkdir -p "$DD/go-opera"
cp -a ~/vinu-identity-backup/nodekey   "$DD/go-opera/"
chown -R "$(id -un):$(id -gn)" "$DD"
chmod 600 "$DD/go-opera/nodekey"
```

## Step 7 — Start **without** validator flags

This is the step that protects you. Start as a plain syncing node — **no
`--validator.id`, no `--validator.pubkey`, no `--validator.password`.** A node with no
identity cannot doublesign.

```bash
./opera \
  --port 3000 \
  --nat "extip:<YOUR_PUBLIC_IP>" \
  --bootnodes "enode://678f242c2d60ed433c23bba0f9ea00982ea9bc5eb1d7f91337c23ccec5f41c9634705fa79994ba8f62ee893574451631a10f694cfa684f75524de79a7e50f890@54.244.138.80:3000,enode://e0d777bf4ef6318a748ffbd2c58d3b664f5132a02d711567a6df378504c49edbc3145b8f0105ea100988bd1bb57ac574a783d255b2b57abd65a5f0ae13954e77@35.161.54.139:3000,enode://0281626c7d7fc8696300688cbb19f3781aabd981d74cd16f3f5cd7885a32da4d1d9d64afbb2416b93654935a3088afbe1a4a05d823ff2146e5d1d0c2cbdeca46@188.165.195.122:3000" \
  --verbosity=3
```

Keep every other flag exactly as it was — same datadir, same ports.

## Step 8 — Confirm you are on the canonical chain

All four must hold before you go further.

```bash
# 1. no divergence errors
grep -c "wrong event epoch hash" <your log>          # expect: 0

# 2. your epoch matches the network
<OPERA> attach --exec 'vc.currentEpoch()' <YOUR_IPC>
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_currentEpoch","params":[],"id":1}'

# 3. the SFC matches
<OPERA> attach --exec 'vc.getCode("0xFC00FACE00000000000000000000000000000000").length' <YOUR_IPC>
#    hex string length 97516  ==  48,757 bytes

# 4. same block hash as the public RPC at a fixed height
```

If `wrong event epoch hash` still appears, **stop and ask before continuing** — do not
re-enable validation.

## Step 9 — Re-enable validation

Only once step 8 passes **and** the network's current epoch is **later than the epoch
you diverged in** (the one you recorded at the start).

Stop the node cleanly, add your `--validator.*` flags back, and start it again.

Expect roughly five minutes of:

```text
Emitting is paused    reason="waiting additional time"
```

That is deliberate doublesign protection. **Do not restart again inside that window.**
It clears on its own, then your validator resumes emitting.

Confirm you are live:

```bash
grep "New event emitted" <your log> | tail -3      # should show by=<your validator id>
```

Your validator ID, stake and delegations are unchanged throughout — you are resuming an
existing validator, not creating a new one.

---

## If it goes wrong

| Symptom | What it means | Do |
|---|---|---|
| `wrong event epoch hash` persists after restore | datadir did not actually get replaced, or the wrong path was extracted | Re-check step 5; confirm `du -sh` shows ~110 GB and the SFC is 48,757 bytes |
| `Bootstrap URL invalid … no such host` | a stale bootnode hostname in your launch command | Use the three enodes in step 7 |
| Node starts but finds no peers | discovery has not populated | Add a `static-nodes.json` in `<datadir>/go-opera/` listing the same three enodes |
| `sha256sum -c` fails | truncated or corrupted download | Delete and re-download; do not extract it |

Keep `${DD}.diverged.*` until your validator has been emitting normally for at least a
full epoch. Then remove it to reclaim disk.

## Getting help

Bring these when you ask:

- `opera version` output
- your node's `vc.currentEpoch` vs the public RPC's
- the count of `wrong event epoch hash` in your log
- the last `New event emitted` line before you started recovery
