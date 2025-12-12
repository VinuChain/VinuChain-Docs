---
description: Validator calls reference
---

# Validator Calls

### Create validator

Create a new validator

Current minimum stake is `sfcc.minSelfStake()`

`pubkey` is a public key used to authenticate future validator's consensus messages. `pubkey` cannot be changed after the call

The call creates a self-delegation with the specified amount. Validator uses the same calls as other delegators. Visit [delegation calls](https://vita-inu.gitbook.io/vinuchain/technical-guides/validators-nodes/delegation-calls), [reward calls](https://vita-inu.gitbook.io/vinuchain/technical-guides/validators-nodes/reward-calls), [stake lockup calls](https://vita-inu.gitbook.io/vinuchain/technical-guides/validators-nodes/stake-lockup-calls) for additional details.

```
sfcc.createValidator("0xPubkey", {from:"0xAddress", value: web3.toWei("amount", "vc")})
```

#### **Checks**

* Self-stake amount is greater or equal to `sfcc.minSelfStake()`
* This address wasn't used for other validator
* `pubkey` is not empty
