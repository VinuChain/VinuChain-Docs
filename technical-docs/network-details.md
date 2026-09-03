# Network Details

> Canonical network facts for VinuChain. Every chain ID, RPC endpoint, and explorer URL in these docs should match this page. Machine-readable contract registries live in [Vinuchain-Lists](https://github.com/VinuChain/Vinuchain-Lists).

## Networks

|                           | Mainnet                                      | Testnet                                                      |
| ------------------------- | -------------------------------------------- | ------------------------------------------------------------ |
| **Chain ID / Network ID** | `207` (`0xcf`)                               | `206` (`0xce`)                                               |
| **Currency**              | VC                                           | VC                                                           |
| **Public RPC**            | `https://rpc.vinuchain.org`                  | `https://vinufoundation-rpc.com`                             |
| **Block explorer**        | [vinuexplorer.org](https://vinuexplorer.org) | [testnet.vinuexplorer.org](https://testnet.vinuexplorer.org) |
| **Faucet**                | —                                            | [Request in Discord](https://discord.gg/vinu)                |
| WSS                       | `wss://rpc.vinuchain.org`                    | `wss://vinufoundation-rpc.com:4100`                           |

## Key contracts

| Contract                                       | Network | Address                                      |
| ---------------------------------------------- | ------- | -------------------------------------------- |
| SFC (Staking)                                  | both    | `0xFC00FACE00000000000000000000000000000000` |
| NodeDriverAuth                                 | both    | `0xD100ae0000000000000000000000000000000000` |
| NodeDriver                                     | both    | `0xd100A01E00000000000000000000000000000000` |
| QuotaContract V2 (Payback, active)             | mainnet | `0x5D989A2d65d049e2198D91d8ddc31C918f2544AB` |
| QuotaContract V1 proxy (legacy, withdraw-only) | mainnet | `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6` |
| QuotaContract V2 (Payback, active)             | testnet | `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4` |

The full contract table (including VNS) is in the [Master Contracts Reference](smart-contracts/contracts-master-list.md). Verify the active Quota contract at any time with `vc_getRules("latest")` → `Economy.QuotaCacheAddress`.

{% hint style="warning" %}
**Mainnet's ELEMONT activation began on 2026-08-29 and all of its flags have now sealed.** `Economy.QuotaCacheAddress` now points at `QuotaContractV2` `0x5D989A2d65d049e2198D91d8ddc31C918f2544AB`, and the mainnet SFC now runs its V2 bytecode (`version()` = `"305"`). **Anyone still staked on the V1 Quota proxy `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6` is no longer earning fee refunds and still needs to migrate** — see the [ELEMONT migration steps](vinuchain-mainnet/elemont-upgrade.md#if-you-stake-in-the-payback-fee-refund-contract). Trust `vc_getRules` over any static list.
{% endhint %}

## Wallet quick-add (mainnet)

* Network name: `VinuChain`
* RPC URL: `https://rpc.vinuchain.org`
* Chain ID: `207`
* Currency symbol: `VC`
* Explorer: `https://vinuexplorer.org`

For step-by-step instructions see [Connect to Mainnet](vinuchain-mainnet/connect-to-mainnet.md) and [Connect to Testnet](vinuchain-testnet/connect-to-testnet.md).
