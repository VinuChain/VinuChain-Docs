# VinuChain Coin (VC)

### 7.1 Overview

The VinuChain Coin (VC) is both the governance and gas coin of the VinuChain Protocol.

VC is both inflationary and deflationary.

* Inflationary: A VC reward is issued to Validators for each new block.
* Deflationary: 30% of every gas fee (paid as VC) is burned.

### 7.2 Initial Distribution

At TGE, there will be 1,000,000,000 VC total supply, allocated as follows:

* 50% - Ecosystem Development (e.g. user rewards, developer grants, etc.)
* 25% - Project Development (e.g. marketing, developer costs, etc.)
* 9% - Foundation Allocation (i.e. Vinu Foundation)
* 10% - Private Allocation
* 5% - Public Allocation
* 1% - Airdrop

However, circulating supply at TGE will be 82,500,000 VC (8.25% of total supply).

_VC will be unlocked slowly over time as per the following chart:_

<figure><img src="../../.gitbook/assets/image (7).png" alt=""><figcaption></figcaption></figure>

There is no maximum supply, as each new block issues a small amount of new VC to incentivise Validators to secure the network (which may be offset by the VC burned from every gas fee).

### 7.3 Gas Fees

The gas fees (denominated in VC) within each validated block on VinuChain are distributed as follows:

1. 70% VC to Validators
2. 30% VC Burned

Users who stake to receive feeless transactions receive their eligible gas costs back per epoch, via the Payback fee-refund system.

{% hint style="info" %}
**Implementation note — fee-refund timing.**
The original whitepaper described a 24-hour cash-back window. The live
implementation uses the **epoch-based Payback** model: stakers accrue a
refund quota each epoch (proportional to their share of total stake), and
the refund is applied in-protocol as a `feeRefund` on the transaction receipt
rather than from a separate pool. Refunds are suppressed when the EIP-1559
base fee is above its configured floor (congestion guard). See the
[Feeless Transactions](../../technical-docs/smart-contracts/feeless-transactions.md)
page for current parameters (mainnet Quota proxy
`0x5d989a2d65d049e2198d91d8ddc31c918f2544ab`, minStake 10 VC).
{% endhint %}

<br>

