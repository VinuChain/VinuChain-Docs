# Deploy a Smart Contract

VinuChain is a full EVM-compatible chain. Smart contracts written in Solidity
deploy and run on VinuChain mainnet (chain 207) exactly as they do on Ethereum.

Deploying a smart contract involves sending a VinuChain transaction containing
your compiled bytecode with no recipient address. You need VC to cover gas fees.

**Mainnet** (chain 207, `https://vinuchain-rpc.com`) is the primary deployment
target. **Testnet** (chain 206, `https://vinufoundation-rpc.com`) is available
for testing before mainnet deployment; use the [testnet faucet](https://faucet.vinuscan.com)
to obtain testnet VC.

## EVM target support

Mainnet supports the full ELEMONT EVM feature set, including Shanghai, Cancun,
and Prague hard-fork opcodes. You can use:

* `evmVersion: "cancun"` or `"prague"` in your Solidity/Hardhat compiler config
* `PUSH0` (EIP-3855), transient storage `TLOAD`/`TSTORE` (EIP-1153), and blob
  base-fee opcode `BLOBBASEFEE` (EIP-7516)
* EIP-7702 set-code transactions for smart-account delegation
* ERC-4337 account abstraction via the canonical EntryPoint v0.7
  (`0x0000000071727De22E5E9d8BAf0edAc6f37da032`) deployed on mainnet via the
  Arachnid deterministic deployer

Testnet runs the same EVM feature set and additionally includes EIP-2537
BLS12-381 precompiles and the P256VERIFY precompile (EIP-7212) — these are
testnet-only features not yet on mainnet.

## **Requirements**

* Bytecode (compiled code) of your smart contract
* VC for gas costs (mainnet VC for mainnet deployment; testnet VC from the [faucet](https://faucet.vinuscan.com) for testing)
* Deployment script or plugin (Hardhat, Foundry, Remix, etc.)
* Access to a VinuChain node — use the public RPC endpoints or run your own node

## Example of smart contract deployment

### Deployment using Hardhat

A minimal [Hardhat](https://hardhat.org/) setup for VinuChain:

```bash
mkdir my-contract && cd my-contract
npm init -y
npm install --save-dev hardhat@2 @nomicfoundation/hardhat-toolbox@5
npx hardhat init   # choose "Create a JavaScript project"
```

(The walkthrough below uses Hardhat 2. Hardhat 3 changes both the init
command — `npx hardhat --init` — and the config format; if you use
Hardhat 3, follow the [Hardhat docs](https://hardhat.org/docs) for project
setup and add the two VinuChain networks with the same URLs and chain IDs
shown here.)

Configure the VinuChain networks in `hardhat.config.js`:

```js
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.24",
  networks: {
    vinuchainTestnet: {
      url: "https://vinufoundation-rpc.com",
      chainId: 206,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY].filter(Boolean),
    },
    vinuchain: {
      url: "https://vinuchain-rpc.com",
      chainId: 207,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY].filter(Boolean),
    },
  },
};
```

Never hardcode your private key — export it as an environment variable
(`export DEPLOYER_PRIVATE_KEY=0x...`) or use a secret manager.

Add a minimal contract at `contracts/Greeter.sol` (the template's own sample
contract and Ignition modules work too; this walkthrough is self-contained):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Greeter {
    string public greeting = "Hello, VinuChain!";
}
```

…and a deploy script at `scripts/deploy.js`:

```js
const hre = require("hardhat");

async function main() {
  const greeter = await hre.ethers.deployContract("Greeter");
  await greeter.waitForDeployment();
  console.log(`Greeter deployed to ${greeter.target}`);
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
```

Deploy it to testnet:

```bash
npx hardhat run scripts/deploy.js --network vinuchainTestnet
```

Once it confirms, look the contract address up on the testnet explorer at
[testnet.vinuexplorer.org](https://testnet.vinuexplorer.org) (for mainnet
deployments, use [vinuexplorer.org](https://vinuexplorer.org)).

### Deployment using Remix

To deploy a smart contract using **Remix** on the **VinuChain Testnet**, follow these simple steps:

1. Connect your Metamask wallet to the VinuChain Testnet.
2. In the Environment option, select 'Injected Provider - Metamask.'
3. Set the **network id** to **206**, which corresponds to the VinuChain Testnet's network id (mainnet is **207**).
4. Once you initiate the smart contract deployment, it will be successfully deployed to the VinuChain Testnet.

## **Additional resources**

* [Compiling](https://ethereum.org/en/developers/docs/smart-contracts/compiling/)
* [Deploying a smart contract on Ethereum](https://ethereum.org/en/developers/tutorials/deploying-your-first-smart-contract/)

## **Tools**

* [Hardhat](https://hardhat.org/): A comprehensive development environment that facilitates editing, compiling, debugging, and deploying smart contracts using the Ethereum Virtual Machine (EVM).
* [Truffle](https://www.trufflesuite.com/): An all-in-one development environment, testing framework, and asset pipeline tailored for blockchain projects utilizing the Ethereum Virtual Machine (EVM).
* [Remix](https://remix.ethereum.org/): An Integrated Development Environment (IDE) enabling you to write, compile, debug, and deploy Solidity code directly in your web browser.
* [Solidity](https://solidity.readthedocs.io/): A sophisticated, object-oriented, high-level language specifically designed for implementing smart contracts on various blockchain platforms.
* [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts): Mitigate risks in your smart contract development by leveraging the battle-tested library of smart contracts provided by OpenZeppelin Contracts, compatible with Ethereum and other blockchain networks.
* [thirdweb](https://thirdweb.com/): A comprehensive Web3 development framework that equips you with all the necessary tools to connect your applications and games with decentralized networks.
