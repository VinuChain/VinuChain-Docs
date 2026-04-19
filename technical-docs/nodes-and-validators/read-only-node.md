---
description: How to run a Read-Only Node
---

# Read-Only Node

## Read-Only Nodes

Read-Only Nodes are nodes that do not participate in the consensus process. Instead, they connect to full nodes or the network's APIs to retrieve information from the blockchain.&#x20;

Read-only nodes can be used for various purposes, such as querying transaction history, checking account balances, and monitoring network activity.&#x20;

They are "read-only" because they cannot write or create new transactions on the blockchain; they can only read and display data.

_**You must install a read-only node before you can upgrade to a validator node!**_

## Launch cloud instance

You can either run a node on your own hardware or use a cloud provider.&#x20;

We would recommend choosing one of the big cloud providers, e.g. Amazon AWS.&#x20;

### **Node Specifications**&#x20;

We recommend the following or better:&#x20;

m5.xlarge General Purpose Instance with 4 vCPUs (3.1 GHz), 16GB of memory, up to 10 Gbps network bandwidth, and at least 500 GB of disk space. AWS m6i.2xlarge, c6i.4xlarge can provide better performance.

We would recommend going with Ubuntu Server 22.04 LTS (64-bit).&#x20;

### **Network Settings**&#x20;

* Open **port 22** for SSH
* Open **port 5050** for both TCP and UDP traffic.
* Open **port 3000**
* Open **port 4000**

A custom port can be used with `--port` flag when run your opera node.

### **Set up Non-Root User**&#x20;

If there is already a non-root user available, you can skip this step.

```
# SSH into your machine
(local)$ ssh root@{VALIDATOR_IP_ADDRESS}
# Update the system
(validator)$ sudo apt-get update && sudo apt-get upgrade -y
# Create a non-root user
(validator)$ USER={USERNAME}
(validator)$ sudo mkdir -p /home/$USER/.ssh
(validator)$ sudo touch /home/$USER/.ssh/authorized_keys
(validator)$ sudo useradd -d /home/$USER $USER
(validator)$ sudo usermod -aG sudo $USER
(validator)$ sudo chown -R $USER:$USER /home/$USER/
(validator)$ sudo chmod 700 /home/$USER/.ssh
(validator)$ sudo chmod 644 /home/$USER/.ssh/authorized_keys
```

* For `(validator)$ USER={USERNAME}` write your non-root username.
* Make sure to paste your public SSH key into the `authorized_keys` file of the newly created user in order to be able to log in via SSH.

```
# Enable sudo without password for the user
(validator)$ sudo vi /etc/sudoers
```

Add the following line to the end of the file:&#x20;

```
{USERNAME} ALL=NOPASSWD: ALL
```

* If this doesn't work for you, try `sudo passwd nonrootusername`
* Not required in 22.04

Now close the root SSH connection to the machine and log in as your newly created user:

```
# Close the root SSH connection
(validator)$ exit
# Log in as new user
(local)$ ssh {USERNAME}@{VALIDATOR_IP_ADDRESS}
```

## Install required tools

You are still logged in as the new user via SSH.&#x20;

Now we are going to install **Go** and **Opera**.&#x20;

First, install the required build tools:

```
# Install build-essential
(validator)$ sudo apt-get install -y build-essential
```

### **Install Go**

```
# Install go
(validator)$ wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
(validator)$ sudo tar -xvf go1.22.5.linux-amd64.tar.gz
(validator)$ sudo mv go /usr/local
```

If that didn't work, you could also try:

```
# Install go
(validator)$ sudo snap install go --classic
```

Export the required Go paths:

```
# Export go paths
(validator)$ vi ~/.bash_aliases
# Append the following lines
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
(validator)$ source ~/.bash_aliases
```

If the final line did not work for you, try `(validator)$ . ~/.bash_aliases` instead.

Alternatively, install Go via snap:

```
(validator)$ sudo snap install go --classic
```

**Validate your Go installation**

```
go version
```

### **Install Opera**

```
# Install Opera
(validator)$ git clone https://github.com/VinuChain/VinuChain
(validator)$ cd VinuChain/
(validator)$ make
```

**Validate your Opera installation**

```
$./build/opera version
VERSION:
2.0.0-rc.1
```

### Download Genesis File

A genesis file is a configuration file that contains the initial settings and parameters for the VinuChain network when it is launched.&#x20;

The genesis file is a crucial component of any blockchain network, as it defines the initial state of the network, including information about the initial block, accounts, validators, and other network-specific parameters.

Drive: [Genesis Files](https://drive.google.com/drive/folders/1_LKq9ljXYwH4LkxO-6e8UnVgiWncGCBH?usp=sharing)

You can download a genesis file from the Drive above, or from the following commands:

**Mainnet:**

```
# Download Mainnet genesis file
(validator)$ curl https://vinu-blockchain-mainnet-genesis.s3.amazonaws.com/vitainu-genesis-mainnet-20240524.g
--output vinuchain-genesis.g
```

**Testnet:**

```
# Download Testnet genesis file (2026-04-19, with history through epoch ~5637 / block ~1.42M)
(validator)$ curl -LO https://vinu-blockchain-genesis.s3.amazonaws.com/vitainu-genesis-testnet-20260419.g
(validator)$ curl -LO https://vinu-blockchain-genesis.s3.amazonaws.com/vitainu-genesis-testnet-20260419.g.sha256
(validator)$ sha256sum -c vitainu-genesis-testnet-20260419.g.sha256
(validator)$ mv vitainu-genesis-testnet-20260419.g vinuchain-genesis-testnet.g
```

{% hint style="warning" %}
**Do not use the 2024-06-21 testnet genesis (`vitainu-genesis-testnet-20240621.g`) under v2.0.8+ binary.** It pre-dates `SfcV2` / `SfcV2Patch` / `SfcV2Patch2`, and a fresh replay under current binary rules produces a state hash that does not match live testnet history — the first inbound event from any current-tip peer rejects with `err="wrong event epoch hash"`. The 2026-04-19 genesis above has history baked post-all-patches and is recognized as a trusted preset by v2.0.9+ (no `--genesis.allowExperimental` required). Older testnet genesis files (2023-08-31 and 2024-06-21) remain in the bucket for archival only; do not use them for new installs.

**Under v2.0.10-elemont, fresh-install operators must also restore from the post-seal chaindata snapshot** at `s3://vinu-blockchain-genesis/chaindata-snapshots/testnet-chaindata-v2.0.10-*.tar.gz`. Replaying from genesis alone under v2.0.10 seals `SfcV2Patch3` at a different block than the live chain did, producing an identical `wrong event epoch hash` divergence. The snapshot bypasses the replay and joins at tip. The older v2.0.8 chaindata snapshot is stale under v2.0.10 rules and must not be used.
{% endhint %}

### Start Opera Read-Only Node

First, start the **Opera read-only node** to interact with it and to create a validator wallet:

**Mainnet:**

```
# Start opera node (Mainnet)
(validator)$ cd build/
(validator)$ nohup ./opera --port 3000 --nat any 
--genesis ../vinuchain-genesis.g
--bootnodes enode://0281626c7d7fc8696300688cbb19f3781aabd981d74cd16f3f5cd7885a32da4d1d9d64afbb2416b93654935a3088afbe1a4a05d823ff2146e5d1d0c2cbdeca46@188.165.195.122:3000
> opera.log &
```

**Testnet:**

```
# Start opera node (Testnet) — v2.0.9-elemont or later recognizes the 2026-04-19
# genesis as a trusted preset, so --genesis.allowExperimental is no longer required.
# On older binaries, add --genesis.allowExperimental; also replace --nat any with
# --nat extip:<your_public_ipv4> in any production setup (see Chain Upgrade Guide).
(validator)$ cd build/
(validator)$ nohup ./opera --port 3000 --nat extip:<YOUR_PUBLIC_IPV4> \
    --genesis ../vinuchain-genesis-testnet.g \
    --bootnodes enode://e2a95c1b8d85b018b8e88133bec342801b42e19b59a52e030462d04a5549f02fc57215b4ca97771ec6b3a0d30a78603fdccd2b5091c44f6ac439d6c8be8bc539@44.239.129.39:3000 \
    > opera.log &
```

* Replace `GENESIS_FILENAME` with the actual Genesis file's filename you are using.

There are different ways to Run your read-only node.

Note that **https** and **ws** must **not** be enabled on a server that stores wallet account.

Starting up your node will look something like this:

<figure><img src="../../.gitbook/assets/asasf.png" alt=""><figcaption></figcaption></figure>

The node should start to sync the network data:

<figure><img src="../../.gitbook/assets/sagag.png" alt=""><figcaption></figcaption></figure>

Once it's running you should wait until it's synced up to the latest block.

A Read-Only Node can be upgraded into a [Validator](become-a-validator.md).
