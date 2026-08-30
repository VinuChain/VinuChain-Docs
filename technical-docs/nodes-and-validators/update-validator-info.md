---
description: How to update your Validator info
---

# Update Validator Info

## **Config File**

Create a config file in JSON format that contains the following parameters (you can also leave parameters empty):

```
{  "name": "VALIDATOR_NAME", /* Name of the validator */
  "logoUrl": "LOGO_URL", /* Validator logo (PNG|JPEG|SVG) - 100px x 100px is enough */
  "website": "WEBSITE_URL", /* Website icon on the right */
  "contact": "CONTACT_URL" /* Contact icon on the right */
}
```

Example:

```
{
  "name": "any",
  "logoUrl": "https://any.site/vinu/any.png",
  "website": "https://any.site",
  "contact": "https://t.me/any_vinu"
}
```

Then host it somewhere publicly accessible.

## **Update your info in the smart contract**

1. Connect to your validator node
2. Open up a go-opera console session via `go-opera attach`
3. Load the `stakerInfoContract ABI` and instantiate the contract:

```
abi = JSON.parse('[{"inputs":[{"internalType":"address","name":"_stakerContractAddress","type":"address"}],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"stakerID","type":"uint256"}],"name":"InfoUpdated","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"previousOwner","type":"address"},{"indexed":true,"internalType":"address","name":"newOwner","type":"address"}],"name":"OwnershipTransferred","type":"event"},{"constant":true,"inputs":[],"name":"isOwner","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"owner","outputs":[{"internalType":"address","name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"renounceOwnership","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"stakerInfos","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"newOwner","type":"address"}],"name":"transferOwnership","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"_stakerContractAddress","type":"address"}],"name":"updateStakerContractAddress","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"string","name":"_configUrl","type":"string"}],"name":"updateInfo","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"internalType":"uint256","name":"_stakerID","type":"uint256"}],"name":"getInfo","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"}]')
```

**Mainnet:**

```
stakerInfoContract = web3.vc.contract(abi).at("0xb914a0b16111BaB228ae6214e6E1FD4a5EaE877C")
```

**Testnet:**

```
stakerInfoContract = web3.vc.contract(abi).at("0x6b39bcd174DddF5A17d065822BDC43353eB6112A")
```

4. Unlock validator account

```
# Unlock validator wallet
personal.unlockAccount("VALIDATOR_WALLET_ADDRESS", "PASSWORD", 300)
```

5. Call the `updateInfo` function of the `stakerInfoContract` (make sure you have enough VC on your wallet to cover the transaction fee)

```
stakerInfoContract.updateInfo("CONFIG_URL", 
{ from: "VALIDATOR_ADDRESS" })
```

Example:

```
stakerInfoContract.updateInfo("https://any.site/vinu/config.json", 
{ from: "VALIDATOR_WALLET_ADDRESS" })
```

6. Validate if you updated your info correctly

```
stakerInfoContract.getInfo(STAKER_ID)
```

Example:

```
stakerInfoContract.getInfo(14)
```

{% hint style="warning" %}
**Keep the config URL reachable.** `updateInfo` stores only a **URL**; the staking UI and the GraphQL API fetch the JSON from it on every render. If that host later goes offline or the path moves, your validator silently loses its name and logo and shows as unnamed — the on-chain record still looks correct, so nothing appears broken.

Publish it somewhere durable (a GitHub raw URL, S3, or a domain you control), serve it over **HTTPS**, and re-check it after any hosting change. Several mainnet validators currently render unnamed for exactly this reason, which also leaves no route to contact their operators during a network upgrade.
{% endhint %}
