# Deploy a Smart Contract

VinuChain leverages a significant portion of the Ethereum Virtual Machine (EVM) on its backend. Smart contracts, coded in Solidity, can seamlessly operate on the VinuChain network, just as they do on Ethereum.

Deploying a smart contract involves sending a VinuChain transaction containing your bytecode without specifying any recipients. It's essential to have VC tokens to cover the gas fees for the deployment process.

For acquiring testnet VC tokens, you can utilize the [testnet faucet](https://faucet.vinuscan.com).

Once the contract is successfully deployed, it becomes accessible to all users within the VinuChain network. Smart contracts are assigned a VinuChain address, similar to other accounts on the platform.

## **Requirements**

* Bytecode (compiled code) of your smart contract
* VC for gas costs
* Deployment script/plugin
* Access to a VinuChain node, by either running your own node or obtaining API access to a node.

For acquiring testnet VC tokens, you can utilize the testnet faucet.

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
