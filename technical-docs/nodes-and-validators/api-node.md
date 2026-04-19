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
(validator)$ make
```

## Mainnet

### **Download genesis file**

```
#Download genesis file
(validator)$ curl https://vinu-blockchain-mainnet-genesis.s3.us-east-1.amazonaws.com/vitainu-genesis-mainnet-with-contracts.g 
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
    --bootnodes enode://0281626c7d7fc8696300688cbb19f3781aabd981d74cd16f3f5cd7885a32da4d1d9d64afbb2416b93654935a3088afbe1a4a05d823ff2146e5d1d0c2cbdeca46@188.165.195.122:3000 \
    --verbosity=3 --tracing > ./opera_read_node.log &
```

* Replace `your_hostname` variables.

## Testnet

### **Download genesis file**

```
# Download Testnet genesis file (2026-04-19, with history through epoch ~5637)
(validator)$ curl -LO https://vinu-blockchain-genesis.s3.amazonaws.com/vitainu-genesis-testnet-20260419.g
(validator)$ curl -LO https://vinu-blockchain-genesis.s3.amazonaws.com/vitainu-genesis-testnet-20260419.g.sha256
(validator)$ sha256sum -c vitainu-genesis-testnet-20260419.g.sha256
```

{% hint style="warning" %}
**Use only the 2026-04-19 testnet genesis under v2.0.8+ binary.** The legacy 2024-06-21 file pre-dates `SfcV2` / `SfcV2Patch` / `SfcV2Patch2` and produces a `wrong event epoch hash` divergence on replay. v2.0.9-elemont recognizes the 2026-04-19 genesis as a trusted preset, so no `--genesis.allowExperimental` is required.
{% endhint %}

### **Run node**

You can turn on and off **http** and **ws** options, use your ports and addresses.

```
# Run node
(validator)$ cd build

(validator)$ nohup ./opera \
    --genesis ../vitainu-genesis-testnet-20260419.g \
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
