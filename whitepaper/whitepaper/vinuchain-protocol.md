# VinuChain Protocol

### 3.1 Directed Acyclic Graph Architecture

VinuChain is a novel blockchain protocol that has been designed as a fork of the Fantom Protocol with enhancements. It employs the same underlying Directed Acyclic Graph (DAG) architecture with the unique enhancement of a Quota System.

In a DAG-based architecture, transactions are processed asynchronously, with each new transaction being linked to previous ones, forming a non-linear network of interconnected transactions. This structural design allows for high scalability and faster transaction speed, as transactions can be processed in parallel instead of sequentially.

### 3.2 Lachesis Protocol and ECC

VinuChain, like Fantom, uses the Lachesis protocol for its consensus mechanism, which supports smart contracts and enables a high transaction speed, ensuring security and scalability. The Lachesis protocol uses Elliptic Curve Cryptography (ECC) to secure transactions and assure authenticity.

### 3.3 Quota System

In contrast to Fantom, VinuChain introduces a Quota System, a unique mechanism that allows for feeless transactions for stakers. This Quota System is a separate layer atop the underlying consensus mechanism and does not directly influence the consensus process. Staking VC in VinuChain reserves transaction quota for the stakers, enabling them to conduct transactions without paying any gas fees, up to their quota limit. Furthermore, an innovative cash-back mechanism is implemented where an inflation on the native token (VC) funds the cash-back to stakers.

This architectural design choice offers two major benefits. Firstly, it allows users who can stake VC to conduct transactions without worrying about gas fees, making microtransactions viable and promoting broader network usage. Secondly, it adds a layer of incentive for users to hold and stake VC, indirectly promoting network security by increasing the staked supply.

We will further elaborate on the unique Quota System (Section 5) and the consensus mechanism (Section 4). It is important to note, however, that while the Quota System and Consensus Mechanism both serve pivotal roles in the functioning of VinuChain, they operate independently of each other; the Quota System is not a part of the Consensus Mechanism.

