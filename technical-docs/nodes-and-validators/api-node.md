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

### **Download genesis file**

```
#Download genesis file
(validator)$ curl https://vinu-blockchain-mainnet-genesis.s3.amazonaws.com/vitainu-genesis-mainnet-with-contracts.g \
    --output vitainu-genesis-mainnet-with-contracts.g
```

### **Run node**

You can turn on and off **http** and **ws** options, use your ports and addresses.

```
# Run node
(validator)$ cd build

(validator)$ nohup ./opera \
    --genesis ../vitainu-genesis-mainnet-with-contracts.g \
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
