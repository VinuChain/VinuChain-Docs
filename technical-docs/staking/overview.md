# Overview

## Overview

There are two ways a user can stake their VC on VinuChain:

1. **Stake for APY (delegating).**
2. **Stake for Payback (zero gas fee transactions).**

A user can separately stake for both options if they wish, or just one, on the [VinuChain staking app](https://vinuchain.org/staking).

### Stake for APY (Delegating)

When a user stakes for APY, they are delegating their VC to a validator to earn a portion of block rewards. In exchange, the validator receives 15% of the staker's rewards.

VinuChain uses a **fluid staking** model where stakers either can stake without a lock-up period for the minimum APR or select a lock-up period between 14 to 365 days for an increased APR.

The rewards percentage increases linearly with time, rewarding the most committed stakers more. This way, the reward schedule combines long-term sustainability for the network and flexibility for stakers.

> Example:&#x20;
>
> Assuming you earn 6.00% on a stake of 1,000,000 VC, you'll receive 1,000,000 \* 0.06 \* (1-0.15) = 51000 VC  per year.

### Stake for Payback (zero gas fee transactions)

When a user stakes for Payback, they are staking VC to have their gas fees refunded for a number of transactions. The refunding wallet must meet the Payback contract's current `minStake()` before refunds are available. The active Payback contract is always the address returned as `Economy.QuotaCacheAddress` by `vc_getRules`. On mainnet that is PaybackV2 at `0x5D989A2d65d049e2198D91d8ddc31C918f2544AB`, with `minStake() = 10 VC`; on testnet it is PaybackV2 at `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4`, with `minStake() = 1000 VC`. The retired mainnet V1 Quota proxy (`0x1c4269fBBD4a8254F69383eeF6aF720bCD0aCda6`) is no longer the active Payback contract: stake left there stays withdrawable but no longer earns fee refunds. Below the current minimum, transactions still pay normal gas and show `feeRefund: 0x0`.

On mainnet and testnet (PaybackV2), VinuChain supports staking VC from one
funding wallet for another receiver wallet via `stakeFor(receiver)`. The
receiver wallet receives Payback quota credit and gas refunds for transactions
it signs once the receiver wallet's total Payback stake reaches `minStake()`.
The funding wallet keeps ownership of the VC it funded and must use
`unstakeFor(receiver, amount)` to begin withdrawing that stake back to itself;
the receiver has no claim to third-party-funded stake.

The Payback quota is dynamic to counteract spam:

* The more VC staked for Payback by a single user, the more gas fee refunds that user will be entitled to.
* The more VC staked for Payback in total from all users combined, the less gas fee refunds each user will be entitled to.
* The minimum stake is only an eligibility floor, not a spam throttle that grows automatically. Each refunded transaction consumes that wallet's available Payback quota for the epoch; once the wallet's quota is exhausted, later transactions still pay normal gas and receive a partial refund or `feeRefund: 0x0` until quota accrues again.
* When network congestion pushes the base fee above the chain-configured floor, Payback refunds are suppressed so fee escalation can still deter spam.

The Payback initiative allows VinuChain to offer the advantage of zero fee transactions to willing users.

<figure><img src="../../.gitbook/assets/image (13).png" alt=""><figcaption></figcaption></figure>

## Rewards <a href="#rewards" id="rewards"></a>

In the fluid staking model, your effective APR:

* Increases proportionally with your lock-up period.
* Decreases proportionally with the average lock-up period of all stakers.
* Decreases proportionally with the total amount of VC staked by all stakers.

### How to receive rewards <a href="#how-to-receive-rewards" id="how-to-receive-rewards"></a>

There are two ways to participate in staking

* [Delegate to a Validator](./stake-vc-on-vinuchain.md)
* [Run a Validator Node](../nodes-and-validators/become-a-validator.md)

| Comparison           | Delegation                                             | Validator Node                                          |
| -------------------- | ------------------------------------------------------ | ------------------------------------------------------- |
| Passive              | +                                                      | -                                                       |
| Minimum requirements | 0.01 VC                                                | 200,000 VC                                              |
| Needed expertise     | None                                                   | DevOps                                                  |
| Rewards              | Staking rewards minus a 15% fee to delegated validator | Staking rewards plus a 15% fee from delegators' rewards |

[Running a validator node](../nodes-and-validators/become-a-validator.md) earns more rewards but requires active management and DevOps experience.
