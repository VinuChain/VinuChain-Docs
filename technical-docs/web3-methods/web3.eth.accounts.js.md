---
description: Generate wallet accounts and sign transactions and data
---

# web3.eth.accounts.js

```
var Web3 = require('web3');

const { TESTNET_RPC } = require('../constants');

const web3 = new Web3(new Web3.providers.HttpProvider(TESTNET_RPC));

const privateKey = process.env.PRIVATE_KEY;
const password = process.env.WALLET_PASSWORD;

const requireWalletSecrets = () => {
  if (!privateKey || !password) {
    throw new Error(
      'Set PRIVATE_KEY and WALLET_PASSWORD in a local .env file before running these examples.'
    );
  }
};

const createAccounts = () => {
  requireWalletSecrets();

  const generatedAccount = web3.eth.accounts.create();
  console.log('Generated account address:', generatedAccount.address);

  const entropyAccount = web3.eth.accounts.create(
    '2435@#@#@±±±±!!!!678543213456764321§34567543213456785432134567'
  );
  console.log('Generated account with entropy address:', entropyAccount.address);

  const privateKeyAccount = web3.eth.accounts.privateKeyToAccount(privateKey);
  console.log('Loaded account address:', privateKeyAccount.address);
};

const signAndRecoverMessage = () => {
  requireWalletSecrets();

  let signedMessage = web3.eth.accounts.sign('Text', privateKey);
  console.log('Signed message hash:', signedMessage.messageHash);

  let recoveredMessage = web3.eth.accounts.recover(signedMessage);

  console.log('Recovered address:', recoveredMessage);
};

const encryptAndDecrypt = () => {
  requireWalletSecrets();

  let encryptedKey = web3.eth.accounts.encrypt(privateKey, password);
  console.log('Encrypted key created; do not print keystore contents.');

  let decryptedKey = web3.eth.accounts.decrypt(encryptedKey, password);
  console.log('Decrypted key address:', decryptedKey.address);
};

const wallets = () => {
  requireWalletSecrets();

  web3.eth.accounts.wallet.create(1);
  console.log('Created wallet with 1 account.');

  const addedAccount = web3.eth.accounts.wallet.add(privateKey);
  console.log('Added account address:', addedAccount.address);

  const removedAccount = web3.eth.accounts.wallet.remove(process.env.FROM_ADDRESS);
  console.log('Removed account:', removedAccount);

  let encryptedWallet = web3.eth.accounts.wallet.encrypt(password);
  console.log('Encrypted wallet created; do not print keystore contents.');

  let decryptedWallet = web3.eth.accounts.wallet.decrypt(
    encryptedWallet,
    password
  );
  console.log('Decrypted wallet account count:', decryptedWallet.length);

  console.log('Cleared wallet:', web3.eth.accounts.wallet.clear());
};

module.exports = {
  createAccounts,
  signAndRecoverMessage,
  encryptAndDecrypt,
  wallets
};
```
