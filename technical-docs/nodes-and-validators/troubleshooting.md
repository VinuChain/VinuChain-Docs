# Troubleshooting

## Troubleshooting

{% hint style="warning" %}
**Testnet operators running or installing v2.x-elemont**: see the [Chain Upgrade Guide](../vinuchain-testnet/chain-upgrade-guide.md) first. Two failure modes need dedicated recovery steps that the legacy procedures on this page do not cover:

- **Validator offline >1,000 epochs cannot rejoin** → upgrade to v2.0.8-elemont (removes the `validatePeerProgress` drift cap). See [Chain Upgrade Guide → stuck peercount](../vinuchain-testnet/chain-upgrade-guide.md#stuck-at-net-peercount-1-with-one-stale-peer).
- **`WARN Incoming event rejected ... err="wrong event epoch hash"`** → fresh resync from genesis **does not work** on current binary rules. Use the latest post-seal chaindata snapshot at `s3://vinu-blockchain-genesis/chaindata-snapshots/` — see [Chain Upgrade Guide → wrong event epoch hash](../vinuchain-testnet/chain-upgrade-guide.md#warn-incoming-event-rejected-err-wrong-event-epoch-hash) for the recovery procedure.

Latest public post-BLS snapshot: `https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.37-elemont-post-vinubls12381-20260603T080900Z-clean.tar.gz` (published 2026-06-03, tip epoch 5907 / block 1,482,910). SHA256 `f5110088aa8a168a0d0166d522d94734a47856d7bb5b5312c427f05f555ddd59`. Excludes `nodekey` / `keystore/` / `static-nodes.json` so your validator identity is preserved during extraction. It includes `VinuBLS12381: active` and `VinuLatestEVM` still false; once `VinuLatestEVM` seals, use a newer post-latest-EVM snapshot instead.
{% endhint %}

## 1. Supported go-opera version <a href="#id-1.-current-version-of-go-opera" id="id-1.-current-version-of-go-opera"></a>

The current supported version is **go-opera 2.0.37-elemont** for testnet. Mainnet is still on `v2.0.0-rc.1` pending the next coordinated upgrade window. The legacy "1.1.2-rc.3" line that previously appeared here referred to the pre-elemont fork and is no longer current.

### **1.0 Pre-flight checklist** <a href="#id-1.0-pre-flight-checklist" id="id-1.0-pre-flight-checklist"></a>

Before restarting opera — whether after a crash, after a binary swap, or during a planned maintenance window — verify the host has adequate headroom.

* `df -h /home` → **≥ 20 GiB free**. Opera's built-in watchdog gracefully shuts the node down at `available=<8 GiB` to prevent LevelDB corruption. A restart triggers compactions that consume roughly 1.5-2 GiB in the first 2-3 minutes (allocating scratch equal to the compacted tier). If you start with <10 GiB free, you may see `ERROR Low disk space. Gracefully shutting down Vinu to prevent database corruption.` within minutes of startup and have to clean up before retry.
* `free -h` → swap not saturated. Swap thrash makes LevelDB open extremely slow and can tip a borderline-healthy restart into OOM.
* `systemctl is-active vinu-opera.service` → `inactive` or `failed`. Never start a second opera process on a box that already has one running — two opera processes opening the same `datadir/chaindata/leveldb-fsh/` produces `LOCK: permission denied` on the slower loser, and can corrupt the winner if the loser gets partial write through.

Common cleanup targets if you need to free space urgently:

* `truncate -s 0 /var/log/syslog` — can reclaim 10+ GiB on boxes with unbounded syslog growth.
* `journalctl --vacuum-size=200M` — quick journal trim.
* `rm build/logs/opera_public_node.log.{2..7}.gz` — keeps the most recent rotated log as a post-crash artefact, drops the older ones.
* `apt-get clean` — typically 100-500 MiB.

Context: the 2026-04-23 mainnet RPC recovery required exactly this sequence after opera's disk watchdog self-terminated a restarted node at 7.87 GiB free.

### 1.1 Reinstalling Opera

* `pkill opera` _(stop the node)_
* `cd VinuChain`
* `git pull` _(pull the VinuChain directory)_
* `make` _(rebuild the build folder)_
* `sudo rm -rf /home/{user}/.opera/chaindata` _(delete chaindata folder, replace {user})_
* _Sync_ [_Read-Only Node_](read-only-node.md)
* _Start_ [_Validator_](become-a-validator.md)

### **1.3 Resuming an interrupted snapshot download** <a href="#id-1.3-resuming-an-interrupted-snapshot-download" id="id-1.3-resuming-an-interrupted-snapshot-download"></a>

Chaindata snapshots from `s3://vinu-blockchain-genesis/chaindata-snapshots/` are typically ~1 GiB compressed. Long-running downloads over SSM can be cut short by an SSM session timeout (20 min default), CloudFlare connection drop, or a transient instance networking blip. To make the download resumable, always pass `curl -C - -o <file> <url>`:

```
curl -C - -o testnet-chaindata-v2.0.37-elemont-post-vinubls12381-20260603T080900Z-clean.tar.gz \
  https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.37-elemont-post-vinubls12381-20260603T080900Z-clean.tar.gz
```

The `-C -` flag auto-resumes from the byte offset already on disk if the file exists, or starts from zero if it doesn't. Without it, an interrupted `curl` forces a full redownload and wastes the partial bytes.

Verify the checksum after a successful (or resumed) download — the published SHA256 is in the top-of-page hint block.

## 2. Pruning node state <a href="#id-2.-pruning-node-state" id="id-2.-pruning-node-state"></a>

If your node is about to run out of space, you may consider to extend the machine's storage OR to prune the current node's datadir.&#x20;

To prune the `datadir`, please use the following steps:

### **2.1 Manual pruning** <a href="#id-2.1-manual-pruning" id="id-2.1-manual-pruning"></a>

* Stop the node `pkill opera`
* Run at the terminal: `./opera snapshot --db.preset <preset> prune-state`

The state pruning process may take a couple of hours for every hundreds of GBs of data and the amount of time required will depend on the machine's speed. Thus, you can run with `nohup`.

### **2.2 Automatic pruning** <a href="#id-2.2-automatic-pruning" id="id-2.2-automatic-pruning"></a>

You can run a node with `--gcmode` flag, either `--gcmode full` or `--gcmode light`.&#x20;

Note that

* Both `--gcmode full` and `--gcmode light` will prune data that is processed after gcmode is enabled. Old data (before gcmode is enabled) is untouched.
* Validator node can use `--gcmode light` but should not use `--gcmode full`.
* `--gcmode full` option will prune much more EVM nodes than `--gcmode light` at expense of worse performance.

## 3. Validator node <a href="#id-3.-validator-node" id="id-3.-validator-node"></a>

### **3.0 Multi-opera safety** <a href="#id-3.0-multi-opera-safety" id="id-3.0-multi-opera-safety"></a>

The testnet validator box (`i-029476269e84beb4a`) runs four opera processes (V1–V4) simultaneously against a shared on-disk `build/opera` binary. Any operation that affects "opera" on this box must treat the four as **independent processes**, not as one unit.

**Never use `pkill -f opera` or `pkill opera.*vinu-testnet`.** Both kill all four validators at once. With 4-of-4 BFT quorum required for block production, a simultaneous stop halts the testnet. `systemctl stop vinu-validators` internally calls `pkill opera.*vinu-testnet` — **do not use it** for routine restarts.

Correct rolling-restart pattern:

1. `ps -eo pid,cmd | grep 'opera.*vinu-testnet' | grep -v grep` → capture the four PIDs + full argv.
2. For each PID, snapshot argv: `cp /proc/$PID/cmdline /tmp/v$N.cmdline.bin` before signalling. On restart, replay via `readarray -d '' argv < /tmp/v$N.cmdline.bin` so the relaunch is byte-for-byte identical (130-char pubkeys are copy-paste hazardous).
3. `kill -SIGINT $PID` on ONE validator at a time. SIGINT gives opera time for a clean LevelDB close; SIGKILL on an active LevelDB writer corrupts chaindata.
4. Wait ≥ 20 seconds for the process to exit cleanly AND for the other three validators to recover quorum.
5. Relaunch the stopped one via `nohup opera … &` with the snapshotted argv.
6. Verify peer count and tip alignment before touching the next validator.

The same principle applies on the mainnet RPC box (`i-083fffeeb03583a18`): one opera process per host, signalled with SIGINT, never pkill.

### **3.1 How to rerun a node if it is stopped** <a href="#how-to-rerun-a-node-if-it-is-stopped" id="how-to-rerun-a-node-if-it-is-stopped"></a>

If your node is stopped (for some reason), please examine the server log to identify if there was any issue.&#x20;

After fixing the issue (if any), you can run the node in read mode to sync to the latest block. After it is synced up, you can stop the node and run in validator mode.

Please make sure your node is synced in read mode first, before it is run in validator mode.

### **3.2 Migration to a new server** <a href="#migration-to-a-new-server" id="migration-to-a-new-server"></a>

If you'd like to migrate your node to a new server, please follow the following steps:

* Set up a 'read' node on a new server, and allow it to run to sync to the latest block.&#x20;
* Stop the old node in at least 40 mins before run the validator mode on the new server.&#x20;
* After the old node is stopped for 40 mins, then you can run in validator mode on the new server.&#x20;

Note that, you should not let the old node run again as it will result in a double-sign and slashing of your validator node.

### **3.3 How to stop a node** <a href="#how-to-stop-a-node" id="how-to-stop-a-node"></a>

Find the running process of opera using `ps`, and then `kill` the process by id.

Note that, after your node is stopped, if you want to rerun it again, don't run directly in validator mode. Instead, please make sure your node is synced in read mode first, before it is run in validator mode.

### **3.4 Offline node** <a href="#offline-node" id="offline-node"></a>

If your validator node is down for more than **5 days**, then it will become offline (i.e., pruned from the network).&#x20;

For an offline node, you can [undelegate](delegation-calls.md) and wait for **3 days** to withdraw (bonding time). After that, you can transfer funds to a new wallet and make a new validator if you wish.&#x20;

Note that, if [undelegating](delegation-calls.md) a locked stake or locked delegation before the locked period is expired, it will incur a penalty.

<figure><img src="../../.gitbook/assets/image (2).png" alt="" width="375"><figcaption><p>Validator Withdrawal Times</p></figcaption></figure>

### **3.5 How to permanently shut down a node** <a href="#how-to-permanently-shut-down-a-node" id="how-to-permanently-shut-down-a-node"></a>

To shutdown a node permanently, you can simply stop running the node in validator mode for 5 days or more. After that, it will become Offline.

### **3.6 How to unstake / withdraw** <a href="#how-to-unstake" id="how-to-unstake"></a>

If your node stake is locked, you will first need to call [unlockStake()](lockup-calls.md) to unlock it.

* A penalty will apply for early unlocking before lockup is expired. &#x20;

Then you can call [undelegate()](delegation-calls.md), to unstake your stake.

Then there is a **waiting period of 3 days** (so-called bonding time) after undelegation. This is required before you can call [withdraw()](delegation-calls.md) to take out your stake.

<figure><img src="../../.gitbook/assets/image (1).png" alt="" width="375"><figcaption><p>Withdrawal Times</p></figcaption></figure>

## 4. Troubleshooting  <a href="#id-4.-troubleshooting" id="id-4.-troubleshooting"></a>

### **4.1 Syncing error** <a href="#id-4.1-syncing-error" id="id-4.1-syncing-error"></a>

If your node is in dirty state (it may happen occasionally), please run:&#x20;

`opera --db.preset legacy-ldb db heal --experimental`&#x20;

alternatively, you may do a fresh resync as follows:

* Stop the node
* Remove the current (broken) datadir (the default datadir is located at \~/.opera)
* Download and build go-opera 1.1.2-rc3
* Run your node again in read mode

### **4.2 Slow syncing** <a href="#id-4.2-slow-syncing" id="id-4.2-slow-syncing"></a>

Check your machine specs if it meets the minimum requirements.

* IOPS greater than 5000 (higher is better)
* connection speed > 1 Gbps (some ppl run with 10 or 20, if they can)
* cores: more than 4 cores (the number of cores is not important unless you will use it for serving API calls).
* CPU: > 3GHz.

You can also check the following flags, if you're using them to run your node. You can adjust to values suitable to your usage.

* maxpeers flag: default is 50, you can adjust it depending on your machine.
* cache flag: --cache 15792 (A larger value can give better performance).
* gcmode: gcmode is not enabled by default. If enabled, gcmode (light or full) it will take some extra CPU and time.

You can also increase the value of `ulimit` on your machine.

## **5. Increase open files limit** <a href="#increase-open-files-limit" id="increase-open-files-limit"></a>

You can check your current limit value on Linux with the command `ulimit -n`.&#x20;

The default value of 1024, which may be not enough in some cases.You can adjust the value to the recommended 500.000 open files limit by either:&#x20;

* `ulimit -n 500000`&#x20;
* change it in `/etc/security/limits.conf` configuration file, limit type nofile.

## 6. Delegated stake stuck on a non-rewarding validator

If your delegation to a particular validator returns "zero rewards" on `claimRewards` and `restakeRewards`, AND `undelegate` reverts with `"not enough unlocked stake"` even though you can see your stake on-chain, the validator you delegated to may have been admitted with a malformed pubkey before the canonical-pubkey enforcement landed in `v2.0.14-elemont`. A validator with a non-`0xc0`-prefixed pubkey produces no consensus-verifiable events, earns zero uptime, and never accumulates rewards-per-token, so any stake delegated to it is permanently stuck until you unwind it manually.

### How to confirm

Read the validator's pubkey from the SFC contract (replace `<VID>` with the validator ID you delegated to):

```javascript
sfcc.getValidatorPubkey(<VID>)
```

A canonical pubkey is **66 bytes / 134 hex characters** and starts with `0xc004…`. Anything shorter (especially 65 bytes / 132 hex characters starting with `0x04…`) is malformed.

You can also confirm by reading `getEpochAccumulatedRewardPerToken(epoch, <VID>)` for several recent epochs — a malformed validator returns `0` at every epoch, while a healthy validator's value strictly increases.

### How to recover (zero penalty, but in three phases)

`unlockStake` cannot be called directly on a stuck delegation — it reverts with `"claim rewards blocked by corruption; wait for epoch correction"`. The revert comes from a per-delegator reward-stashing cursor (`stashedRewardsUntilEpoch[delegator][validatorID]`) that advances by **at most 100 epochs per call** to any function that triggers `_stashRewards`. For a delegator on a long-active malformed validator, the cursor lags `currentSealedEpoch` by hundreds or thousands of epochs, and `unlockStake`'s guard refuses the call until the cursor is fully caught up.

The fix is to call `delegate(<VID>)` repeatedly with a tiny `msg.value` until the cursor catches up, then unlock and withdraw.

#### Phase 1 — advance the cursor to currentSealedEpoch

`delegate(<VID>)` calls `_rawDelegate`, which calls `_stashRewards`, which advances the cursor by up to 100 epochs per invocation. The minimum delegation amount is **0.01 VC** (`minDelegation()`). Calculate how many calls you need:

```javascript
const sealed = await sfcc.currentSealedEpoch()
const cursor = await sfcc.stashedRewardsUntilEpoch(yourAddress, <VID>)
const calls  = Math.ceil((sealed - cursor) / 100)
console.log(`need ${calls} delegate calls of 0.01 VC each (= ${calls * 0.01} VC + gas)`)
```

Issue them in a loop:

```javascript
const tinyAmount = web3.toWei("0.01", "vc")
for (let i = 0; i < calls; i++) {
  await sfcc.delegate(<VID>, { from: yourAddress, value: tinyAmount })
}
```

Each call costs 0.01 VC of stake (added to `getStake[yourAddress][<VID>]` as **unlocked** stake) plus normal gas. After the loop, `stashedRewardsUntilEpoch == currentSealedEpoch` and the corruption guard in `unlockStake` will pass.

#### Phase 2 — unlock the locked stake (zero penalty)

```javascript
sfcc.unlockStake(<VID>, <originalLockedAmount>)
```

Because the malformed validator never accumulates rewards, `getStashedLockupRewards` is `(0, 0, 0)` and the early-unlock penalty math at `_popDelegationUnlockPenalty` evaluates to `lockupExtraRewardShare + lockupBaseRewardShare / 2 = 0 + 0 / 2 = 0`. `unlockStake` imposes **zero penalty**; the full locked amount becomes unlocked stake. Verify before calling:

```javascript
const stash = await sfcc.getStashedLockupRewards(yourAddress, <VID>)
// stash should be [0, 0, 0]
```

If any value is non-zero, the validator was rewarding for some span of its lifetime and the penalty is non-zero — simulate the unlock through a tracer (`debug_traceCall`) before sending it on-chain.

#### Phase 3 — undelegate and withdraw

```javascript
// Undelegate everything (the original locked amount + the 0.01 VC * calls
// you added during phase 1, all of which are now unlocked).
const total = (await sfcc.getStake(yourAddress, <VID>))
sfcc.undelegate(<VID>, total)
// Note the wrID emitted by Undelegated(delegator, <VID>, wrID, total).

// Wait at least 6 epochs AND 1 day, then withdraw:
sfcc.withdraw(<VID>, <wrID>)
```

You receive the full delegation back to your wallet at `withdraw`. No fees beyond gas.

### Why this dance is necessary

The reward-stashing cursor is bounded by `MAX_CORRUPTION_CHECK_EPOCHS = 100` per call to limit gas. The cursor was designed to keep a per-delegator scan of `accumulatedRewardPerToken[validatorID]` monotonic so a downward "rate inversion" cannot mint phantom rewards — but the same scan also has to walk forward through quiet (zero-reward) epochs to update the cursor, even when there's nothing to stash. The public `stashRewards()` helper specifically reverts on `"nothing to stash"`, and `claimRewards` / `restakeRewards` revert on `"zero rewards"`, so neither lets you advance the cursor on a zero-rewards validator. `delegate` is the only public path that calls `_stashRewards` without a `rewards != 0` precondition.

### Future prevention

`v2.0.14-elemont` (testnet) / Cycle-161 SFC bytecode rejects malformed pubkeys at `createValidator` ingress, so this condition cannot recur for new admissions. The `ElemontPubkeyValidation` upgrade flag also ejects already-admitted malformed validators from the active set at the next epoch seal. See [Become a Validator](become-a-validator.md#register-your-validator) and [Validator Calls → Create validator](validator-calls.md#create-validator) for the canonical pubkey format requirements.
