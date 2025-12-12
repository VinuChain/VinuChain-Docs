---
description: Stake on VinuChain
---

# Stake VC on VinuChain

## Stake on VinuChain

VinuChain uses a proof-of-stake consensus algorithm to validate transactions and secure the network. You can participate by staking your VC. In exchange, you are rewarded with VC tokens or zero gas transactions.

To stake, you do not need any dedicated special hardware or device. You can do it directly from your phone or PC. While staking means locking up your tokens, they are still in your wallet and only you have access to them. You can unlock your funds at any time.

## Staking parameters <a href="#staking-parameters" id="staking-parameters"></a>

* Minimum amount: 1 VC.
* Minimum lock-up period: 0 days, earning the base reward rate.
* Maximum lock-up period: 365 days, earning the maximum reward rate.
* Unbonding time (time between unstaking and funds becoming available): 1 day.
* Delegation fee: The network has set a fixed fee of 15% on staking rewards paid from stakers to validators for running their nodes.
* Payback: There is a separate staking option where you instead receive gas fee refunds on a number of transactions.

> Delegation fee example:&#x20;
>
> Assuming you earn 6.00% on a stake of 1,000,000 VC, you'll receive 1,000,000 \* 0.06 \* (1-0.15) = 51000 VC  per year.

## How to Stake <a href="#staking-parameters" id="staking-parameters"></a>

You can stake on [VinuScan](https://mainnet.vinuscan.com/staking).

## How Staking Rewards are Calculated <a href="#staking-parameters" id="staking-parameters"></a>

### Validators

Validators receive a **base reward** and **15% of delegator rewards** per epoch.

* If a validator stake is locked, it receives 100% of the base reward.
* If a validator stake is unlocked, it only receives 30% of the base reward.
  * `validatorStake` = the amount you have staked.
  * `epochDuration` = [Epoch Duration](https://mainnet.vinuscan.com/epochs) in seconds _(an epoch is approximately 4 hours / 14,400 seconds)._
  * `validatorEpochUptime` _=_ [Epoch Duration](https://mainnet.vinuscan.com/epochs) in seconds _(if validator was online for 100% of the time, otherwise pro-rata it)._
  * `baseRewardPerSecond` = 0.75.
  * `totalBaseRewardWeight` = a field found within each [Epoch](https://mainnet.vinuscan.com/epochs).
  * `delegatorStake` = the amount delegated to the validator excluding its own stake.

```
Total Validator Reward = Validator Reward + Delegator Fees

Validator Reward per epoch (locked stake):
validator_BaseReward = (epochDuration * baseRewardPerSecond) * [(validatorStake * (validatorEpochUptime/epochDuration)^2) / totalBaseRewardWeight]

Validator Reward per epoch (unlocked stake):
validator_BaseReward = (epochDuration * baseRewardPerSecond) * [(validatorStake * (validatorEpochUptime/epochDuration)^2) / totalBaseRewardWeight] * 0.30

Delegator Fee per epoch (gets paid to Validator):
delegator_Fee = (epochDuration * baseRewardPerSecond) * [(delegatorStake * (validatorEpochUptime/epochDuration)^2) / totalBaseRewardWeight] * 0.15
```

### Delegators

Delegators receive a **base reward** **less** **15% fee sent to the validator** per epoch.

* If a delegator stake is locked, it receives 85% _(100% - 15%)_ of the base reward per epoch.
* If a delegator stake is unlocked, it receives 25.5% _(30% x (100%-15%))_ of the base reward per epoch.
  * `delegatorStake` = the amount you have staked as a delegator.
  * `epochDuration` = [Epoch Duration](https://mainnet.vinuscan.com/epochs) in seconds _(an epoch is approximately 4 hours / 14,400 seconds)._
  * `validatorEpochUptime` _=_ [Epoch Duration](https://mainnet.vinuscan.com/epochs) in seconds _(if validator was online for 100% of the time, otherwise pro-rata it)._
  * `baseRewardPerSecond` = 0.75.
  * `totalBaseRewardWeight` = a field found within each [Epoch](https://mainnet.vinuscan.com/epochs).

```
Total Delegator Reward = Delegator Reward + Delegator Fees

Delegator Reward per epoch (locked stake):
delegator_BaseReward = (epochDuration * baseRewardPerSecond) * [(delegatorStake * (validatorEpochUptime/epochDuration)^2) / totalBaseRewardWeight] * (1 - 0.15)

Delegator Reward per epoch (unlocked stake):
delegator_BaseReward = (epochDuration * baseRewardPerSecond) * [(delegatorStake * (validatorEpochUptime/epochDuration)^2) / totalBaseRewardWeight] * 0.30 * (1 - 0.15)
```

