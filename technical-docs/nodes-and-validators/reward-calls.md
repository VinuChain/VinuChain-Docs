---
description: Reward calls reference
---

# Reward Calls

### Claim rewards

Claim earned rewards. The rewards will be transferred to the account.

```
// check you have rewards to claim:
sfcc.pendingRewards("0xAddress", validatorID) // returns: rewards amount
// claim rewards:
sfcc.claimRewards(validatorID, {from: "0xAddress"})
```

**Checks**

* Delegation `pendingRewards` is greater than zero

### Restake rewards

Restake earned rewards. Rewards will be added to the stake amount.

If a part of the reward received for locked up stake, then this reward will be added to the `locked stake`.

```
// check you have rewards to claim:
sfcc.pendingRewards("0xAddress", validatorID) // returns: rewards amount
// restake rewards:
sfcc.restakeRewards(validatorID, {from: "0xAddress"})
```

**Checks**

* Delegation `pendingRewards` is greater than zero
* `Validator's stake` is less or equal to `15.0` \* `validator's self-stake`

### Transfer rewards

Transfer your VC to another wallet

```
vc.sendTransaction({from: vc.accounts[0], 
to: "target_address", 
value: web3.toWei("AMOUNT", "VC")})
```

* Change `AMOUNT` to the number of VC you wish to transfer.
