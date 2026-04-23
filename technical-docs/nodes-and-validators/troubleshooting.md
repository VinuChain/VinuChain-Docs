# Troubleshooting

## Troubleshooting

{% hint style="warning" %}
**Testnet operators running or installing v2.x-elemont**: see the [Chain Upgrade Guide](../vinuchain-testnet/chain-upgrade-guide.md) first. Two failure modes need dedicated recovery steps that the legacy procedures on this page do not cover:

- **Validator offline >1,000 epochs cannot rejoin** → upgrade to v2.0.8-elemont (removes the `validatePeerProgress` drift cap). See [Chain Upgrade Guide → stuck peercount](../vinuchain-testnet/chain-upgrade-guide.md#stuck-at-net-peercount-1-with-one-stale-peer).
- **`WARN Incoming event rejected ... err="wrong event epoch hash"`** → fresh resync from the 2024-06-21 genesis **does not work** on current binary rules. Use the chaindata snapshot at `s3://vinu-blockchain-genesis/chaindata-snapshots/` — see [Chain Upgrade Guide → wrong event epoch hash](../vinuchain-testnet/chain-upgrade-guide.md#warn-incoming-event-rejected-err-wrong-event-epoch-hash) for the recovery procedure.

Latest testnet snapshot: `https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.8-20260419-053442.tar.gz` (~1.1 GiB compressed, published 2026-04-19, tip ≈ epoch 5637 / block 1.42M). SHA256 `7d1ec36699c450a820f0b42e3b113bd2d09345e44abb0c39d38d262464f91823`. Excludes `nodekey` / `keystore/` / `static-nodes.json` so your validator identity is preserved during extraction.
{% endhint %}

## 1. Supported go-opera version <a href="#id-1.-current-version-of-go-opera" id="id-1.-current-version-of-go-opera"></a>

The current supported version is **go-opera 2.0.8-elemont** for testnet. Mainnet is still on `v2.0.0-rc.1` pending the next coordinated upgrade window. The legacy "1.1.2-rc.3" line that previously appeared here referred to the pre-elemont fork and is no longer current.

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
curl -C - -o testnet-chaindata-v2.0.8-20260419-053442.tar.gz \
  https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.8-20260419-053442.tar.gz
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
