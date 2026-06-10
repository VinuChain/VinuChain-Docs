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
| VNS Registrar Controller (pausable) | `0x67f98dD44B88bE9fAB06e3b94C77EB2444E81695` |
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
| Retired VNS Registrar Controller (replaced 2026-05-21 by the pausable controller; pending commits there must be re-committed on the new address) | `0x313b4C7CDe49a74983205c938f904b4a488bDb14` |

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
   reverts on read, which causes price reads, registrations, and renewals to
   fail until a fresh answer is accepted. `commit(bytes32)` only stores the
   commitment and does not read pricing.
2. Exponential Premium Price Oracle at
   `0xf165a2a7858C6E215e56B27a3Bf4565Bcf16e226` holds the owner-governed USD
   rent curve for 1-, 2-, 3-, 4-, and 5+ character names and converts that
   curve into VC at quote time using the live `VinuUsdOracle` answer.
3. VNS Registrar Controller at `0x67f98dD44B88bE9fAB06e3b94C77EB2444E81695`
   stores commitments in `commit(bytes32)`, computes pricing inside
   `register` and `renew`, and rejects underpayment against the current
   `rentPrice(...)`. The controller has owner-gated `pause()`/`unpause()`;
   while paused, `commit`/`register`/`renew` revert with `EnforcedPause`.

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
unavailable. The current scheduled cadence is every four hours at 17 minutes
past the hour.

### Key management

VNS administration is split across per-role owner keys (role split executed
2026-05-21; owners verifiable on-chain via `owner()`):

* **VNS namespace admin** — `0x9214C638e240eda8D47AAc4A01C57b08C10fcdCd` —
  owns `Root`, Base Registrar, Name Wrapper, Owned Resolver, Gateway
  Provider, the VNS Registrar Controller, and the reverse registrars.
* **VNS oracle updater** — `0xD77b037c1F6F8Eb0D21629C97F6E330a7816557e` —
  owns `VinuUsdOracle` and the Exponential Premium Price Oracle. The
  scheduled oracle-update workflow's `VNS_ORACLE_PRIVATE_KEY` secret is this
  key, so the 4-hourly cron never touches namespace or chain-governance
  surfaces.
* Chain governance (NodeDriverAuth, QuotaContract V2) remains with a
  separate Foundation EOA that holds no VNS roles.

Operationally this means:

* `VinuUsdOracle.setLatestAnswer`, `setMaxAge`, `setBounds`, and
  `setMaxChangeBps` are guarded by `onlyOwner` against the oracle-updater
  EOA. If the oracle key is compromised an attacker can move the VC/USD
  answer inside the configured bounds and max-change cap — but cannot touch
  the namespace or registrar surfaces.
* If the oracle key is lost the feed will freeze. Registrations and renewals
  will keep clearing at the last accepted price for up to 24 hours and then
  start reverting in `latestAnswer()` once the staleness window elapses.
* `Root` ownership lets the holder reassign top-level VNS subnodes such as
  `.vinu` and `addr.reverse`. Loss or compromise of the namespace-admin key
  has the largest blast radius of any VNS administrator on testnet.
* The registrar controller has an owner-gated on-chain `pause()` for
  emergencies (halts `commit`/`register`/`renew`), but there is no
  multi-signature wallet and no time-locked owner rotation on any of the
  VNS administrator surfaces.

VNS public registration is currently disabled on `vinuchain.org` until the
full stack is reviewed and approved for public launch. Remaining follow-ups
before public launch and before any mainnet rollout:

* Move the registrar-administrator role behind a multi-signature wallet with
  a time-locked owner rotation procedure, or document the accepted
  single-key custody procedure for it.
* Keep the key-rotation playbook (covering both the `VNS_ORACLE_PRIVATE_KEY`
  repository secret and on-chain owner rotation) current in this page.

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

Security contact: `hello@vinuchain.org`.

## Explorer integration

See [Explorer support](#explorer-support) above for the user-visible
behaviour and search semantics. This section documents the backend
wiring that powers those surfaces.

VinuExplorer surfaces VNS without a separate Blockscout BENS Rust service.
The upstream BENS service does not have a record for VinuChain (chains 206
or 207); both `bens.services.blockscout.com` and its dev variant return
`Network with id <id> not found`. To bridge this, the `vinuexplorer-backend`
fork carries a custom adapter that emits BENS-protocol-shaped envelopes
from local data.

| BENS resource | Where it comes from |
|---------------|---------------------|
| `domain_info` / `/api/v1/206/domains/:name` | `VNSMetadata.domain_info/2` composes from `@known_allocations_by_name`, controller `NameRegistered` log scan, and `address_names` rows with `metadata->>'protocol' = 'VNS'` |
| `address_domain` / `/api/v1/206/addresses/:address` | Reverse-resolution via `VNSMetadata.name_for_address_hash/2` (indexed ERC-721 owner + `address_names` row) |
| `domains:lookup` / `/api/v1/206/domains:lookup` | Bulk enumeration of every registered name — unions controller `NameRegistered` logs with `@known_allocations_by_name`. Supports `name=` substring (auto-strips `.vinu`), `only_active=`, `page_size=`, `page_token=` |
| `addresses:lookup` / `/api/v1/206/addresses:lookup` | Filters bulk enumeration by owner address. Refuses malformed addresses without raising |
| `protocols` / `/api/v1/206/protocols` | Hardcoded `[vns]` protocol entry — the frontend protocol-selector keys off the `id` |
| `domain_events` / `/api/v1/206/domains/:name/events` | Returns `{"items":[]}` (no separate event index yet; a future Graph Node deployment would populate it) |

### Frontend wiring

`NEXT_PUBLIC_NAME_SERVICE_API_HOST` points at the explorer's own host
(`https://testnet.vinuexplorer.org`) rather than at a separate BENS service.
The Next.js page is `/name-services` (the nav label is "VinuChain Name
Service (VNS)"); the per-domain detail page is `/name-services/domains/[name]`.

Every consumer surface gates off `config.features.nameServices`, which becomes
truthy whenever `NEXT_PUBLIC_NAME_SERVICE_API_HOST` is set. The P0 surfaces
wired through that flag are:

* `/name-services` — Domains tab + Clusters tab
* `/name-services/domains/[name]` — detail page
* top-nav button (sidebar / horizontal nav)
* universal search bar (accepts `1.vinu` style queries)
* `/search-results` (search row with `EnsEntity`)
* `/address/[hash]` header — primary VNS badge via `bens:address_domain`
* `/address/[hash]` "Names" tab — `AddressEnsDomains` via `bens:addresses_lookup`
* connected-wallet badge in the user profile widget
* tx-interpretation chips

All address-bearing display surfaces share a single `EnsEntity` component
that URL-encodes the link target (so `/`, `?`, `#`, and `..` in a name
cannot escape the path segment) and safe-displays the name via
`lib/vns/displayName.ts` (strips bidi/zero-width characters, Punycode-encodes
non-ASCII labels, warns on mixed-script labels).

### Mainnet status

VNS is not deployed on mainnet (chain 207). The explorer's `VNSMetadata`
module fails closed on chain 207 — no domain lookups, no reverse resolution,
no metadata emission.

The mainnet rollout gate has five criteria, each of which must land before
any wallet, explorer, or DEX integration treats mainnet `.vinu` as
authoritative. Summary:

- **P0** — `Root.lock(vinu)` on testnet. (The per-role key split of the
  original deployer EOA is done — see Key management above.)
- **P1** — deploy the VNS stack on mainnet with the split-owner keys,
  then generalise `Explorer.Chain.Token.Instance.VNSMetadata` to dispatch
  on chain-id (chain 207 alongside chain 206).
- **P2** — publish a chaindata snapshot, register mainnet addresses in
  `vinuchain-lists` (`contracts/vns/deployment-mainnet.json`), surface a
  "Mainnet deployment" section here, and announce that the testnet
  `1.vinu` allocation does not carry over.

The full criteria (including the "Why not bundle with a consensus release"
rationale and open testnet audit items) are maintained in the VinuChain
team's internal deployment log.

## Oracle refresh runbook

`VinuUsdOracle.latestAnswer()` reverts with `StaleAnswer(updatedAt, maxAge)` if
`block.timestamp - updatedAt > maxAge`. Every downstream price read in
`rentPrice`, `register`, and `renew` propagates that revert. Refresh procedure:

### Cron-driven refresh (normal path)

A GitHub Actions workflow in `vinuchain-lists` runs every 4 hours at `:17` past
the hour. The workflow is `.github/workflows/vns-oracle-update.yml` and is
gated on the `vns-oracle-prod` GitHub Environment, which scopes the
`VNS_ORACLE_PRIVATE_KEY` secret to that environment.

To verify the cron is healthy:

```bash
gh run list --workflow vns-oracle-update.yml --limit 5 \
  --repo VinuChain/vinuchain-lists \
  --json conclusion,createdAt,databaseId
```

A run of `failure` repeated across multiple ticks means the cron has stopped
refreshing the oracle. Each consecutive failure is a 4-hour staleness budget
spent; budget is exhausted at `maxAge / cronInterval = 24h / 4h = 6` failures
in a row.

Common failure modes and their fixes:

| Failure error | Cause | Fix |
|---|---|---|
| `Set VNS_ORACLE_PRIVATE_KEY` | Secret missing from `vns-oracle-prod` env | `gh secret set VNS_ORACLE_PRIVATE_KEY --env vns-oracle-prod --repo VinuChain/vinuchain-lists` (key for the oracle-updater EOA `0xD77b…557e`) |
| `CoinGecko/V3 TWAP deviation … bps exceeds N` | Pool TWAP and CoinGecko prices diverge by more than the cap | Set repo variable `VNS_ORACLE_MAX_DEVIATION_BPS` to widen the cap (e.g. `750`). Walking past `1000` requires script-level review. |
| `Answer update deviation … bps exceeds N` | Trying to set an answer that moves the price more than `maxChangeBps` (default 20 %) in one step | Wait for the next cron tick (the script computes a fresh price each run); or manually call `setLatestAnswer` with a value within the cap. |
| `Unable to price VC from CoinGecko or guarded V3 TWAP pools` | Both price sources unreachable | Trigger workflow_dispatch with `allow_single_source: true` if one source is up; otherwise wait for upstream recovery. |
| Workflow stuck in `waiting` | Environment has required reviewers; nobody approved | An admin opens the Actions tab and approves the pending run. |

### Manual refresh (emergency path)

When the cron is broken and the oracle is approaching staleness, refresh from
a local checkout of `vinuchain-lists` with the oracle-owner key in a
gitignored `.env`:

```bash
# 1. Stage the oracle-owner key in a gitignored .env (mode 600)
cd ~/vinuchain-lists
umask 077
printf 'VNS_ORACLE_PRIVATE_KEY=%s\n' "$YOUR_KEY" > .env
# verify .env is gitignored (.gitignore:.env)

# 2. Dry-run to confirm reachability and acceptable deviation
VNS_USD_ORACLE_ADDRESS='0xde7931dCA452Be9647e4AF13C92edCFac1f26d52' \
VNS_ORACLE_CHAIN_ID='206' \
VNS_PRICE_CHAIN_ID='207' \
VNS_ORACLE_REQUIRE_POOL_GUARD='1' \
VNS_ORACLE_RPC_URL='https://vinufoundation-rpc.com' \
VNS_PRICE_RPC_URL='https://vinuchain-rpc.com' \
VNS_ORACLE_MAX_DEVIATION_BPS='750' \
npm run vns:oracle:dry-run

# 3. Broadcast (same env vars + the script's send flag)
VNS_USD_ORACLE_ADDRESS='0xde7931dCA452Be9647e4AF13C92edCFac1f26d52' \
VNS_ORACLE_CHAIN_ID='206' \
VNS_PRICE_CHAIN_ID='207' \
VNS_ORACLE_REQUIRE_POOL_GUARD='1' \
VNS_ORACLE_RPC_URL='https://vinufoundation-rpc.com' \
VNS_PRICE_RPC_URL='https://vinuchain-rpc.com' \
VNS_ORACLE_MAX_DEVIATION_BPS='750' \
npm run vns:oracle:update

# 4. Verify post-refresh: latestAnswer should not revert
curl -sS https://vinufoundation-rpc.com -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_call",
           "params":[{"to":"0xde7931dCA452Be9647e4AF13C92edCFac1f26d52","data":"0x50d25bcd"},
                     "latest"],"id":1}'
# expected: result is non-revert; decoded uint = vcUsd * 1e8
```

After the manual refresh, set the secret in the `vns-oracle-prod` GH
environment so the next scheduled cron tick succeeds without manual
intervention:

```bash
printf '%s' "$YOUR_KEY" | gh secret set VNS_ORACLE_PRIVATE_KEY \
  --env vns-oracle-prod --repo VinuChain/vinuchain-lists
```

### Recent incidents

| Date | Cause | Resolution |
|---|---|---|
| 2026-05-21 | `VNS_ORACLE_PRIVATE_KEY` secret missing from `vns-oracle-prod` env from creation (2026-05-20T04:39Z) onwards; all 5 subsequent cron runs failed silently. Compounding factor: thin VinuSwap V3 pool TWAP froze at `0.0003878450641267948` across multiple runs, so the CoinGecko-vs-pool deviation exceeded the default `500 bps` cap. | Manual refresh broadcast by the oracle owner at tx `0xe28ffd8a0e3af57f34f0cc9af724bfb14a451e68d0a4cb1e55649d2f9aa4dac2` block `1,465,168` (`latestAnswer = 41382` = $0.00041382/VC). Secret subsequently added to GH env. Workflow patched to expose `VNS_ORACLE_MAX_DEVIATION_BPS` as a repo variable, and the script's `Set VNS_ORACLE_PRIVATE_KEY` throw was replaced with an actionable error pointing at this runbook. |

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
