# VinuChain Name Service

VinuChain Name Service (VNS) is the VinuChain testnet deployment of Ethereum
Name Service-style contracts for `.vinu` names. It lets wallets and explorer
clients resolve names such as `example.vinu` to VinuChain addresses, and lets
addresses set a primary reverse name.

VNS is deployed as ordinary EVM contracts. It does not require a VinuChain node
upgrade, genesis change, or consensus rule change.

## Testnet deployment

| Contract | Address |
| --- | --- |
| VNS Registry | `0x75a267fe2910BF96bA42924a67411E1091Be97C3` |
| Root | `0xeC612586627a4315954fA80ba3982D28c15735bE` |
| Reverse Registrar | `0xB7d2D6C6c897cEfe6D4a92164DCBdAA9a6294FD7` |
| Default Reverse Registrar | `0x787e8D94D39a2c296E8Aeca482a522BCDA5d2F2E` |
| Default Reverse Resolver | `0x22Df7D962e56619145ec448a0F7cEB6A7C844cD2` |
| VNS Base Registrar | `0x9e450D84E12090c7A927ec369D514c969F76f11C` |
| Owned Resolver | `0xF45Ee4Be3C1f93B6daD46d3d4A5264151C084794` |
| Dummy Oracle | `0xa99e68A0E3e78d16252f6C6460b8c8F8D613a0B9` |
| Premium Price Oracle | `0x8B889e24679BfB83af796dAD6676C85237ca3b31` |
| Static Metadata Service | `0xAE8B12256B7AFEdc250914501867cbaC0a5A9eeB` |
| Name Wrapper | `0x7e82c20DB1E128F73D0370Ea05CA98d0CCDB5E26` |
| VNS Registrar Controller | `0x24Cf3e3094787c223ee2Ba6b106DC15d4474a844` |
| VNS Bulk Renewal | `0xb666eDA6Fb0180741923Ef2ff8f35AfE5642eB76` |
| VNS Public Resolver | `0x4A48039E378d7a29A27BC737d9D6E303D46A6620` |
| Gateway Provider | `0xbd3D532604cDC469aF0C69e7D8fbC11420eB7BaC` |
| Universal Resolver | `0x79165046bac745Aad2649b2278EEb1389AA577AA` |

Network details:

* Chain ID: `206`
* RPC: `https://vinufoundation-rpc.com`
* Top-level domain: `.vinu`
* `.vinu` namehash:
  `0x8b2c096e21786c9afa7a1fedd1b69a27848cce61a49ec6363cd582b31efa6694`
* `.vinu` labelhash:
  `0xf51f7b42cfc94df97ddae258deab475433ad9c881402cfc605a5e6b28b861605`

The deployment provenance, patched source snapshots, and ABIs are tracked in
the `vinuchain-lists` repository under `contracts/vns/`.

## Contract baseline

VNS is based on the official `@ensdomains/ens-contracts` package version
`1.7.0`, with the ENS `.eth` registrar and wrapper constants patched to `.vinu`.
The VNS deployment keeps the registry, base registrar, commit/reveal registrar
controller, public resolver, reverse registrar, name wrapper, bulk renewal, and
universal resolver surface.

The DNSSEC registrar, DNS oracle flow, offchain DNS integration, P-256
verification path, L2 reverse registrar, and migration contracts are not part of
the current VNS testnet deployment. Those components are not needed for native
`.vinu` registration and address resolution, and the DNSSEC path depends on
Ethereum precompile assumptions that VinuChain does not currently expose.

## Explorer support

The testnet explorer is configured to expose VNS through the Blockscout-style
name-service API and to use it in search results.

Supported explorer behavior:

* Search `name.vinu` and open the resolved address.
* Show a primary `ens_domain_name` value on address API responses when reverse
  resolution is set.
* Batch-resolve address names for address, transaction, token transfer,
  internal transaction, log, withdrawal, and search API responses.
* Query VNS protocol metadata at `/api/v1/206/protocols`.

The explorer integration is intentionally read-through for the initial testnet
deployment. It resolves exact names and reverse names from the live VNS
contracts instead of running a separate full historical name index.

## Smoke check

The initial testnet smoke name is `codexvns.vinu`.

Expected resolution:

* `codexvns.vinu` resolves to
  `0xf9c82B1117e8BeA97843042521B8FBC93044f347`
* The same address resolves back to `codexvns.vinu`

## Mainnet preparation

Before deploying VNS on mainnet:

1. Re-run the contract deployment from a reviewed mainnet deployment plan.
2. Re-confirm the supported contract subset. If DNSSEC, P-256 verification,
   offchain DNS, L2 reverse registrar, or migration contracts are added, review
   whether VinuChain needs extra chain support before deployment.
3. Record the mainnet contract addresses and ABIs in `vinuchain-lists`.
4. Configure the mainnet explorer with the mainnet VNS addresses.
5. Run forward and reverse resolution smoke checks.
6. Document the mainnet addresses in this page after deployment.
