# VinuChain — Master Contracts & Owners Reference

> Single source-of-truth for every user-facing contract VinuChain operates,
> the network it's on, its owner / administrator EOA, and where the canonical
> source / ABI live. Use this as the first stop before any operation that
> touches a core contract.
>
> Last refreshed: 2026-06-10.

## Networks

| Network | Chain ID (hex / dec) | Public RPC | Block Explorer |
|---|---|---|---|
| Mainnet | `0xcf` / `207` | `https://vinuchain-rpc.com` | `https://vinuexplorer.org` |
| Testnet | `0xce` / `206` | `https://vinufoundation-rpc.com` | `https://testnet.vinuexplorer.org` |
| Staging | `0xcd` / `205` | (internal) | (internal) |
| Fakenet | `0x1b` / `27` | (local dev) | n/a |

## VinuChain Core (chain 207 mainnet · chain 206 testnet)

These are predeploy / genesis-installed contracts that exist on every VinuChain network.

| Contract | Address | Owner / Administrator | Role |
|---|---|---|---|
| **SFC (Staking)** | `0xFC00FACE00000000000000000000000000000000` | mainnet: `0xF39257…16c1`; testnet: `0x7f9076…dbfd` | Validator staking, delegation, lockups, epoch rewards, slashing. V1 bytecode on mainnet; V2 Cycle-161 on testnet (active since v2.0.14-elemont). |
| **NodeDriverAuth** | `0xD100ae0000000000000000000000000000000000` | mainnet & testnet: `0xf9c82B1117e8BeA97843042521B8FBC93044f347` | Owner-controlled governance — queues and executes time-locked migrations, network rule updates, epoch advances. Owner key controls the chain's administrative surface. |
| **NodeDriver** | `0xd100A01E00000000000000000000000000000000` | (delegated by NodeDriverAuth) | EVM-facing relay between NodeDriverAuth and EvmWriter. Emits canonical events for validator weight/pubkey changes, rule updates, epoch advances. |
| **EvmWriter** *(Go precompile)* | `0xd100ec0000000000000000000000000000000000` | n/a (precompile) | State-write precompile (`setBalance`, `copyCode`, `swapCode`, `setStorage`, `incNonce`). Only callable from `NodeDriver`. |
| **NetInit** *(genesis-only)* | `0xd1005eed00000000000000000000000000000000` | n/a | Bootstraps SFC + drivers during genesis. No bytecode after init. |
| **QuotaContract V1 (proxy)** | mainnet: `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6` · testnet: `0x824B93dE7221cf8a35FBd29d5202f6eFa3A29C5D` | VinuChain Foundation — contact team | Original payback / fee-refund proxy. **Superseded on testnet by QuotaContract V2.** Stakers retain permissionless access to `unstake()`/`withdrawStake()` on V1. |
| **QuotaContract V2** (testnet, PaybackV2 active) | testnet: `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4` | `0xf9c82B1117e8BeA97843042521B8FBC93044f347` | Non-proxy replacement; the active testnet Quota contract — the address `vc_getRules("latest")` reports as `Economy.QuotaCacheAddress`. Same ABI as V1 plus `stakeFor(address)` / `unstakeFor(address,uint256)`. |

## VNS — VinuChain Name Service (chain 206 testnet only)

Active stack as of the 2026-05-18 oracle redeploy. Legacy / revoked addresses listed for provenance only.

### Active contracts

| Contract | Address | Owner / Admin | Role |
|---|---|---|---|
| **ENS Registry** | `0x75a267fe2910BF96bA42924a67411E1091Be97C3` | Root | Holds owner/resolver/ttl per node. |
| **Root** | `0xeC612586627a4315954fA80ba3982D28c15735bE` | `0x9214C638e240eda8D47AAc4A01C57b08C10fcdCd` (VNS namespace admin) | Owns the namespace. Loss / compromise = largest VNS blast radius. |
| **Reverse Registrar** (`addr.reverse`) | `0xB7d2D6C6c897cEfe6D4a92164DCBdAA9a6294FD7` | controller set incl. ETHRegistrarController | EVM-coinType-60 reverse registrar. |
| **Default Reverse Registrar** (`default.reverse`) | `0x787e8D94D39a2c296E8Aeca482a522BCDA5d2F2E` | controller set incl. ETHRegistrarController | Fallback reverse for all EVM chains. |
| **Default Reverse Resolver** | `0x22Df7D962e56619145ec448a0F7cEB6A7C844cD2` | — | Resolves the default-reverse records. |
| **Base Registrar** (ERC-721 names) | `0x9e450D84E12090c7A927ec369D514c969F76f11C` | controller set incl. ETHRegistrarController | `.vinu` token-bound names; ownership & expiry. |
| **Owned Resolver** | `0xF45Ee4Be3C1f93B6daD46d3d4A5264151C084794` | `0x9214C638e240eda8D47AAc4A01C57b08C10fcdCd` (VNS namespace admin) | TLD-level resolver. |
| **Static Metadata Service** | `0xAE8B12256B7AFEdc250914501867cbaC0a5A9eeB` | — | NFT metadata bridge for wrapped names. |
| **Name Wrapper** | `0x7e82c20DB1E128F73D0370Ea05CA98d0CCDB5E26` | controller set incl. ETHRegistrarController | ERC-1155 wrap layer for `.vinu` names. |
| **VinuUsdOracle (VC/USD price feed)** | `0xde7931dCA452Be9647e4AF13C92edCFac1f26d52` | `0xD77b037c1F6F8Eb0D21629C97F6E330a7816557e` (oracle updater) | 8-decimal VC/USD answer with `maxAge`/`minAnswer`/`maxAnswer`/`maxChangeBps` guards. Refreshed by the `vns-oracle-update.yml` GitHub Actions workflow every 4h. **Reverts with `StaleAnswer(uint256,uint256)` if not refreshed within `maxAge` (86400 s).** |
| **Exponential Premium Price Oracle** | `0xf165a2a7858C6E215e56B27a3Bf4565Bcf16e226` | `0xD77b037c1F6F8Eb0D21629C97F6E330a7816557e` (oracle updater) | Owner-governed USD-rent curve (1/2/3/4/5+ char names) + 21-day exponential premium. Reads `VinuUsdOracle.latestAnswer()` at quote time. |
| **VNS Registrar Controller (ETHRegistrarController)** | `0x67f98dD44B88bE9fAB06e3b94C77EB2444E81695` | `0x9214C638e240eda8D47AAc4A01C57b08C10fcdCd` (VNS namespace admin) | Commit/reveal registrar: `commit`, `register`, `renew`, `rentPrice`, `available`. Min commitment age 60 s, max 24 h. Owner-gated `pause()`/`unpause()` halts `commit`/`register`/`renew` in emergencies. |
| **Static Bulk Renewal** | `0xC3E55936B1014c41370A678ea22F986C1Ef57288` | — | Batch `renew` helper for resolvers/wallets. |
| **Public Resolver** | `0x4A48039E378d7a29A27BC737d9D6E303D46A6620` | n/a (per-record owner controls) | Forward records (`addr`, `text`, `contenthash`, etc). Recommended resolver for all new `.vinu` registrations. |
| **Gateway Provider** | `0xbd3D532604cDC469aF0C69e7D8fbC11420eB7BaC` | — | CCIP-Read gateway list provider. |
| **Universal Resolver** | `0x79165046bac745Aad2649b2278EEb1389AA577AA` | — | Multi-step resolution entry point (used by explorer / wallets). |

### Legacy / revoked (2026-05-18 oracle-stack switch)

These addresses had their controller permissions on Base Registrar, Name Wrapper, Reverse Registrar, and Default Reverse Registrar revoked at blocks `1462432–1462435`. Do not send transactions to these contracts.

| Contract | Address |
|---|---|
| Legacy Dummy Oracle | `0xa99e68A0E3e78d16252f6C6460b8c8F8D613a0B9` |
| Legacy Exponential Premium Price Oracle | `0x8B889e24679BfB83af796dAD6676C85237ca3b31` |
| Legacy VNS Registrar Controller | `0x24Cf3e3094787c223ee2Ba6b106DC15d4474a844` |
| Legacy VNS Bulk Renewal | `0xb666eDA6Fb0180741923Ef2ff8f35AfE5642eB76` |
| Previous VinuUsdOracle | `0x02387e01050340d51d328Bb8cC088f9488C2c5Ff` |
| Previous Exponential Premium Price Oracle | `0x46f987cb963122BdF172Af1CA81AC7dF0616d11F` |
| Previous VNS Registrar Controller | `0xe793903D6C81ED9E907f3B8EaD820deBEDf63C21` |
| Previous VNS Bulk Renewal | `0x810e4C552Db16c83009a03F135A646BeBeEcc20b` |
| Retired VNS Registrar Controller (replaced by pausable controller, 2026-05-21) | `0x313b4C7CDe49a74983205c938f904b4a488bDb14` |

### Namespace constants

* `.vinu` namehash: `0x8b2c096e21786c9afa7a1fedd1b69a27848cce61a49ec6363cd582b31efa6694`
* `.vinu` labelhash: `0xf51f7b42cfc94df97ddae258deab475433ad9c881402cfc605a5e6b28b861605`
* TLD: `.vinu`

## Canonical sources

Contract ownership and administration is held by the VinuChain Foundation.
For integration questions, contact [hello@vinuchain.org](mailto:hello@vinuchain.org).

Machine-readable address registries and ABIs live in the public
[Vinuchain-Lists](https://github.com/VinuChain/Vinuchain-Lists) repository:

| Concern | Source |
|---|---|
| VNS contracts catalogue (`.sol` + `_abi.json` per contract) | `Vinuchain-Lists:/contracts/vns/` |
| VNS testnet deployment provenance (tx hashes + block numbers) | `Vinuchain-Lists:/contracts/vns/deployment-testnet.json` |
| Core VinuChain contracts catalogue | `Vinuchain-Lists:/contracts/vinuchain/` |
| Go-side predeploy / address constants | [`VinuChain:/opera/contracts/`](https://github.com/VinuChain/VinuChain/tree/main/opera/contracts) |
| `Economy.QuotaCacheAddress` per-network rule | [`VinuChain:/opera/rules.go`](https://github.com/VinuChain/VinuChain/blob/main/opera/rules.go) |
| PaybackV2 per-network V2 address slots | [`VinuChain:/opera/payback_v2_address.go`](https://github.com/VinuChain/VinuChain/blob/elemont/opera/payback_v2_address.go) (on the `elemont` branch) |

## Smoke-name baseline (testnet)

| Field | Value |
|---|---|
| Name | `codexvns.vinu` |
| Namehash | `0x083e64b73b42885c8b58586f144e1bb568800fdf31f0a07ff26eff93de2ec0df` |
| Owner / Registrant | `0xf9c82B1117e8BeA97843042521B8FBC93044f347` |
| Resolved address | `0xf9c82B1117e8BeA97843042521B8FBC93044f347` |
| Resolver | `0x4A48039E378d7a29A27BC737d9D6E303D46A6620` |
| Expiry | `2027-05-17T17:03:06Z` |

## How to verify on-chain state

```bash
# 1) Oracle is fresh (no StaleAnswer revert)
curl -sS https://vinufoundation-rpc.com -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_call",
           "params":[{"to":"0xde7931dCA452Be9647e4AF13C92edCFac1f26d52",
                      "data":"0x50d25bcd"},"latest"],"id":1}'
# expected: result is non-revert; decoded uint = $price * 1e8

# 2) rentPrice("name", 31536000) on the controller
curl -sS https://vinufoundation-rpc.com -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_call","params":[
            {"to":"0x67f98dD44B88bE9fAB06e3b94C77EB2444E81695",
             "data":"0x83e7f6ff00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000001e1338000000000000000000000000000000000000000000000000000000000000000046e616d6500000000000000000000000000000000000000000000000000000000"},
            "latest"],"id":1}'
# expected: result returns 64-byte tuple (base, premium)

# 3) BENS adapter — VNS protocol manifest
curl -sS https://testnet.vinuexplorer.org/api/v1/206/protocols | jq .

# 4) BENS adapter — domain lookup
curl -sS https://testnet.vinuexplorer.org/api/v1/206/domains/codexvns.vinu | jq .

# 5) BENS adapter — reverse lookup
curl -sS https://testnet.vinuexplorer.org/api/v1/206/addresses/0xf9c82B1117e8BeA97843042521B8FBC93044f347 | jq .
```

## See also

- [VinuChain Name Service](./vinuchain-name-service.md) — VNS deployment summary + oracle refresh runbook
- [`Vinuchain-Lists:/contracts/vinuchain/info.json`](https://github.com/VinuChain/Vinuchain-Lists/blob/main/contracts/vinuchain/info.json) — machine-readable mainnet contract index used by VinuExplorer, wallets, and SDK consumers
