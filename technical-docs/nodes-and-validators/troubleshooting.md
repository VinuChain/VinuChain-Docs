# Troubleshooting

## Troubleshooting

{% hint style="warning" %}
**Testnet operators running or installing v2.x-elemont**: see the [Chain Upgrade Guide](../vinuchain-testnet/chain-upgrade-guide.md) first. Two failure modes need dedicated recovery steps that the legacy procedures on this page do not cover:

- **Validator offline >1,000 epochs cannot rejoin** → upgrade to v2.0.8-elemont (removes the `validatePeerProgress` drift cap). See [Chain Upgrade Guide → stuck peercount](../vinuchain-testnet/chain-upgrade-guide.md#stuck-at-net-peercount-1-with-one-stale-peer).
- **`WARN Incoming event rejected ... err="wrong event epoch hash"`** → resync from a **stale** genesis (the 2024-06-21 / 2026-04-19 files) **does not work** on current binary rules. Use the latest post-seal chaindata snapshot at `s3://vinu-blockchain-genesis/chaindata-snapshots/` — see [Chain Upgrade Guide → wrong event epoch hash](../vinuchain-testnet/chain-upgrade-guide.md#warn-incoming-event-rejected-err-wrong-event-epoch-hash) for the recovery procedure — or bootstrap a fresh datadir from the regenerated 2026-07-11 genesis (see the Chain Upgrade Guide's *Fresh install?* note).

Latest public snapshot: `https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.46-elemont-20260717T055748Z-clean.tar.gz` (published 2026-07-17, tip block 1,541,394 / epoch 6170). SHA256 `ff52058d5f2f6a61972cfd5a5bd6fcd1db63dd9c2a3b229573140d173fbeac4a`. Excludes `nodekey` / `keystore/` / `static-nodes.json` so your validator identity is preserved during extraction. It includes `VinuBLS12381`, `VinuLatestEVM`, and `SfcV2Patch7`/`SfcV2Patch8`/`SfcV2Patch9` all active.
{% endhint %}

## 1. Supported go-opera version <a href="#id-1.-current-version-of-go-opera" id="id-1.-current-version-of-go-opera"></a>

The current node release is **v2.0.44-elemont** for testnet (mainnet runs the ELEMONT feature set on the latest mainnet-compatible build). Build it from the `v2.0.44-elemont` tag with Go 1.25+ (see [Read-Only Node](read-only-node.md)).

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
curl -C - -o testnet-chaindata-v2.0.46-elemont-20260717T055748Z-clean.tar.gz \
  https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.46-elemont-20260717T055748Z-clean.tar.gz
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

The testnet validator box runs four opera processes (V1–V4) simultaneously against a shared on-disk `build/opera` binary. Any operation that affects "opera" on this box must treat the four as **independent processes**, not as one unit.

**Never use `pkill -f opera` or `pkill opera.*vinu-testnet`.** Both kill all four validators at once. With 4-of-4 BFT quorum required for block production, a simultaneous stop halts the testnet. `systemctl stop vinu-validators` internally calls `pkill opera.*vinu-testnet` — **do not use it** for routine restarts.

Correct rolling-restart pattern:

1. `ps -eo pid,cmd | grep 'opera.*vinu-testnet' | grep -v grep` → capture the four PIDs + full argv.
2. For each PID, snapshot argv: `cp /proc/$PID/cmdline /tmp/v$N.cmdline.bin` before signalling. On restart, replay via `readarray -d '' argv < /tmp/v$N.cmdline.bin` so the relaunch is byte-for-byte identical (130-char pubkeys are copy-paste hazardous).
3. `kill -SIGINT $PID` on ONE validator at a time. SIGINT gives opera time for a clean LevelDB close; SIGKILL on an active LevelDB writer corrupts chaindata.
4. Wait ≥ 20 seconds for the process to exit cleanly AND for the other three validators to recover quorum.
5. Relaunch the stopped one via `nohup opera … &` with the snapshotted argv.
6. Verify peer count and tip alignment before touching the next validator.

The same principle applies on the mainnet RPC box: one opera process per host, signalled with SIGINT, never pkill.

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

If your validator node stays down long enough to cross the SFC offline-penalty threshold — **more than 7,200 missed blocks _and_ at least ~5 days offline** (both conditions must be met) — the SFC deactivates it and drops it from the active validator set. Whether you can get that exact validator back depends on the network and the reason for deactivation (see [§8.5](#id-8-5)): on **testnet** an offline-deactivated validator can be reactivated in place by the SFC owner, but a **slashed** (double-sign) validator cannot, and **mainnet** has no reactivation path at all.&#x20;

{% hint style="success" %}
**Came back before the threshold tripped?** On testnet you can revive the **same** validator (same validator ID and stake) instead of recreating it — even if the node fell thousands of blocks/epochs behind. See [§8 Reviving a dead or long-offline validator (testnet)](#id-8.-reviving-a-dead-or-long-offline-validator-testnet). If the SFC has **already** deactivated it, [§8.5](#id-8-5) covers the reactivate-vs-recreate decision; the undelegate/withdraw/recreate steps below are the path when reactivation isn't possible.
{% endhint %}

For an offline node, you can [undelegate](delegation-calls.md) and wait the validator self-stake withdrawal period — **180 epochs and 3 days** (both must elapse) — before you can withdraw. After that, you can transfer funds to a new wallet and make a new validator if you wish.&#x20;

Note that, if [undelegating](delegation-calls.md) a locked stake or locked delegation before the locked period is expired, it will incur a penalty.

<figure><img src="../../.gitbook/assets/image (2).png" alt="" width="375"><figcaption><p>Validator Withdrawal Times</p></figcaption></figure>

### **3.5 How to permanently shut down a node** <a href="#how-to-permanently-shut-down-a-node" id="how-to-permanently-shut-down-a-node"></a>

To shutdown a node permanently, you can simply stop running the node in validator mode for 5 days or more. After that, it will become Offline.

### **3.6 How to unstake / withdraw** <a href="#how-to-unstake" id="how-to-unstake"></a>

If your node stake is locked, you will first need to call [unlockStake()](lockup-calls.md) to unlock it.

* A penalty will apply for early unlocking before lockup is expired. &#x20;

Then you can call [undelegate()](delegation-calls.md), to unstake your stake.

Then there is a validator self-stake bonding period — **180 epochs and 3 days** (both must elapse) — after undelegation. This is required before you can call [withdraw()](delegation-calls.md) to take out your stake.

<figure><img src="../../.gitbook/assets/image (1).png" alt="" width="375"><figcaption><p>Withdrawal Times</p></figcaption></figure>

## 4. Troubleshooting  <a href="#id-4.-troubleshooting" id="id-4.-troubleshooting"></a>

### **4.1 Syncing error** <a href="#id-4.1-syncing-error" id="id-4.1-syncing-error"></a>

If your node is in dirty state (it may happen occasionally), do a fresh resync as follows:

* Stop the node
* Remove the current (broken) datadir (the default datadir is located at \~/.opera)
* Rebuild the current binary: `git clone https://github.com/VinuChain/VinuChain.git && cd VinuChain && git checkout v2.0.44-elemont && make opera` (requires Go 1.25+)
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

The default value of 1024 may not be enough in some cases. You can adjust the value to the recommended 500,000 open files limit by either:&#x20;

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

The current SFC bytecode rejects malformed pubkeys at `createValidator` ingress, so this condition cannot recur for new admissions. The `ElemontPubkeyValidation` upgrade flag also ejects already-admitted malformed validators from the active set at the next epoch seal. See [Become a Validator](become-a-validator.md#register-your-validator) and [Validator Calls → Create validator](validator-calls.md#create-validator) for the canonical pubkey format requirements.

## 7. Pending rewards shown, but Claim / Restake fails with "zero rewards"

If your staking page shows a **non-zero pending rewards** balance for a validator, but `claimRewards` and `restakeRewards` revert with `"zero rewards"`, your delegation's reward cursor is stuck. This issue was **resolved in v2.0.41-elemont (deployed 2026-06-21)**: the `_rawDelegate` cursor-init fix prevents new first-delegations from stranding rewards, and a one-shot migration corrected the 12 known stuck delegator cursors at the `SfcV2Patch7` activation (block 1,508,211). Claims and restakes for those delegators now succeed.

This is different from [§6](#6-delegated-stake-stuck-on-a-non-rewarding-validator): in §6 the validator genuinely never earned rewards, so the pending-rewards figure is zero. Here the validator **is** healthy and earning, the pending-rewards **view** over-reports a non-zero figure, and the claim path reverts because the cursor lags behind.

### How to confirm

* Your staking page (or `pendingRewards(yourAddress, <VID>)`) shows a non-zero amount.
* `claimRewards(<VID>)` and `restakeRewards(<VID>)` both revert with `"zero rewards"`.
* The validator is otherwise healthy — it has a canonical `0xc0…` pubkey (66 bytes) and `getEpochAccumulatedRewardPerToken(epoch, <VID>)` strictly increases over recent epochs (i.e. it is **not** the malformed-validator case in §6).

### What to do — and what NOT to do

* **Do NOT** attempt repeated `delegate` / `undelegate` calls to try to force the cursor forward. Unlike the §6 procedure, walking the cursor by hand on a **rewarding** validator can mint more than you are actually owed, so this path is unsafe here and must not be used.
* If you were one of the 12 affected delegators: your cursor was corrected at block 1,508,211 — **retry Claim or Restake now**. It should succeed.
* If you **still** see this symptom after the fix:
  * **Check your node/RPC is past block 1,508,211 and running v2.0.44-elemont.** A non-upgraded node diverges with `wrong event epoch hash` and shows stale state — upgrade and re-sync from the [current snapshot](../vinuchain-testnet/chain-upgrade-guide.md).
  * If your node is current and the revert persists, your delegation may be a newly surfaced case that was not among the 12 corrected by the migration. **Report it through the official VinuChain channels** — the permanent cursor-init fix prevents brand-new delegations from getting stuck, but the team can apply a targeted correction if a pre-existing delegation was missed.

## 8. Reviving a dead or long-offline validator (testnet) <a href="#id-8.-reviving-a-dead-or-long-offline-validator-testnet" id="id-8.-reviving-a-dead-or-long-offline-validator-testnet"></a>

If your validator has been down, or fell so far behind that it can no longer catch up — the classic "dead validator" — you can in most cases bring **the same validator** (same validator ID, same stake) back to life on the public testnet (chain 206). If it is still active on-chain you do this entirely yourself ([8.4](#id-8-4)); if the SFC has already offline-deactivated it, testnet's SFC — unlike mainnet's — lets **you reactivate it yourself** in place ([8.5](#id-8-5)). This section is the end-to-end runbook.

{% hint style="warning" %}
**There is a hard deadline.** Two separate clocks decide whether you revive in place or have to start over:

1. **The node re-sync clock** — a node that has been offline a long time used to be permanently locked out of re-peering. That limit was removed in `v2.0.8-elemont` (see [8.2](#id-8-2)), so on a current binary a stale node can always re-peer and sync forward, no matter how far behind.
2. **The on-chain SFC offline clock.** The SFC deactivates an offline validator once it has missed **more than `offlinePenaltyThresholdBlocksNum` (7,200 blocks) _and_ been offline for at least `offlinePenaltyThresholdTime` (~5 days)** — _both_ conditions must hold. Until that trips, your validator keeps `status = 0` and you revive it entirely yourself ([8.4](#id-8-4)). After it trips it leaves the active set: on **testnet** you can call `reactivateValidator(<VID>)` yourself (from the validator `auth` key, offline-only, after an anti-flap cooldown) to restore the **same** ID and stake, whereas **mainnet's SFC has no reactivation at all**, and a double-sign/slashed validator cannot be reactivated on either chain — those cases need a fresh validator (see [8.5](#id-8-5)).
{% endhint %}

### 8.1 First, check your on-chain status <a href="#id-8-1" id="id-8-1"></a>

The deciding fact is the SFC's view of your validator, not the state of your box. Attach to any synced node's Opera console and initialise the `sfcc` object exactly as in [Become a Validator → Initialize SFC](become-a-validator.md#initialize-sfc), then read (replace `<VID>` with your validator ID):

```javascript
sfcc.getValidator(<VID>)
// returns (status, deactivatedTime, deactivatedEpoch, receivedStake, createdEpoch, createdTime, auth)
```

- **`status == 0` and `deactivatedEpoch == 0`** → your validator is still **active**. Proceed with [8.4](#id-8-4) — you keep your ID and stake.
- **`status != 0`, or a non-zero `deactivatedEpoch` / `deactivatedTime`** → the SFC has already **deactivated** your validator. Check **why** with `sfcc.isSlashed(<VID>)` and the status bits (`8` = offline, `128` = double-sign / cheater, `1` = withdrawn). Skip to [8.5](#id-8-5); the node-level steps alone cannot put a deactivated validator back into the set, and whether it can be reactivated at all depends on the reason and the network.

Confirm your stake is still committed (a fully undelegated/withdrawn self-stake is terminal):

```javascript
sfcc.getSelfStake(<VID>)   // must still be >= sfcc.minSelfStake()
```

### 8.2 Why a long-dead node can rejoin at all <a href="#id-8-2" id="id-8-2"></a>

Earlier testnet binaries (`v1.0.0-elemont` … `v2.0.7-elemont`) carried a peer-progress sanity check that rejected any peer reporting progress **more than 1,000 epochs or 5,000 blocks ahead** of the local head. A validator offline long enough to fall past those bounds therefore rejected **every** current-tip peer on the handshake and could never catch up. The fingerprint, seen on the healthy (tip-side) peer, is a ~30-second churn loop:

```text
Adding p2p peer    conn=inbound ...
Removing p2p peer  req=true err="subprotocol error"     (~175 ms later)
```

— while the stale node itself sits at `net.peerCount == 0/1` and never advances its head.

`v2.0.8-elemont` removed those drift caps (`validatePeerProgress` now only rejects a structurally invalid zero-epoch progress), so a node re-peers with the tip regardless of how far behind it is — the deeper acceptance checks still gate actual state changes on epoch equality, so this is safe. **You must therefore be on `v2.0.8-elemont` or later to revive a long-dead validator; use the current release `v2.0.44-elemont`.** If you still see the `subprotocol error` churn above, you are on a pre-`v2.0.8` binary and must upgrade first.

{% hint style="info" %}
**Scope.** External validators run on the **public testnet**, and this runbook is written for testnet operators on the `v2.x-elemont` binary line — the drift-cap regression and its fix were confined to that lineage. The on-chain offline-deactivation behaviour in [8.1](#id-8-1) / [8.5](#id-8-5) is enforced by the SFC contract itself and is independent of the node binary.
{% endhint %}

### 8.3 Step 0 — double-sign safety (do this first) <a href="#id-8-3" id="id-8-3"></a>

{% hint style="danger" %}
**Never run two copies of the same validator key.** If a second process signs consensus events with your validator key while the first is (or comes back) online, you double-sign — which is slashed and **permanently** deactivates the validator. Before starting the revived node, make sure no other instance of this validator is running anywhere. If you are reviving on a **new** host, stop the old node and wait **at least 40 minutes** before starting validator mode on the new host (see [§3.2 Migration to a new server](#migration-to-a-new-server)).
{% endhint %}

### 8.4 Revival procedure <a href="#id-8-4" id="id-8-4"></a>

{% stepper %}
{% step %}

#### Upgrade to the current binary

Build and verify the current release tag, following [Chain Upgrade Guide → Download and build](../vinuchain-testnet/chain-upgrade-guide.md#download-and-build-the-new-binary):

```bash
git clone https://github.com/VinuChain/VinuChain.git $HOME/vinuchain-upgrade
cd $HOME/vinuchain-upgrade && git checkout v2.0.44-elemont && make opera
./build/opera version   # Expected: Version: 2.0.44-elemont
```

Anything `>= v2.0.8-elemont` clears the drift-cap lockout; `v2.0.44-elemont` is the current consensus release and the version your chaindata must match.
{% endstep %}

{% step %}

#### Restore chain state

- **Datadir intact and not past a missed consensus seal** → just restart in read mode; with the drift caps gone it peers with the tip and syncs forward on its own.
- **Long-dead, corrupted, or stale across a fork seal** → a stale datadir replays historical forks under the wrong rules and halts with `WARN Incoming event rejected ... err="wrong event epoch hash"`. Restore from the latest chaindata snapshot per [Chain Upgrade Guide → wrong event epoch hash](../vinuchain-testnet/chain-upgrade-guide.md#warn-incoming-event-rejected-err-wrong-event-epoch-hash). For any validator dead more than a few hours this is the reliable path.

{% hint style="warning" %}
**Preserve your identity files.** Back up `<datadir>/keystore/` and `<datadir>/go-opera/nodekey` before deleting any chaindata. The published snapshots deliberately exclude `nodekey`, `keystore/`, `static-nodes.json`, and `trusted-nodes.json`, so extracting one over your datadir keeps your validator identity intact. **Do not resync from a stale genesis on testnet** (the 2024-06-21 / 2026-04-19 files) — it stages not-yet-sealed forks at the wrong heights and diverges immediately. The regenerated 2026-07-11 genesis (all activations sealed in its history) is the exception and may be used to bootstrap a fresh datadir — see the [Chain Upgrade Guide's *Fresh install?* note](../vinuchain-testnet/chain-upgrade-guide.md).
{% endhint %}
{% endstep %}

{% step %}

#### Bring it up as a read node and confirm it re-peers

Start **without** the validator flags first and let it catch up. `--nat extip` is effectively required — without it your node advertises `127.0.0.1` and stalls at `net.peerCount == 1` (see [Stuck at net.peerCount == 1](../vinuchain-testnet/chain-upgrade-guide.md#stuck-at-net-peercount-1-with-one-stale-peer)):

```bash
cd $HOME/vinuchain-upgrade/build
nohup ./opera \
  --bootnodes "enode://e2a95c1b8d85b018b8e88133bec342801b42e19b59a52e030462d04a5549f02fc57215b4ca97771ec6b3a0d30a78603fdccd2b5091c44f6ac439d6c8be8bc539@44.239.129.39:3000,enode://7a45d086b9c82bd3677a76d36e003b9490066d56b612f33d05cb4d242212acd4e5cab4abbcb15a0df9aa499e41b4b4e868d82ba1c509c1990c9217dfe4607775@44.239.129.39:3001,enode://d8e37eeba79b2c52dcba6e396ff907f27a6a8f7db34528cb8636bc3271291657a01c5649bff53429cea8a23b03fac13a178813c34c6d17d14f7b810a988393b5@44.239.129.39:3002,enode://3f15b5ac22dea3e37a90cd9378cf0cd4ed9ea122851846c8108fcc7d2c7e709ea4a089cf3da93c0d3d3053250417cf0ea9ad9eff0aa77ff07d76b6cf267a2937@44.239.129.39:3003" \
  --nat extip:<your_public_ipv4> \
  --datadir <datadir> \
  > sync.log &
echo $! > opera.pid    # record THIS read node's PID for a targeted stop in step 4
```

`<datadir>` is the directory you restored the snapshot into in the previous step — the one holding your preserved `keystore/` and `go-opera/nodekey`. **Omit `--datadir` only if that directory is the default `~/.opera`**; otherwise the node will boot the wrong (default) database and fail to find your validator identity.

Verify catch-up — attach with `./opera attach` (or `./opera attach <datadir>/opera.ipc` if you started with a custom `--datadir`):

- `net.peerCount` climbs to 4+.
- `New DAG summary` log lines show `age=` in seconds/milliseconds, not hours.
- `eth_syncing` returns `false` and your tip matches the public RPC:

```bash
curl -s -X POST https://vinufoundation-rpc.com -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' \
  | jq -r '"Block \(.result.number): \(.result.hash)"'
```

The block number is returned as a hex quantity (e.g. `0x1705f0`); compare it (and the hash) against another node's `latest`. For a decimal value, run `printf '%d\n' 0x1705f0`.

You should **not** see the `Removing p2p peer ... err="subprotocol error"` churn from [8.2](#id-8-2); if you do, you are still on a pre-`v2.0.8` binary.
{% endstep %}

{% step %}

#### Restart in validator mode

Once fully synced, stop **only the read node you started in step 3** (never `pkill opera` — on a host running more than one validator that stops every validator at once; see [§3.0 Multi-opera safety](#id-3.0-multi-opera-safety)) and relaunch with your validator flags — the **same** ID and pubkey you registered, and always an **absolute** path for the password file:

```bash
# Stop ONLY the read node started in step 3, by its recorded PID.
kill -TERM "$(cat opera.pid)"
# Wait for a clean exit (releases the datadir/IPC lock) before relaunch. If it never
# exits, check the logs; only `kill -KILL "$(cat opera.pid)"` as a last resort.
while kill -0 "$(cat opera.pid)" 2>/dev/null; do sleep 1; done

nohup ./opera \
  --bootnodes "<full canonical testnet bootnodes — copy the complete string from step 3>" \
  --nat extip:<your_public_ipv4> \
  --datadir <datadir> \
  --validator.id <YOUR_VALIDATOR_ID> \
  --validator.pubkey 0xYOUR_PUBKEY \
  --validator.password /absolute/path/to/password.txt \
  > validator.log &
```

The `--bootnodes` value is the **same complete four-enode string** shown in step 3 — copy it verbatim; truncated enodes will fail to peer. Your validator ID and stake are unchanged — you are **resuming the existing validator**, not creating a new one.
{% endstep %}

{% step %}

#### Verify the revival

- **Emitting again:** `validator.log` shows your node producing/confirming events and the chain head advancing.
- **Still active on-chain:** `sfcc.getValidator(<VID>)` still returns `status == 0`, and at the next epoch seal `sfcc.getEpochValidatorIDs(sfcc.currentEpoch())` includes your `<VID>` — confirming you are back in the active set.
- **Stake intact:** `sfcc.getSelfStake(<VID>)` is unchanged.
{% endstep %}
{% endstepper %}

### 8.5 If your validator was already deactivated <a href="#id-8-5" id="id-8-5"></a>

If [8.1](#id-8-1) showed a non-zero `status` / `deactivatedEpoch`, the SFC removed your validator from the active set. What you can do next depends on **why** it was deactivated and on **which network** you are on.

An **offline-deactivated** validator (status bit `8` only — not slashed, not withdrawn) can be reactivated **in place** on **testnet** (chain 206), keeping the same validator ID and stake. Since `SfcV2Patch8` this is **self-service**: you call `reactivateValidator(<VID>)` from the validator's own `auth` key, provided (a) its status is offline-only, (b) its self-stake still meets `minSelfStake()`, and (c) the anti-flap cooldown has elapsed (`offlinePenaltyThresholdTime`, ~5 days after `deactivatedTime`). The SFC owner can also call it, without the cooldown, as a lost-key fallback. **Mainnet's SFC has no reactivation; slashed/double-sign or withdrawn validators cannot be reactivated on either chain — use the recreate path below.**

First bring your node back in synced **validator mode** ([8.4](#id-8-4)) so it resumes emitting the moment the SFC re-adds it, observing double-sign safety ([8.3](#id-8-3)).

**Load the SFC into the Opera console.** Fetch the current ABI and build the `sfcc` object. The script is written under your home directory — not world-writable `/tmp`, where another local user could swap the file between generation and `loadScript`:

```bash
curl -L "https://raw.githubusercontent.com/VinuChain/Vinuchain-Lists/refs/heads/main/contracts/vinuchain/SFC_abi.json" -o "$HOME/SFC_abi.json"

python3 - <<'PY'
import json, os

home = os.path.expanduser("~")
abi = json.load(open(os.path.join(home, "SFC_abi.json")))

js = "var abi = " + json.dumps(abi) + ";\n"
js += 'var sfcc = web3.vc.contract(abi).at("0xFC00FACE00000000000000000000000000000000");\n'
js += 'console.log("SFC ABI loaded. Use sfcc.functionName(...)");\n'

path = os.path.join(home, "sfc_console.js")
open(path, "w").write(js)
print('Now run in the Opera console:  loadScript("%s")' % path)
PY
```

Then inside the Opera console (`./opera attach`), paste the `loadScript` line the script printed, e.g.:

```javascript
loadScript("/home/YOUR_USER/sfc_console.js")
```

**Reactivate** — from the validator's `auth` address (self-service) or the SFC owner address (fallback). Replace `15` with your validator ID:

```javascript
var addr = "0xYOUR_AUTH_OR_OWNER_ADDRESS";
sfcc.getValidator(15)                        // confirm status == 8 (offline only)
personal.unlockAccount(addr, "your-password", 900)
vc.defaultAccount = addr                     // set the sender
vc.defaultAccount                            // confirm the sender
sfcc.reactivateValidator(15, {from: addr})   // reactivate
```

Verify:

```javascript
sfcc.getValidator(15)                                         // status == 0, deactivatedEpoch == 0
sfcc.getEpochValidatorIDs(sfcc.currentEpoch())                // your validator ID (15) should appear in this list
```

#### Slashed / double-sign, withdrawn, or on mainnet → recreate

If `sfcc.isSlashed(<VID>)` is `true` (`DOUBLESIGN_BIT = 128`), the validator **cannot be reactivated on either network** — `reactivateValidator` reverts with `"cheaters cannot be reactivated"`. The same recreate path applies to any deactivated validator on mainnet. Unwind and start over (same as the [§3.4 Offline node](#offline-node) path):

1. If your stake is locked, [`unlockStake()`](lockup-calls.md) first (an early-unlock penalty may apply).
2. [`undelegate()`](delegation-calls.md) your self-stake and wait the validator bonding period — **180 epochs and 3 days** (both must elapse).
3. [`withdraw()`](delegation-calls.md) your stake back to your wallet.
4. Start over from [Become a Validator](become-a-validator.md) with a fresh `createValidator` — this mints a **new** validator ID.

(For a cheater, the SFC owner may separately refund a portion of slashed stake via the slashing-refund flow, but the validator ID itself stays dead.)

To avoid this next time, bring a downed node back **before** the offline-penalty threshold trips (see the deadline box at the top of this section), and keep `nodekey` + `keystore/` backed up so a fast snapshot-restore is always available.
