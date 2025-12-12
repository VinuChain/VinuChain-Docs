---
description: Create your own Private Network (Fakenet)
---

# Private Network (Fakenet)

Fakenet is a private network optimized for your private testing. It'll generate a genesis containing N validators with equal stakes. To launch a validator in this network, all you need to do is specify a validator ID you're willing to launch.

Pay attention that validator's private keys are deterministically generated in this network, so you must use it only for private testing.

Maintaining your own private network is more involved as a lot of configurations taken for granted in the official networks need to be manually set up.

To run the fakenet with just one validator (which will work practically as a PoA blockchain), use:

```
$ opera --fakenet 1/1
```

To run the fakenet with 5 validators, run the command for each validator:

```
$ opera --fakenet 1/5 # first node, use 2/5 for second node
```

If you have to launch a non-validator node in fakenet, use 0 as ID:

```
$ opera --fakenet 0/5
```

After that, you have to connect your nodes. Either connect them statically or specify a bootnode:

```
$ opera --fakenet 1/5 --bootnodes "enode://verylonghex@1.2.3.4:5050"
```

#### Scripts

* start network: `./start.sh`;
* stop network: `./stop.sh`;
* clean data and logs: `./clean.sh`;

You can specify number of genesis validators by setting N environment variable.

#### Balance transfer example

* Start network:

```
N=3 ./start.sh
```

* Attach js-console to running node0:

```
go run ../cmd/opera attach http://localhost:4000
```

* Check the balance to ensure that node0 has something to transfer (node0 js-console):

```
ftm.getBalance(ftm.accounts[0]);
```

output shows the balance value:

```
1e+27
```

* Get node1 address:

```
go run ../cmd/opera attach --exec "ftm.accounts[0]" http://localhost:4001
```

output shows address:

```
"0x02aff1d0a9ed566e644f06fcfe7efe00a3261d03"
```

* Transfer some amount from node0 to node1 address as receiver (node0 js-console):

```
ftm.sendTransaction(
	{from: ftm.accounts[0], to: "0x02aff1d0a9ed566e644f06fcfe7efe00a3261d03", value:  "1000000000"},
	function(err, transactionHash) {
        if (!err)
            console.log(transactionHash + " success");
    });
```

output shows unique hash of the outgoing transaction:

```
0x68a7c1daeee7e7ab5aedf0d0dba337dbf79ce0988387cf6d63ea73b98193adfd success
```

* Check the transaction status by its unique hash (js-console):

```
ftm.getTransactionReceipt("0x68a7c1daeee7e7ab5aedf0d0dba337dbf79ce0988387cf6d63ea73b98193adfd").blockNumber
```

output shows number of block, transaction was included in:

```
174
```

* As soon as transaction is included into a block you will see new balance of both node addresses:

```
go run ../cmd/opera attach --exec "ftm.getBalance(ftm.accounts[0])" http://localhost:4000
go run ../cmd/opera attach --exec "ftm.getBalance(ftm.accounts[0])" http://localhost:4001
```

outputs:

```
9.99999999978999e+26
1.000000000000001e+27
```
