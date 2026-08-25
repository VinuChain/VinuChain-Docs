# VinuChain Mainnet

VinuChain mainnet is the production network (chain ID `207`). This section covers
connecting a wallet to mainnet and running mainnet nodes.

{% hint style="danger" %}
**Scheduled upgrade — 29 August 2026, 10:00 UTC.** Mainnet begins its move to
testnet's target feature set: the **ELEMONT** release activates SfcV2, Shanghai, Cancun,
Prague (EIP-7702 set-code transactions), the Elemont consensus fixes, the
BLS12-381 and latest-EVM precompiles, and PaybackV2. The binary also adds
`vc_getPaybackBalance` and `eth_config`/`vc_config`; core `vc_*` RPC methods are
already live.

**Node operators must upgrade in that window** — this is a consensus upgrade.
See the [Mainnet Upgrade Guide (ELEMONT)](./chain-upgrade-guide.md); pre-flight
checks need lead time, especially transaction-index recovery. Container
deployments also require their coordinator-approved image/deployment runbook.

**Fee-refund stakers must migrate** to a new Payback contract —
see [the migration steps](./elemont-upgrade.md#if-you-stake-in-the-payback-fee-refund-contract).

Until that upgrade activates, mainnet runs the pre-ELEMONT rule set (`Berlin`,
`London`, `Llr`, `Podgorica`) on the V1 staking contract.
{% endhint %}

For the full ELEMONT feature set, user actions, and RPC availability,
see [VinuChain ELEMONT Upgrade](./elemont-upgrade.md).

For all chain IDs, RPC endpoints, and explorer URLs in one place, see
[Network Details](../network-details.md).
