# Network Details

> Canonical network facts for VinuChain. Every chain ID, RPC endpoint, and
> explorer URL in these docs should match this page. Machine-readable
> contract registries live in
> [Vinuchain-Lists](https://github.com/VinuChain/Vinuchain-Lists).

## Networks

| | Mainnet | Testnet |
|---|---|---|
| **Chain ID / Network ID** | `207` (`0xcf`) | `206` (`0xce`) |
| **Currency** | VC | VC |
| **Public RPC** | `https://rpc.vinuchain.org` | `https://vinufoundation-rpc.com` |
| **Block explorer** | [vinuexplorer.org](https://vinuexplorer.org) | [testnet.vinuexplorer.org](https://testnet.vinuexplorer.org) |
| **Faucet** | — | [Request in Discord](https://discord.gg/vinu) |

## Key contracts

| Contract | Network | Address |
|---|---|---|
| SFC (Staking) | both | `0xFC00FACE00000000000000000000000000000000` |
| NodeDriverAuth | both | `0xD100ae0000000000000000000000000000000000` |
| NodeDriver | both | `0xd100A01E00000000000000000000000000000000` |
| QuotaContract (Payback, active) | mainnet | `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6` |
| QuotaContract V2 (Payback, active) | testnet | `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4` |

The full contract table (including VNS) is in the
[Master Contracts Reference](smart-contracts/contracts-master-list.md).
Verify the active Quota contract at any time with
`vc_getRules("latest")` → `Economy.QuotaCacheAddress`.

{% hint style="warning" %}
**Mainnet's Payback contract changes on 2026-08-29.** The ELEMONT upgrade repoints
`Economy.QuotaCacheAddress` off the V1 proxy above onto a newly deployed
`QuotaContractV2`. Fee-refund stakers must migrate — see the
[Mainnet Upgrade Guide](vinuchain-mainnet/chain-upgrade-guide.md#if-you-stake-in-the-payback-fee-refund-contract).
The same upgrade replaces the mainnet SFC with its V2 bytecode. Re-read this page
after the upgrade, and trust `vc_getRules` over any static list.
{% endhint %}

## Wallet quick-add (mainnet)

* Network name: `VinuChain`
* RPC URL: `https://rpc.vinuchain.org`
* Chain ID: `207`
* Currency symbol: `VC`
* Explorer: `https://vinuexplorer.org`

For step-by-step instructions see
[Connect to Mainnet](vinuchain-mainnet/connect-to-mainnet.md) and
[Connect to Testnet](vinuchain-testnet/connect-to-testnet.md).
