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

Coming soon

### Deployment using Remix

To deploy a smart contract using **Remix** on the **VinuChain Testnet**, follow these simple steps:

1. Connect your Metamask wallet to the VinuChain Testnet.
2. In the Environment option, select 'Injected Provider - Metamask.'
3. Set the **network id** to **26**, which corresponds to the VinuChain Testnet's network id.
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
