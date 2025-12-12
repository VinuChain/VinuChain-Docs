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
* `Validator's stake` is less or equal to `15.0` \* `validator's self-stake`

## Undelegate

Undelegate begins the unstaking process.

Your VC will first need to be unlocked before you can Undelegate.\
See [lockup-calls.md](lockup-calls.md "mention") for details on how to unlock.

Once you Undelegate, the withdrawal period (required time before you can withdraw) begins.

At the end of the withdrawal period, you will then be able to call the `withdraw` command successfully.

Set the `requestID` to any number which you have not assigned previously.

* The `requestID` you use here is what you reference later in the `withdraw` function to Withdraw that specific Undelegate request.
  * For example, if you Undelegate 200,000 VC using `requestID` 0, then to withdraw this 200,000 you will need to use `requestID` 0 in the `withdraw` command.
* If you leave `requestID` blank, it will automatically assign the next unused value starting from 0. So you will need to count (with the first being 0) how many Undelegate requests you have done to determine which `requestID` you need to use for the `withdraw` command.

**Undelegate Command:**

```
sfcc.undelegate(validatorID, requestID, web3.toWei("amount", "vc"), {from: "0xAddress"})
```

**Checks**

* Amount is greater than zero
* Delegation's `unlocked stake` is greater or equal to the amount to undelegate
* `requestID` isn't occupied by an existing withdrawal request for this delegation
* If called for validator's self-delegation, then the following stays true after the operation: either `validator's stake` is less or equal to `15.0` \* `validator's self-stake` or the `self-stake` is `0`

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
