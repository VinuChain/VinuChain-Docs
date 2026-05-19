# VinuChain Name Service

VinuChain Name Service (VNS) is the VinuChain testnet deployment of Ethereum
Name Service-style contracts for `.vinu` names. It lets wallets and explorer
clients resolve names such as `example.vinu` to VinuChain addresses, and lets
addresses set a primary reverse name.

VNS is deployed as ordinary EVM contracts. It does not require a VinuChain node
upgrade, genesis change, or consensus rule change.

## Testnet deployment

These are the active VNS contracts as of the 2026-05-18 oracle-stack switch. The
registrar controller, premium price oracle, and bulk renewal helper were
redeployed on that date against the real `VinuUsdOracle`; the previous-stack
addresses are listed under "Legacy contracts" below for provenance only.

| Contract | Address |
| --- | --- |
| VNS Registry | `0x75a267fe2910BF96bA42924a67411E1091Be97C3` |
| Root | `0xeC612586627a4315954fA80ba3982D28c15735bE` |
| Reverse Registrar | `0xB7d2D6C6c897cEfe6D4a92164DCBdAA9a6294FD7` |
| Default Reverse Registrar | `0x787e8D94D39a2c296E8Aeca482a522BCDA5d2F2E` |
| Default Reverse Resolver | `0x22Df7D962e56619145ec448a0F7cEB6A7C844cD2` |
| VNS Base Registrar | `0x9e450D84E12090c7A927ec369D514c969F76f11C` |
| Owned Resolver | `0xF45Ee4Be3C1f93B6daD46d3d4A5264151C084794` |
| Static Metadata Service | `0xAE8B12256B7AFEdc250914501867cbaC0a5A9eeB` |
| Name Wrapper | `0x7e82c20DB1E128F73D0370Ea05CA98d0CCDB5E26` |
| VinuUsdOracle | `0xde7931dCA452Be9647e4AF13C92edCFac1f26d52` |
| Exponential Premium Price Oracle | `0xf165a2a7858C6E215e56B27a3Bf4565Bcf16e226` |
| VNS Registrar Controller | `0x313b4C7CDe49a74983205c938f904b4a488bDb14` |
| VNS Bulk Renewal | `0xC3E55936B1014c41370A678ea22F986C1Ef57288` |
| VNS Public Resolver | `0x4A48039E378d7a29A27BC737d9D6E303D46A6620` |
| Gateway Provider | `0xbd3D532604cDC469aF0C69e7D8fbC11420eB7BaC` |
| Universal Resolver | `0x79165046bac745Aad2649b2278EEb1389AA577AA` |

### Legacy contracts (revoked 2026-05-18, retained for provenance only)

These addresses were active before the 2026-05-18 oracle-stack switch. Their
controller permissions on the base registrar, name wrapper, reverse registrar,
and default reverse registrar were revoked at blocks 1462432–1462435. Do not
send transactions to these contracts — they no longer have registrar or
wrapper permissions and quotes from the legacy oracle are divorced from the
live VC/USD rate.

| Contract | Address |
| --- | --- |
| Legacy Dummy Oracle | `0xa99e68A0E3e78d16252f6C6460b8c8F8D613a0B9` |
| Legacy Exponential Premium Price Oracle | `0x8B889e24679BfB83af796dAD6676C85237ca3b31` |
| Legacy VNS Registrar Controller | `0x24Cf3e3094787c223ee2Ba6b106DC15d4474a844` |
| Legacy VNS Bulk Renewal | `0xb666eDA6Fb0180741923Ef2ff8f35AfE5642eB76` |
| Previous VinuUsdOracle | `0x02387e01050340d51d328Bb8cC088f9488C2c5Ff` |
| Previous Exponential Premium Price Oracle | `0x46f987cb963122BdF172Af1CA81AC7dF0616d11F` |
| Previous VNS Registrar Controller | `0xe793903D6C81ED9E907f3B8EaD820deBEDf63C21` |
| Previous VNS Bulk Renewal | `0x810e4C552Db16c83009a03F135A646BeBeEcc20b` |

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

## Pricing oracle

VNS pricing on testnet is a three-layer stack that converts a USD-denominated
rent curve into the VC amount enforced at registration and renewal time.

1. `VinuUsdOracle` at `0xde7931dCA452Be9647e4AF13C92edCFac1f26d52` is an
   owner-updated VC/USD feed. It stores the answer with 8 decimals and
   enforces a configured staleness window, absolute answer bounds, and a
   per-update relative-change cap. If any of those guards fail the feed
   reverts on read, which causes the registrar controller to refuse new
   commits and registrations until a fresh answer is accepted.
2. Exponential Premium Price Oracle at
   `0xf165a2a7858C6E215e56B27a3Bf4565Bcf16e226` holds the owner-governed USD
   rent curve for 1-, 2-, 3-, 4-, and 5+ character names and converts that
   curve into VC at quote time using the live `VinuUsdOracle` answer.
3. VNS Registrar Controller at `0x313b4C7CDe49a74983205c938f904b4a488bDb14`
   reads the price oracle inside `commit`, `register`, and `renew` and rejects
   underpayment against the current `rentPrice(...)`.

Active oracle parameters (from the 2026-05-18 testnet redeploy):

| Parameter | Value |
| --- | --- |
| Decimals | `8` |
| Max age | `86400` seconds (24 hours) |
| Min accepted answer | `1000` (1e-5 USD per VC) |
| Max accepted answer | `1000000` (1e-2 USD per VC) |
| Max per-update change | `2000` basis points (20%) |
| Min commitment age | `60` seconds |
| Max commitment age | `86400` seconds |
| Source feed | CoinGecko price with VinuSwap V3 TWAP fallback agreement |

The feed is refreshed by a scheduled GitHub Actions workflow
(`.github/workflows/vns-oracle-update.yml` in `vinuchain-lists`) that prices VC
from CoinGecko and a guarded VinuSwap V3 TWAP, requires both sources to be
fresh and within the configured deviation threshold for normal sends, and
submits `VinuUsdOracle.setLatestAnswer(...)` using the
`VNS_ORACLE_PRIVATE_KEY` repository secret. An emergency single-source flag
exists for the case where CoinGecko or the guarded pool fallback is
unavailable. The current default cadence is once per day at 00:17 UTC; the
cadence is moving to every four hours as part of oracle and CI hardening work
in progress.

### Key management

Every state-changing surface on the VNS testnet stack is currently owned by a
single deployer EOA, `0xf9c82B1117e8BeA97843042521B8FBC93044f347`. That EOA is
the recoverable NodeDriverAuth-owner used elsewhere on VinuChain and is the
same key recorded as the `Root` owner, the registrar/wrapper controller-set
administrator, and the `VinuUsdOracle` and Exponential Premium Price Oracle
owners in `deployment-testnet.json` and `info.json`.

Operationally this means:

* `VinuUsdOracle.setLatestAnswer`, `setMaxAge`, `setBounds`, and
  `setMaxChangeBps` are all guarded by `onlyOwner` against that EOA. If the
  oracle key is compromised an attacker can move the VC/USD answer inside the
  configured bounds and max-change cap, which lets them inflate or deflate
  VNS prices up to those limits per update.
* If the oracle key is lost the feed will freeze. Registrations and renewals
  will keep clearing at the last accepted price for up to 24 hours and then
  start reverting in `latestAnswer()` once the staleness window elapses.
* `Root` ownership lets the holder reassign top-level VNS subnodes such as
  `.vinu` and `addr.reverse`. Loss or compromise of this key has the largest
  blast radius of any VNS administrator on testnet.
* There is currently no on-chain pause method, no multi-signature wallet, and
  no time-locked owner rotation on any of the VNS administrator surfaces.

This is the same shape of risk that played out on the Quota
`ProxyAdmin` owner key `0x07b4ef…b9a5`, which was deployed in 2024 and is
unrecoverable in-house. That incident is the reason VNS public registration
is currently disabled on `vinuchain.org` until the full stack is reviewed and
approved for public launch. Recommended (not yet executed) follow-ups before
public launch and before any mainnet rollout:

* Split the registrar-administrator role from the oracle-updater role so the
  daily-update workflow runs under a key that does not also own `Root` or the
  registrar/wrapper controller-set.
* Move the registrar-administrator role behind a multi-signature wallet with
  a time-locked owner rotation procedure.
* Document the key-rotation playbook (covering both the `VNS_ORACLE_PRIVATE_KEY`
  repository secret and on-chain owner rotation) in this page before public
  launch.

## Security status

VNS reuses the audited `@ensdomains/ens-contracts` `1.7.0` codebase. The
VinuChain-specific layer on top of that codebase has NOT yet been third-party
audited. Specifically:

* ENS `1.7.0` upstream is audited. The patches applied for VNS are recorded
  in `vns-port.patch` in `vinuchain-lists/contracts/vns/` and are
  constant-substitution-only: the `.eth` namehash, the `.eth` labelhash, the
  `.vinu` namehash, the `.vinu` labelhash, and the DNS wire-name helpers in
  `ETHRegistrarController.sol`, `NameWrapper.sol`, and `NameCoder.sol`. No
  control-flow or storage-layout changes are included in the patch.
* `VinuUsdOracle` is VinuChain-specific, owner-controlled, and has NOT been
  third-party audited.
* The off-chain oracle-update pipeline (`scripts/update-vns-oracle.js` and
  `.github/workflows/vns-oracle-update.yml`) has NOT been third-party
  audited.

A multi-bot internal review was completed on 2026-05-19 covering registrar
behaviour, oracle bounds and update guards, port-patch coverage, deployment
provenance, and public-docs consistency. Open items from that review:

* The legacy revoked-controller-stack addresses cited as live on this page
  before this update have been moved into the "Legacy contracts" sub-section
  above.
* Promotion of `VinuUsdOracle` from `localExtensions` to
  `deployedArtifactHashes` in `build-provenance.json` is being landed in the
  same change-set.
* Backend-side critical findings flagged by the review are being fixed
  separately ahead of public registration being re-enabled.
* The `Root` lock referenced in the review is still pending.

Public registration should remain disabled on `vinuchain.org` until the full
stack is reviewed and approved for public launch.

Security contact: `hello@vinuchain.com`.

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
