# Network Architecture

### 6.1 Node Structure

VinuChain's network architecture closely mirrors the structure established by Fantom. It is designed to offer the same levels of security, speed, and scalability while innovatively integrating its unique Quota System.

The core of VinuChain's infrastructure comprises nodes, the individual elements that together form the distributed network. These nodes are responsible for validating transactions, maintaining the state of the blockchain, and upholding the consensus rules. This structure can be divided into two primary categories: validator nodes and ordinary nodes.

### 6.2 Validator and Ordinary Nodes

Validator nodes form the backbone of the VinuChain network. By staking VC, the native token, they participate in the network's consensus process. Their primary responsibilities involve verifying transactions, creating new blocks, and preserving the integrity of the blockchain.

Ordinary nodes, while not directly involved in the consensus process, fulfill crucial network functionalities. They contribute to maintaining the blockchain's state, relaying transactions, and enhancing the overall robustness of the network.

### 6.3 Quota System

The key divergence between VinuChain and Fantom lies in the introduction of the Quota System. This innovative solution eliminates the direct transaction fee for those who stake a certain amount of VC, replacing it with a quota that grants a specific number of feeless transactions based on the amount staked. This quota accrues and refreshes per epoch, providing a steady stream of feeless transactions for stakeholders.

{% hint style="info" %}
**Implementation note — quota refresh cadence.**
The original whitepaper described a 24-hour quota refresh window. The live
system uses the **epoch-based Payback** model: quota accrues each epoch in
proportion to the staker's share of total stake, and refunds are applied
in-protocol as a `feeRefund` on the transaction receipt. See the
[Quota System](quota-system.md) chapter and the
[Feeless Transactions](../../technical-docs/smart-contracts/feeless-transactions.md)
page for full details on the shipped parameters.
{% endhint %}

### 6.4 Scalability and Security

The network architecture of VinuChain is designed to scale according to demand. This adaptability ensures that a large number of nodes can participate without compromising speed or performance, thus providing the capacity to handle high volumes of transactions.

Security remains paramount in VinuChain's design. Measures such as the requirement for validators to stake a significant amount of VC and the use of cryptographic signatures for transaction verification ensure the network's integrity and security.

### 6.5 Supported Programming Languages

VinuChain, akin to its parent protocol Fantom, adopts a flexible approach towards programming language compatibility, offering developers an extensive range of options to design and create decentralized applications (dApps). This breadth of support caters to developers with different coding proficiencies and facilitates the creation of diverse and innovative dApps within the VinuChain ecosystem.

Solidity, the preeminent smart contract language of the Ethereum network, is natively supported on VinuChain. This enables a seamless transition for developers accustomed to Ethereum's smart contract environment and allows a broad range of pre-existing dApps and tools to be deployed on VinuChain.

In addition to Solidity, VinuChain provides compatibility with other programming languages through transcompilers. This encompasses languages like Vyper and Yul, further expanding the repertoire of options available to developers.

Furthermore, VinuChain supports WebAssembly (Wasm), an efficient binary format that is fast, secure, and compatible with a multitude of languages, including Rust, C++, and TypeScript. The support for Wasm increases the versatility of VinuChain, allowing integration of advanced cryptographic primitives and offering developers greater flexibility.

By fostering a diverse language environment, VinuChain encourages participation from a wide array of developers, contributing to the goal of creating a robust and inclusive decentralized ecosystem.

### 6.6 Future Development

VinuChain will continue to refine and optimize its network architecture to enhance performance, scalability, and security. Leveraging advancements in blockchain technology, VinuChain is committed to delivering a high-performance, feeless blockchain platform that meets the needs of a diverse and growing user base.

<br>

<br>

<br>
