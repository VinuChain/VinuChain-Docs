# Overview

## Overview

There are two ways a user can stake their VC on VinuChain:

1. **Stake for APY (delegating).**
2. **Stake for Payback (zero gas fee transactions).**

A user can separately stake for both options if they wish, or just one, on [VinuScan](https://mainnet.vinuscan.com/staking).

### Stake for APY (Delegating)

When a user stakes for APY, they are delegating their VC to a validator to earn a portion of block rewards. In exchange, the validator receives 15% of the staker's rewards.

VinuChain uses a **fluid staking** model where stakers either can stake without a lock-up period for the minimum APR or select a lock-up period between 14 to 365 days for an increased APR.

The rewards percentage increases linearly with time, rewarding the most committed stakers more. This way, the reward schedule combines long-term sustainability for the network and flexibility for stakers.

> Example:&#x20;
>
> Assuming you earn 6.00% on a stake of 1,000,000 VC, you'll receive 1,000,000 \* 0.06 \* (1-0.15) = 51000 VC  per year.

### Stake for Payback (zero gas fee transactions)

When a user stakes for Payback, they are staking VC to be able to have their gas fees refunded for a number of transactions.

The Payback quota is dynamic to counteract spam:

* The more VC staked for Payback by a single user, the more gas fee refunds that user will be entitled to.
* The more VC staked for Payback in total from all users combined, the less gas fee refunds each user will be entitled to.

The Payback initiative allows VinuChain to offer the advantage of zero fee transactions to willing users.

<figure><img src="../../.gitbook/assets/image (13).png" alt=""><figcaption></figcaption></figure>

## Rewards <a href="#rewards" id="rewards"></a>

In the fluid staking model, your effective APR:

* Increases proportionally with your lock-up period.
* Decreases proportionally with the average lock-up period of all stakers.
* Decreases proportionally with the total amount of VC staked by all stakers.

### How to receive rewards <a href="#how-to-receive-rewards" id="how-to-receive-rewards"></a>

There are two ways to participate in staking

* [Delegate to a Validator](https://vinu.gitbook.io/vinuchain/technical-docs/staking/stake-vc-on-vinuchain)
* [Run a Validator Node](https://vinu.gitbook.io/vinuchain/technical-docs/nodes-and-validators/become-a-validator)

| Comparison           | Delegation                                             | Validator Node                                          |
| -------------------- | ------------------------------------------------------ | ------------------------------------------------------- |
| Passive              | +                                                      | -                                                       |
| Minimum requirements | 1 VC                                                   | 200,000 VC                                              |
| Needed expertise     | None                                                   | DevOps                                                  |
| Rewards              | Staking rewards minus a 15% fee to delegated validator | Staking rewards plus a 15% fee from delegators' rewards |

[Running a validator node](https://vinu.gitbook.io/vinuchain/technical-docs/nodes-and-validators/become-a-validator) earns more rewards but requires active management and DevOps experience.
