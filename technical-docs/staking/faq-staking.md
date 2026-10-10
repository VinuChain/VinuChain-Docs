# FAQ - Staking

## FAQ - Staking

### How are staking rewards generated? <a href="#how-are-staking-rewards-generated" id="how-are-staking-rewards-generated"></a>

The Staking Rewards on VinuChain consist of both network rewards and fees:

* **Inflation on the VinuChain Network (Block Rewards):** The VinuChain network emits 0.75 VC per second. The Block rewards are distributed after each epoch (the epoch gas cap of 1,500,000,000 gas is reached, or 4 hours have elapsed since the previous epoch, whichever occurs first). Block rewards are distributed to validators and consequently shared amongst delegators. This implies that VC holders who choose not to stake will get diluted over time.
* **Transaction Fees:** Each transaction processed by the network comes with transaction fees. 30% of transaction fees are burned. The remaining 70% of transaction fees are distributed between validators proportional to their transactions reward weight. The Staking APR will vary with network usage, as the network gets busier the APR will rise and vice versa.

Please note that the total annual rewards are divided by all active stakers; hence, as the amount of staked tokens goes up, the reward rate goes down.

### How are Staking Rewards Calculated? <a href="#how-are-staking-rewards-calculated" id="how-are-staking-rewards-calculated"></a>

[How are staking rewards calculated?](./stake-vc-on-vinuchain.md#how-staking-rewards-are-calculated)

### Can others access my staked tokens? <a href="#can-others-access-my-staked-tokens" id="can-others-access-my-staked-tokens"></a>

No. Assuming no one else has access to your private key or seed phrase, nobody except you will have access to your tokens. Make sure not to share nor lose your seed phrase or private key.

### **Can I lose my tokens when staking?** <a href="#can-i-lose-my-tokens-when-staking" id="can-i-lose-my-tokens-when-staking"></a>

If you stake to a validator node that acts maliciously, **you could lose all your staked tokens**. You must choose the validator node wisely and make sure they are reputable. Slashing delegators as well, instead of only validators, is an essential part of network security. It makes it costly for a set of bad actors to take over the majority of the network.

### **How do I choose a reputable validator?** <a href="#how-do-i-choose-a-reputable-validator" id="how-do-i-choose-a-reputable-validator"></a>

Most validators for VinuChain have active communities, websites, and Twitter accounts. Do your own research and ask around in the community as they will be able to help you.

### **Can a validator run away with my funds?** <a href="#can-a-validator-run-away-with-my-funds" id="can-a-validator-run-away-with-my-funds"></a>

No. In any case, a validator does not have access to any other tokens than their own. However, if a validator acts maliciously, all the funds staked to that node can be lost.

### **What happens if a validator goes offline?** <a href="#what-happens-if-a-validator-goes-offline" id="what-happens-if-a-validator-goes-offline"></a>

If a validator node goes offline, it stops receiving rewards since it is not helping secure the network anymore. When it comes back online, the rewards resume.

### **Can I withdraw my delegation if a node goes offline?** <a href="#can-i-withdraw-my-delegation-if-a-node-goes-offline" id="can-i-withdraw-my-delegation-if-a-node-goes-offline"></a>

Yes, you can.

### **Can I re-stake or increase my delegation?** <a href="#can-i-re-stake-or-increase-my-delegation" id="can-i-re-stake-or-increase-my-delegation"></a>

Yes. This is possible through the [VinuChain staking app](https://vinuchain.org/staking).

### **Can I unlock my delegation before the lock-up period ends?** <a href="#can-i-unlock-my-delegation-before-the-lock-up-period-ends" id="can-i-unlock-my-delegation-before-the-lock-up-period-ends"></a>

Yes, but you pay a penalty. The penalty is calculated from the lock-up rewards you have earned **since the lock began**, including rewards you have already claimed or restaked. The contract does not give a discount for the time remaining on the lock: the penalty is charged on all rewards accumulated up to the moment you unlock. Rewards keep accumulating while you wait, so the penalty grows the longer the lock has been running, and the full amount applies even if you are only a few hours from the end. Once the lock-up has ended, there is no penalty.

The penalty is the lock-up bonus plus half of the base reward. As a share of your total lock-up rewards it depends on the lock duration. For a lock whose duration has not changed: `(15% + bonus) / (30% + bonus)`, where the bonus is `70% × lock duration / 365 days`. It is about **54%** for a 14-day lock, about **77%** for a 180-day lock, and about **85%** for a lock of roughly one year. If you re-locked with a different duration, rewards earned under the earlier duration are still counted at their own rate, so the share is a mix of the old and new rates; to get your exact share, divide `lockupExtraReward + lockupBaseReward / 2` by `lockupExtraReward + lockupBaseReward` from `getStashedLockupRewards`. The penalty is taken from your staked balance and permanently removed. It is not refundable and is not paid to anyone.

Because rewards you have already claimed are not given back, an early unlock can leave your staked balance **below the amount you originally delegated**. The rewards you were paid still count in your favour: your remaining stake plus all the rewards you have received is normally still more than you delegated, by the part of the rewards that the penalty does not take (about 15% for a one-year lock). If you claim rewards regularly, the penalty therefore removes roughly the rewards you have already taken out of your stake.

**Example:** you lock 250,000 VC for about 362 days and earn about 74,000 VC in rewards. You claim about 72,000 VC to your wallet and restake about 2,000 VC, so your stake is about 252,000 VC. If you unlock early, the penalty is about 63,000 VC (85% of 74,000) and about 189,000 VC remains staked. You hold about 189,000 VC of stake plus the 72,000 VC you claimed, which is about 261,000 VC, or about 11,000 VC more than the 250,000 VC you started with. If you wait until the lock-up has ended, there is no penalty.

{% hint style="warning" %}
Check the lock-up end date before you unlock. Unlocking even a few hours early applies the penalty on all rewards earned so far. See [`unlockStake`](../nodes-and-validators/lockup-calls.md#unlock-stake-prematurely) for how to read the exact penalty on-chain before sending the transaction.
{% endhint %}
