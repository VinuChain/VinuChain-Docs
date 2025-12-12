---
description: README.md
---

# Web3 Methods

This repository contains examples of web3 methods that can be used on VinuChain. \
VinuChain is an EVM-compatible chain secured by the Lachesis consensus algorithm.

The methods can be categorised into:

* ABI
* Accounts
* Common Methods
* Contract
* IBAN
* Subscribe
* Utils

[**ABI**](web3.eth.abi.js.md)

The web3.eth.abi functions let you encode and decode parameters to ABI.

[**Accounts**](web3.eth.accounts.js.md)

The web3.eth.accounts package contains functions to generate wallet accounts and sign transactions and data.

#### [Common Methods](common.js.md) <a href="#user-content-common-methods" id="user-content-common-methods"></a>

The main package web3.eth contains simple API references that can help get certain information about the connected blockchain.

[**Contract**](web3.eth.contract.js.md)

The web3.eth.contract package makes it easy to interact with smart contracts on the blockchain. When you create a new contract object you give it the json interface of the respective smart contract and web3 will auto convert all calls into low level ABI calls over RPC for you. This allows you to interact with smart contracts as if they were JavaScript objects.

[**IBAN**](web3.eth.iban.js.md)

The web3.eth.Iban function converts wallet addresses from and to IBAN and BBAN.

[**Subscribe**](web3.eth.subscribe.js.md)

The web3.eth.subscribe function lets you subscribe to specific events in the blockchain.

[**Utils**](web3.eth.utils.js.md)

Utility functions for Blockchain dapps and other web3.js packages.

### Build <a href="#user-content-build" id="user-content-build"></a>

#### Add .env file <a href="#user-content-add-env-file" id="user-content-add-env-file"></a>

```
FROM_ADDRESS=
PRIVATE_KEY = 
TO_ADDRESS=
IBAN=
```

```
npm install
```

### Run <a href="#user-content-run" id="user-content-run"></a>

### node app.js <a href="#user-content-run" id="user-content-run"></a>

<br>
