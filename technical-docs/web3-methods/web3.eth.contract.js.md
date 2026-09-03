---
description: Interact with smart contracts on the blockchain
---

# web3.eth.contract.js

```
var Web3 = require('web3');
const { signTransaction } = require('../common');
const { TESTNET_RPC, ABI, CONTRACT_ADDRESS, BYTE_CODE } = require('../constants');

const web3 = new Web3(new Web3.providers.HttpProvider(TESTNET_RPC));

var myContract = new web3.eth.Contract(ABI, CONTRACT_ADDRESS);

const firstMessage = 'Hello, Hardhat!';
let messageToUpdate = 'Hello, Hardhat again!';

const deploy = async () => {
  let deployContract = new web3.eth.Contract(ABI);

  // Function Parameter
  let payload = {
    data: BYTE_CODE,
    arguments: ['Hello!']
  };

  const tx = await deployContract.deploy(payload);

  signTransaction(tx);
};

const updateProperties = async () => {
  web3.eth.defaultAccount = process.env.FROM_ADDRESS;
  console.log('Setting the default account: ', web3.eth.defaultAccount);

  let message = await myContract.methods.greet().call();
  console.log('Using method.call() to get value: ', message);

  messageToUpdate =
    message === firstMessage ? 'Hello, Hardhat again!' : firstMessage;

  console.log('Using method.send() to update the message');

  const tx = await myContract.methods.setGreeting(messageToUpdate);

  await signTransaction(tx, myContract, true);

  console.log(`New data value: ${await myContract.methods.greet().call()}`);
};

const getEvents = async () => {
  await myContract.getPastEvents(
    'UpdateGreeting',
    {
      // VinuChain public RPCs reject a filtered eth_getLogs spanning more than
      // 100,000 blocks (only 100 blocks with no address/topics filter), so a
      // fromBlock: 0 scan fails with -32000 'too wide blocks range'. Leave
      // headroom: 'latest' advances between this call and the getLogs call.
      fromBlock: (await web3.eth.getBlockNumber()) - 99000,
      toBlock: 'latest'
    },
    function (error, events) {
      if (error) {
        console;
        return;
      }
      for (i = 0; i < events.length; i++) {
        var eventObj = events[i];
        console.log('Event Blocknumber: ', eventObj.blockNumber);
        console.log('Event Data: ' + eventObj.returnValues.greeting);
      }
    }
  );
};

const batchRequest = async () => {
  var myContract = new web3.eth.Contract(ABI, CONTRACT_ADDRESS);
  var batch = await new web3.BatchRequest();
  batch.add(
    web3.eth.getBalance.request(
      process.env.FROM_ADDRESS,
      'latest',
      (error, result) => {
        if (error) console.error(error);
        else console.log('Result: ', web3.utils.fromWei(result, 'ether'));
      }
    )
  );
  batch.add(
    myContract.methods
      .greet()
      .call.request({ from: process.env.FROM_ADDRESS }, (error, result) => {
        if (error) console.error(error);
        else console.log('Result: ', result);
      })
  );
  batch.execute();
};

module.exports = { deploy, updateProperties, getEvents, batchRequest };
```
