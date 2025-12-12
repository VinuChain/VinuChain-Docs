---
description: Stake lockup calls reference
---

# Lockup Calls

### Lock up stake

Reward for a non-locked stake is 30% (base rate) of the full reward for a locked stake.

* Minimum lock-up period is 14 days.

Note that validator's stake must be locked up before validator's delegations can lock their stake. The specified lockup period of a delegation must not exceed the validator's current lockup period.

Delegation can be locked partially according to the specified amount.

`lockupDuration` is lockup duration in **seconds**. Must be >= 14 days, <= 365 days

**Example:**

* **To lock up for 14 days, `lockupDuration` = 86400 x 14 = 1209600**

`lockupDuration` proportionally increases `lockup rate` for rewards.&#x20;

* For 14 days, rewards are `30%+2.684931%` of the total reward rate.&#x20;
* For 365 days, rewards are `30%+70%` of the total reward rate.
  * _`(30% + (0.00191780785714286 * Days))`_

```
sfcc.lockStake(validatorID, lockupDuration, web3.toWei("amount", "vc"), {from: "0xAddress"})
```

**Checks**

* Amount is smaller or equal to `unlocked stake`
* Previous lockup period (if any) must end before the new period starts.
* `lockupDuration` >= 14 days
* `lockupDuration` <= 365 days
* Validator's lockup period must end after delegation's lockup period will expire
* Validator is active

**Min/Max**

```
#Minimum
function minLockupDuration() public pure returns (uint256) {return 86400 * 14;}

#Maximum
function maxLockupDuration() public pure returns (uint256) {return 86400 * 365;}
```

### Re-lock stake

Extend lockup period or increase lockup up stake.

If user is already lockup up, the call will create a new lockup entry with parameters: lockedStake=`prevLockedStake+amount` and lockup duration=`newLockupDuration`.

**It is denominated in seconds. For a 365 days re-lock, you would input 31536000.**

Example:

1. Alice had locked up 10 VC for 3 months a month ago, and she has to wait 2 months until lockup expiration
2. She called relockStake(validatorID, 4 months, 5 VC)
3. As a result, now she has 15 VC as locked up, and she has to wait 4 months until lockup expiration (2 months longer, despite new lockup duration being only 1 month longer)

```
sfcc.relockStake(validatorID, newLockupDuration, web3.toWei("amount", "vc"), {from: "0xAddress"})
```

**Checks**

* Amount is smaller or equal to `unlocked stake`
* `lockupDuration` >= `previous lockupDuration` (if locked up). Note that `previous lockupDuration` is not `locked time remaining` but `lockup duration` of existing lockup.
* `lockupDuration` >= 14 days
* `lockupDuration` <= 365 days
* Validator's lockup period must end not earlier than delegation's lockup period will expire
* Validator is active

### Unlock stake prematurely

Unlock the stake before lockup duration has elapsed.

The following penalty will be withheld from the unlocked amount:

* `(base rate = 30%)/2 + lockup rate` of rewards received for epochs during the lockup period

```
sfcc.unlockStake(validatorID, web3.toWei("amount", "vc"), {from: "0xAddress"})
```

**Checks**

* Amount is greater than zero
* Amount is smaller or equal to `locked stake`
* Delegation is locked up (fully or partially)
