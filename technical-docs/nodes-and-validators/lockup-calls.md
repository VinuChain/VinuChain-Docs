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

In the SFC this is `lockupExtraReward + lockupBaseReward / 2`, taken from `getStashedLockupRewards(delegator, validatorID)` and scaled by `amount / lockedStake` for a partial unlock. The penalty is removed from your stake (`_rawUndelegate`) and counted in `totalPenalty`.

{% hint style="warning" %}
`getStashedLockupRewards` accumulates for the **whole lockup** and is **not reduced by `claimRewards`**. Rewards you already claimed or restaked still count towards the penalty. The contract gives no discount for the time remaining: the penalty is charged on all rewards accumulated up to the unlock, and it is capped only at the amount being unlocked, so your staked balance can drop below the amount you originally delegated. Together with the rewards you received you still end up with at least your original stake.
{% endhint %}

Read the exact penalty before unlocking. `unlockStake` first stashes any pending epochs and only then calculates the penalty, so bring the stash up to date first, otherwise the numbers below can be too low:

```
// 1. Stash pending rewards. Each call advances at most 100 epochs; repeat until the cursor is current.
//    (stashRewards reverts with "nothing to stash" once it is already current.)
sfcc.stashRewards("0xAddress", validatorID, {from: "0xAddress"})
sfcc.stashedRewardsUntilEpoch("0xAddress", validatorID)   // must equal sfcc.currentSealedEpoch()

// 2. Read the stash and the lockup
var s = sfcc.getStashedLockupRewards("0xAddress", validatorID)  // [lockupExtraReward, lockupBaseReward, unlockedReward]
var lock = sfcc.getLockupInfo("0xAddress", validatorID)         // [lockedStake, fromEpoch, endTime, duration]
// penalty for unlocking `amount` = (s[0] + s[1] / 2) * amount / lock[0]
// Unlocking is penalty-free once the current time is past lock[2] (endTime)
```

```
sfcc.unlockStake(validatorID, web3.toWei("amount", "vc"), {from: "0xAddress"})
```

**Checks**

* Amount is greater than zero
* Amount is smaller or equal to `locked stake`
* Delegation is locked up (fully or partially)
