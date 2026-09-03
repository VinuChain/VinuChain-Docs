# VinuChain Testnet

VinuChain testnet (chain ID `206`) is the parallel public test network. It
runs the full ELEMONT binary plus additional experimental stages
(the `SfcV2Patch`-`SfcV2Patch10` SFC re-flashes and `PaybackV2Patch`) that are
not staged on mainnet — mainnet installed the same Cycle-165 SFC bytecode
directly at its first `SfcV2` seal, so those re-flash flags never apply there.
VinuBLS12381, VinuLatestEVM and PaybackV2 are no longer testnet-only: all three
went live on mainnet in the 2026-08-29 ELEMONT upgrade.
Use it to test contracts and integrations against the latest chain features
before they reach mainnet. This section covers connecting to testnet, running
a private fakenet, and the operator-facing chain upgrade guide.

For all chain IDs, RPC endpoints, and explorer URLs in one place, see
[Network Details](../network-details.md).
