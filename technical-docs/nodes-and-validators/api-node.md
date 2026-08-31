---
description: How to run an API Node
---

# API Node

## API Nodes

API nodes are special types of nodes that run on the VinuChain network and provide access to the full history of transactions, balances, and smart contract interactions. They are often exposed to the public via HTTP or WebSocket protocols, allowing developers and users to interact with the VinuChain network.

API nodes also support transaction tracing, which is a feature that enables tracking the execution of smart contracts and their internal calls.

API nodes are useful for building applications that require querying historical data or tracing smart contract logic on the VinuChain network.

## Initial steps

### **Install Opera**

```
# Install Opera
(validator)$ git clone https://github.com/VinuChain/VinuChain
(validator)$ cd VinuChain/
(validator)$ git checkout v2.0.49-elemont
(validator)$ make
```

## Mainnet

### **Restore latest snapshot**

**Mainnet:**

Current mainnet installs must restore the latest chaindata snapshot instead of replaying from a genesis file:

```text
https://vinu-blockchain-mainnet-genesis.s3.amazonaws.com/chaindata-snapshots/elemont-20260829/seal-5/mainnet-chaindata-elemont-seal5-20260830T103737Z.tar.zst
```

SHA256: `969fb6acc86f1cfbc29ceed77224c25046f410c6e78726d5078c04a07afd7b31` (tip epoch 7,894 / block 14,709,230)

```bash
# download, verify, extract  (needs zstd)
(validator)$ curl -fL -O https://vinu-blockchain-mainnet-genesis.s3.amazonaws.com/chaindata-snapshots/elemont-20260829/seal-5/mainnet-chaindata-elemont-seal5-20260830T103737Z.tar.zst
(validator)$ curl -fL -O https://vinu-blockchain-mainnet-genesis.s3.amazonaws.com/chaindata-snapshots/elemont-20260829/seal-5/mainnet-chaindata-elemont-seal5-20260830T103737Z.tar.zst.sha256
(validator)$ sha256sum -c mainnet-chaindata-elemont-seal5-20260830T103737Z.tar.zst.sha256
(validator)$ cd build && tar -I zstd -xf ../mainnet-chaindata-elemont-seal5-20260830T103737Z.tar.zst
```

{% hint style="warning" %}
**Do not bootstrap current mainnet from a genesis file.** The distributed 2024 mainnet genesis pre-dates every ELEMONT-era upgrade flag. A fresh replay under `v2.0.49-elemont` seals those flags at different blocks than the live chain did, so the node computes a different epoch-state hash and rejects current-tip events with `err="wrong event epoch hash"`. The snapshot above, and the regenerated genesis below, were both produced after all five activation seals (2026-08-29/30); they are the only valid mainnet bootstraps. The older mainnet genesis files remain archival only.
{% endhint %}

#### Alternative: bootstrap from the regenerated genesis

The snapshot above is the **fastest** path. The regenerated genesis is the
**verifiable** one — its section hashes are compiled into the binary's
`AllowedOperaGenesis`, so opera refuses to start on a tampered file. A snapshot's
checksum lives beside the archive on the same bucket, so it can only be trusted as
far as that bucket is.

```bash
(validator)$ curl -fL -O https://vinu-blockchain-mainnet-genesis.s3.amazonaws.com/genesis/elemont-20260829/vitainu-genesis-mainnet-elemont-20260830.g
(validator)$ curl -fL -O https://vinu-blockchain-mainnet-genesis.s3.amazonaws.com/genesis/elemont-20260829/vitainu-genesis-mainnet-elemont-20260830.g.sha256
(validator)$ sha256sum -c vitainu-genesis-mainnet-elemont-20260830.g.sha256
```

| | |
|---|---|
| Size | `50,791,105,980` bytes (47.3 GiB) |
| sha256 | `14021d4f64e395ed705b7adfb5a29c648cfef6ae4f52abe2a2eb563c369fddd8` |
| Exported from | epoch 7,896 / block 14,711,847 — after all five ELEMONT seals |

Then start with `--genesis ./vitainu-genesis-mainnet-elemont-20260830.g` **instead of**
`--datadir` pointing at an extracted snapshot. Replay takes considerably longer than
extracting the snapshot; pick it when you want the binary to verify the source itself.

**Which to use:** snapshot for speed, genesis when you want end-to-end verification.
Both produce the same node — you need one or the other, never both. Once a datadir
exists, neither is read again (`Genesis is already written`).



### **Run node**

You can turn on and off **http** and **ws** options, use your ports and addresses.

```
# Run node
(validator)$ cd build

(validator)$ nohup ./opera \
    --datadir ./datadir \
    --http \
    --http.addr=your_hostname \
    --http.port 4000  --http.corsdomain=* --http.vhosts=* \
    --http.api=eth,debug,net,admin,web3,personal,txpool,vc,dag \
    --ws \ 
    --ws.addr=your_hostname \
    --ws.port 4100 \
    --ws.api=eth,debug,net,admin,web3,personal,txpool,vc,dag \
    --ws.rpcprefix "/" \
    --bootnodes "enode://678f242c2d60ed433c23bba0f9ea00982ea9bc5eb1d7f91337c23ccec5f41c9634705fa79994ba8f62ee893574451631a10f694cfa684f75524de79a7e50f890@54.244.138.80:3000,enode://e0d777bf4ef6318a748ffbd2c58d3b664f5132a02d711567a6df378504c49edbc3145b8f0105ea100988bd1bb57ac574a783d255b2b57abd65a5f0ae13954e77@35.161.54.139:3000,enode://0281626c7d7fc8696300688cbb19f3781aabd981d74cd16f3f5cd7885a32da4d1d9d64afbb2416b93654935a3088afbe1a4a05d823ff2146e5d1d0c2cbdeca46@188.165.195.122:3000" \
    --verbosity=3 --tracing > ./opera_read_node.log &
```

* Replace `your_hostname` variables.

## Testnet

### **Restore latest snapshot**

Current testnet API nodes must restore the latest chaindata snapshot before first start:

```text
https://vinu-blockchain-genesis.s3.amazonaws.com/chaindata-snapshots/testnet-chaindata-v2.0.47-elemont-20260820T113052Z-clean.tar.gz
```

SHA256: `56fb6ed4ca88f4fe202444180036b1a5920560d1879110716d6ae74befa2409d` (tip epoch 6,375 / block 1,585,766)

{% hint style="warning" %}
**Do not bootstrap current testnet from genesis files or pre-v2.0.47 snapshots.** Nodes that missed a seal-time upgrade compute a different epoch-state hash and reject current-tip events with `err="wrong event epoch hash"`. The v2.0.47 snapshot above includes all sealed upgrades through `SfcV2Patch10`; older testnet snapshots and genesis files remain archival only.
{% endhint %}

### **Run node**

You can turn on and off **http** and **ws** options, use your ports and addresses.

```
# Run node
(validator)$ cd build

(validator)$ nohup ./opera \
    --datadir ./datadir \
    --http \
    --http.addr=your_hostname \
    --http.port 4000  --http.corsdomain=* --http.vhosts=* \
    --http.api=eth,debug,net,admin,web3,personal,txpool,vc,dag \
    --ws \ 
    --ws.addr=your_hostname \
    --ws.port 4100 \
    --ws.api=eth,debug,net,admin,web3,personal,txpool,vc,dag \
    --ws.rpcprefix "/" \
    --bootnodes enode://e2a95c1b8d85b018b8e88133bec342801b42e19b59a52e030462d04a5549f02fc57215b4ca97771ec6b3a0d30a78603fdccd2b5091c44f6ac439d6c8be8bc539@44.239.129.39:3000 \
    --verbosity=3 --tracing > ./opera_read_node.log &
```

* Replace `your_hostname` variables.

<br>

<br>

<br>
