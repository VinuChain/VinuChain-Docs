---
description: Stake on VinuChain
---

# Stake VC on VinuChain

## Stake on VinuChain

VinuChain uses a proof-of-stake consensus algorithm to validate transactions and secure the network. You can participate by staking your VC. In exchange, you are rewarded with VC tokens or zero gas transactions.

To stake, you do not need any dedicated special hardware or device. You can do it directly from your phone or PC. While staking means locking up your tokens, they are still in your wallet and only you have access to them. You can unlock your funds at any time.

## Staking parameters <a href="#staking-parameters" id="staking-parameters"></a>

* Minimum amount: 0.01 VC (the SFC's `minDelegation()`).
* Minimum lock-up period: none required - unlocked stake earns the base reward rate. If you do lock up, the SFC requires a duration of at least 14 days.
* Maximum lock-up period: 365 days, earning the maximum reward rate.
* Unbonding time (time between unstaking and funds becoming available): 1 day and 6 epochs (both must elapse).
* Delegation fee: The network has set a fixed fee of 15% on staking rewards paid from stakers to validators for running their nodes.
* Payback: There is a separate staking option where you instead receive gas fee refunds on a number of transactions.
* Payback minimum stake: The refunding wallet must meet the Payback contract's current `minStake()` before any gas refunds are available. The active Payback contract is the address returned as `Economy.QuotaCacheAddress` by `vc_getRules`: mainnet PaybackV2 `0x5D989A2d65d049e2198D91d8ddc31C918f2544AB` with `minStake() = 10 VC`, testnet PaybackV2 `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4` with `minStake() = 1000 VC`. The Quota owner can update this parameter with `setMinStake(uint256)`. Stake left on the retired mainnet V1 Quota proxy `0x1c4269fBBD4a8254F69383eeF6aF720bCD0aCda6` no longer earns fee refunds. Below the current minimum, transactions still pay normal gas and show `feeRefund: 0x0`.
* Payback receiver staking (PaybackV2, mainnet and testnet): A funding wallet can call `stakeFor(receiver)` to stake VC for another receiver wallet. The receiver wallet receives Payback quota credit and gas refunds for transactions it signs, but only after the receiver wallet's total Payback stake reaches `minStake()`. The funding wallet keeps ownership of the VC it funded and must use `unstakeFor(receiver, amount)` to begin withdrawing that stake back to itself; the receiver has no claim to third-party-funded stake.
* Payback quota: The minimum stake is only an eligibility floor. Every refunded transaction consumes the sender wallet's available Payback quota for the epoch; when that quota is exhausted, later transactions still pay normal gas and receive a partial refund or `feeRefund: 0x0` until quota accrues again. When network congestion pushes the base fee above the chain-configured floor, Payback refunds are suppressed so fee escalation can still deter spam.

> Delegation fee example:&#x20;
>
> Assuming you earn 6.00% on a stake of 1,000,000 VC, you'll receive 1,000,000 \* 0.06 \* (1-0.15) = 51000 VC  per year.

## How to Stake <a href="#how-to-stake" id="how-to-stake"></a>

You can stake on the [VinuChain staking app](https://vinuchain.org/staking).

### Reading epoch data <a href="#reading-epoch-data" id="reading-epoch-data"></a>

The per-epoch values in the formulas below (`epochDuration`, `totalBaseRewardWeight`) come from
the epoch snapshot held on-chain by the SFC staking contract at
`0xFC00FACE00000000000000000000000000000000`. Read the current epoch number first, then that
epoch's snapshot:

```bash
# current epoch
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_currentEpoch","params":[],"id":1}'

# snapshot for a sealed epoch (replace the padded epoch number)
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"0xFC00FACE00000000000000000000000000000000","data":"0x39b80c000000000000000000000000000000000000000000000000000000000000001e91"},"latest"],"id":1}'
```

`getEpochSnapshot(uint256)` (selector `0x39b80c00`) returns the epoch's end time, fee, and
`totalBaseRewardWeight`. Query a **sealed** epoch (one below the current one) — the in-progress
epoch has no final snapshot yet. A mainnet epoch seals at most every 4 hours.

## How Staking Rewards are Calculated <a href="#how-staking-rewards-are-calculated" id="how-staking-rewards-are-calculated"></a>

### Validators

Validators receive a **base reward** and **15% of delegator rewards** per epoch.

* If a validator stake is locked, it receives 100% of the base reward.
* If a validator stake is unlocked, it only receives 30% of the base reward.
  * `validatorStake` = the amount you have staked.
  * `epochDuration` = the epoch duration in seconds _(an epoch is approximately 4 hours / 14,400 seconds)._
  * `validatorEpochUptime` _=_ the epoch duration in seconds _(if validator was online for 100% of the time, otherwise pro-rata it)._
  * `baseRewardPerSecond` = 0.75.
  * `totalBaseRewardWeight` = a field in that epoch's on-chain snapshot — see [Reading epoch data](#reading-epoch-data).
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
  * `epochDuration` = the epoch duration in seconds _(an epoch is approximately 4 hours / 14,400 seconds)._
  * `validatorEpochUptime` _=_ the epoch duration in seconds _(if validator was online for 100% of the time, otherwise pro-rata it)._
  * `baseRewardPerSecond` = 0.75.
  * `totalBaseRewardWeight` = a field in that epoch's on-chain snapshot — see [Reading epoch data](#reading-epoch-data).

```
Total Delegator Reward = Delegator Reward + Delegator Fees

Delegator Reward per epoch (locked stake):
delegator_BaseReward = (epochDuration * baseRewardPerSecond) * [(delegatorStake * (validatorEpochUptime/epochDuration)^2) / totalBaseRewardWeight] * (1 - 0.15)

Delegator Reward per epoch (unlocked stake):
delegator_BaseReward = (epochDuration * baseRewardPerSecond) * [(delegatorStake * (validatorEpochUptime/epochDuration)^2) / totalBaseRewardWeight] * 0.30 * (1 - 0.15)
```
