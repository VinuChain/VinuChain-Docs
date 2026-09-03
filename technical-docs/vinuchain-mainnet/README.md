# VinuChain Mainnet

VinuChain mainnet is the production network (chain ID `207`). This section covers
connecting a wallet to mainnet and running mainnet nodes.

{% hint style="danger" %}
**Completed upgrade — activated 29–30 August 2026.** Mainnet has moved to
testnet's target feature set: the **ELEMONT** release activated SfcV2, Shanghai, Cancun,
Prague (EIP-7702 set-code transactions), the Elemont consensus fixes, the
BLS12-381 and latest-EVM precompiles, and PaybackV2. The binary also adds
`vc_getPaybackBalance` and `eth_config`/`vc_config`; core `vc_*` RPC methods are
already live.

**Node operators must be running the ELEMONT binary** — this is a consensus upgrade.
See the [Mainnet Upgrade Guide (ELEMONT)](./chain-upgrade-guide.md); pre-flight
checks need lead time, especially transaction-index recovery. Container
deployments also require their coordinator-approved image/deployment runbook.

**Fee-refund stakers must migrate** to a new Payback contract —
see [the migration steps](./elemont-upgrade.md#if-you-stake-in-the-payback-fee-refund-contract).

Mainnet now runs the full ELEMONT rule set (`Berlin`, `London`, `Shanghai`, `Cancun`,
`Prague`, `VinuBLS12381`, `VinuLatestEVM`, `Llr`, `Podgorica`, `SfcV2`, `Elemont`,
`ElemontPubkeyValidation`, `PaybackV2`) on the V2 staking contract.
{% endhint %}

For the full ELEMONT feature set, user actions, and RPC availability,
see [VinuChain ELEMONT Upgrade](./elemont-upgrade.md).

For all chain IDs, RPC endpoints, and explorer URLs in one place, see
[Network Details](../network-details.md).
