---
description: Delegating VC to Validators calls reference
---

# Delegation Calls

## Delegate

Delegate (stake) an amount of VC to a validator.

Can be used to create a new delegation or increase an existing delegation.

The delegated stake is always unlocked unless locked explicitly with `lockStake`.

```
sfcc.delegate(validatorID, {from: "0xAddress", value: web3.toWei("amount", "vc")})
```

**Checks**

* Validator must exist
* Validator is active
* Amount is greater than zero
* `Validator's stake` is less or equal to `16.0` \* `validator's self-stake` (i.e. delegations may total up to 15x the self-stake on top of it)

## Undelegate

Undelegate begins the unstaking process.

Your VC will first need to be unlocked before you can Undelegate.\
See [lockup-calls.md](lockup-calls.md "mention") for details on how to unlock.

Once you Undelegate, the withdrawal period (required time before you can withdraw) begins.

At the end of the withdrawal period, you will then be able to call the `withdraw` command successfully.

The SFC assigns the `requestID` (wrID) itself — you do not choose it. `undelegate` takes only the validator ID and the amount.

* After the transaction confirms, read the wrID from the `Undelegated(delegator, toValidatorID, wrID, amount)` event in the receipt. All three of `delegator`, `toValidatorID` and `wrID` are indexed, so the wrID is the third indexed topic (`topics[3]`). That is the value you pass to `withdraw`.
* You can also list your open requests with `sfcc.getWrRequests(delegator_address, validatorID, offset, limit)`, which returns `(epoch, time, amount)` entries indexed by wrID starting at `offset`.

**Undelegate Command:**

```
sfcc.undelegate(validatorID, web3.toWei("amount", "vc"), {from: "0xAddress"})
```

**Checks**

* Amount is greater than zero
* Delegation's `unlocked stake` is greater or equal to the amount to undelegate
* If called for validator's self-delegation, then the following stays true after the operation: either `validator's stake` is less or equal to `16.0` \* `validator's self-stake` or the `self-stake` is `0`

Withdrawal period in seconds and epochs can be retrieved via:

```
sfcc.withdrawalPeriodTime()
sfcc.withdrawalPeriodEpochs()
```

You can retrieve a `requestID` via:&#x20;

```
sfcc.getWrRequests(delegator_address, validatorID, offset, limit)
```

## Withdraw

Finalize withdrawal request.

Erases request object and withdraws requested stake, transfers requested stake to account address.

Note that a number of seconds and epochs must elapse since `undelegate` call (called withdrawal period).

If validator is a cheater (i.e. double-signed), then the stake may be fully or partially slashed according to validator's `slashingRefundRatio`.

```
sfcc.withdraw(validatorID, requestID, {from: "0xAddress"})
```

**Checks**

* Withdrawal request with given address, validator ID and requestID exists
* At least `sfcc.withdrawalPeriodTime()` seconds passed since `undelegate` call
* At least `sfcc.withdrawalPeriodEpochs()` epochs passed since `undelegate` call
* Non-slashed part of stake is above zero
