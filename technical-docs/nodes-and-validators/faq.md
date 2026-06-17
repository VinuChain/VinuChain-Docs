# FAQ

## Node requirements

Recommended minimum hardware requirements:&#x20;

AWS EC2 m5.xlarge with 4 vCPUs (3.1 GHz), SSD (gp2) storage (or equivalent or better).

* CPU > 3.0 GHz
* SSD (or NVMe SSD) (**NB**: AWS gp2 has upto 16000 IOPS)
* Network bandwidth: 1 Gbps  (**NB**: m5.xlarge has upto 10 Gbps)
* Storage: depending on the types of your nodes.

## Types of Opera nodes

* **Read node:** A read node can sync the latest events from the network. Users can submit their transactions into a read node. Transactions will be propagated to the other nodes of the network. A read node is usually run locally, unless you expose it to the outside (with --http, or --ws flag).
* **Validator node:** A validator node can emit new events and they confirm events together with the other validators. Events are propagated to other peer nodes in the network. Users can submit transactions into their own validators, or they can submit transactions to a read node or API node, and then transactions will be propagated across the network.
* **API node:** An API node is functional similar to a read node. Unlike read node, an API node contains all the history (transactions, balances, smart contract interactions). An API node is often expose to the public via --http or --ws flag.
* **Tracing node:** A tracing node is an API node, which has a full history plus additional information for tracing. Users can perform tracing queries on a tracing node.

## Sync modes

* Full syncmode: This allows a node to sync every new blocks from the network. The flag is `--syncmode full`. The sync mode is full by default,  if `--syncmode` is not specified.
* Snap syncmode: This mode is enabled with a `--syncmode snap.` It will sync in snap sync mode, and so it will not download and store every event like in the full syncmode. Thus, it's not suitable for API or tracing node, which requires to store all the historical data.

## Data pruning

To save machine's storage, you may use pruning.

*   Manual pruning:&#x20;

    Stop the node, then issue the following command:\
    `./opera snapshot prune-state`
*   Automatic pruning:

    You can run a node with `--gcmode` flag, and it will prune old data on-the-fly.

    * Full gcmode: This can be enabled by  `--gcmode full`, which prunes old VM tries. It will need more RAM. Often, --cache 15000 (or more RAM) is required to ensure normal operation in this mode.
    * Light gcmode: the light gcmode version (adopted from geth) is less aggressive. It is used by `--gcmode light` flag. It requres  less RAM usage than full gcmode.

## Cache size

One can specify the cache size by --cache \<size in MB>.&#x20;

The default value of cache size is 3200 MB.&#x20;

Nodes tend to sync faster with a larger cache size.

## Transaction ordering

Transactions in blocks aren't necessarily sorted by gas price. Even though transactions in each event and in the txpool are sorted by gas price, events are sorted by their topological ordering in the DAG.&#x20;

A new block includes transactions from multiple confirmed events in that topological order, which is used by Lachesis - a DAG aBFT consensus algorithm.

## Penalty for unspent gas

It is recommended that you make sure to submit transactions with a reasonable gas limit amount.&#x20;

This is because transactions with excessive gas limits will have less chance to be included, due to a gas limit for each block, and the originating power of validators.\
\
There is a penalty of 10% for unspent gas. This penalty is a disincentive against excessive transaction gas limits.

The disincentive is necessary because VinuChain (Lachesis DAG-BFT) is leaderless — blocks are not known in advance to a validator (unlike an Ethereum miner) until blocks are created from confirmed events. There is no single proposer who can originate transactions for a whole block, so validators do not know the used gas in advance.
