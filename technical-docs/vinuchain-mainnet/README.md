# VinuChain Mainnet

VinuChain mainnet is the production network (chain ID `207`). This section covers
connecting a wallet to mainnet and running mainnet nodes.

{% hint style="danger" %}
**Scheduled upgrade — 29 August 2026, 10:00 UTC.** Mainnet is being brought to full
parity with testnet: the **ELEMONT** release activates SfcV2, Shanghai, Cancun,
Prague (EIP-7702 set-code transactions), the Elemont consensus fixes, the
BLS12-381 and latest-EVM precompiles, and PaybackV2 — along with the `vc_*` RPC
namespace, `vc_getPaybackBalance`, and `eth_config`/`vc_config`.

**Node operators must upgrade in that window** — this is a consensus upgrade.
See the [Mainnet Upgrade Guide (ELEMONT)](./chain-upgrade-guide.md); two pre-flight
items need days of lead time.

**Fee-refund stakers must migrate** to a new Payback contract —
see [the migration steps](./chain-upgrade-guide.md#if-you-stake-in-the-payback-fee-refund-contract).

Until that upgrade activates, mainnet runs the pre-ELEMONT rule set (`Berlin`,
`London`, `Llr`, `Podgorica`) on the V1 staking contract.
{% endhint %}

For the full ELEMONT feature set, operator prerequisites, and new RPC surface,
see [VinuChain ELEMONT Upgrade](./elemont-upgrade.md).

For all chain IDs, RPC endpoints, and explorer URLs in one place, see
[Network Details](../network-details.md).
