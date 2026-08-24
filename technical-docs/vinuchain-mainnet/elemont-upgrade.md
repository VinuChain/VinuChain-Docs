# VinuChain ELEMONT Upgrade

The **ELEMONT** upgrade is VinuChain mainnet's hard-fork to the modern EVM and the
V2 staking contract. It is **live on testnet (chain ID `206`)** and is **scheduled
for mainnet (chain ID `207`) on 29 August 2026 at 10:00 UTC**. This page is the
single reference for what ELEMONT changes, the new RPC surface it exposes, and
what node operators need to know.

{% hint style="warning" %}
**Mainnet has not activated ELEMONT yet.** Until the 29 August activation seals,
mainnet runs the pre-ELEMONT rule set — `Berlin`, `London`, `Llr`, `Podgorica` —
and the **V1** SFC staking contract. Everything on this page described as an
ELEMONT feature is live on testnet today and arrives on mainnet at that
activation.

Node operators: the step-by-step procedure is in the
[Mainnet Upgrade Guide (ELEMONT)](chain-upgrade-guide.md). Two pre-flight items
(transaction indexing and the Go toolchain) need lead time — start now.
{% endhint %}

> **TL;DR** — The 2026-08-29 release brings mainnet to **full parity with
> testnet**: SfcV2 (V2 staking + 30% base-fee burn), the Shanghai / Cancun /
> Prague EVM (including EIP-7702 set-code transactions), the Elemont consensus
> fixes, canonical-pubkey validation, the BLS12-381 and latest-EVM precompiles,
> and PaybackV2 (a new fee-refund contract) — on top of the already-live Llr and
> Podgorica features. The new binary also exposes a branded `vc_*` JSON-RPC
> namespace, `vc_getPaybackBalance`, and `eth_config`. **Fee-refund stakers must
> migrate to the new Payback contract** — see the
> [Mainnet Upgrade Guide](chain-upgrade-guide.md#if-you-stake-in-the-payback-fee-refund-contract).
> Activation crosses five consecutive epoch seals over roughly 17 hours.

## Check what mainnet is running right now

Do not take this page's word for it — ask the chain:

```bash
curl -s -X POST https://rpc.vinuchain.org \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getRules","params":["latest"],"id":1}' \
  | python3 -m json.tool
```

* **Before the activation:** `Upgrades` contains exactly `Berlin`, `London`,
  `Llr`, `Podgorica`.
* **After the activation:** it additionally reports `Shanghai`, `Cancun`,
  `Prague`, `SfcV2`, `Elemont`, `ElemontPubkeyValidation`, `VinuBLS12381`,
  `VinuLatestEVM`, and `PaybackV2` — and `Economy.QuotaCacheAddress` **changes**
  from the V1 proxy `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6` to the new
  `QuotaContractV2`. The flags arrive across five consecutive epoch seals, not
  all at once.

The SFC staking contract's own version is the clearest single signal:

```bash
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"0xFC00FACE00000000000000000000000000000000","data":"0x54fd4d50"},"latest"],"id":1}'
# 0x3330340...  = "304" = SFC V1  (pre-ELEMONT)
# 0x3330350...  = "305" = SFC V2  (post-ELEMONT)
```

## What ELEMONT activates on mainnet

| Feature | What it means |
|---|---|
| **SfcV2** | V2 SFC (staking) bytecode at `0xFC00FACE…0000`, with a **30% burn of the validator base-fee share**. |
| **Shanghai** | `PUSH0`, warm coinbase, and Shanghai transaction rules. |
| **Cancun** | Selected (non-blob) Cancun: transient storage (`TLOAD`/`TSTORE`), `MCOPY`, and the Cancun `SELFDESTRUCT` (EIP-6780) semantics. Blob transactions (EIP-4844) and the `BLOBBASEFEE` opcode (EIP-7516) are **not** enabled. |
| **Prague** | **EIP-7702 set-code transactions** (type `0x04`) — EOAs can delegate to contract code, the foundation for account-abstraction UX on ordinary wallets. |
| **Elemont** | Consensus-critical correctness fixes (merged no-cheaters view, full ABI decode of epoch advances, cheater-fee zeroing, deterministic vector-clock tie-breaking, stable median-time sort, empty-pubkey validator skip at epoch seal). |
| **ElemontPubkeyValidation** | Validator pubkeys must be the canonical 66-byte `0xc0`-prefixed Secp256k1 form at every on-chain ingress (`createValidator`, `_rawCreateValidator`, `updateValidatorPubkey`). Malformed keys are rejected. |
| **VinuBLS12381** | The EIP-2537 BLS12-381 precompile family at `0x0b`–`0x11`. |
| **VinuLatestEVM** | `P256VERIFY` at `0x0100`, `CLZ`, MODEXP bounds/repricing, and the EIP-7825 per-transaction gas cap. |
| **PaybackV2** | Payback / fee-refund moves off the V1 Quota proxy onto a newly deployed non-proxy `QuotaContractV2`. **Fee-refund stakers must migrate.** |

Berlin, London (EIP-1559 base fee), **Llr**, and **Podgorica** (the Payback /
fee-refund system) are already active on mainnet today and remain so.

## New RPC surface

ELEMONT ships a richer RPC surface. It is live on the testnet endpoint
`https://vinufoundation-rpc.com` today, and arrives on the public mainnet
endpoint `https://rpc.vinuchain.org` with the 29 August activation. Of these,
only `vc_getRules` is available on mainnet's current binary.

| Method | Purpose | On mainnet today? |
|---|---|---|
| `vc_*` namespace | The full `eth_*` JSON-RPC surface mirrored under a branded `vc_` namespace — e.g. `vc_blockNumber`, `vc_call`, `vc_getBalance`, `vc_getTransactionReceipt`, `vc_sendRawTransaction`, `vc_getRules`. (Filter/subscription methods such as `eth_getLogs` / `eth_subscribe` remain under `eth` only.) | Partial — `vc_getRules` yes |
| `vc_getRules(blockTag)` | Active network rules for the epoch, including every upgrade flag and `Economy.QuotaCacheAddress`. | **Yes** |
| `vc_getPaybackBalance(address, blockTag)` | The wallet's currently available Payback quota in wei (its fee-refund cap for the next transaction). Process rate-limited; overload returns error `-32005`. | No — arrives with ELEMONT |
| `eth_config` / `vc_config` | Returns the current / next / last fork configuration — `chainId`, `forkId`, the per-fork `activationBlock` (VinuChain forks at block height), and the precompile map. | No — arrives with ELEMONT |

See [Public API Endpoints](../api/public-api-endpoints.md) for the full endpoint
list.

## What this means for you

### dApp developers
* **Modern EVM — after the activation.** Solidity targeting the `shanghai`,
  `cancun`, or `prague` EVM versions compiles and runs on mainnet once ELEMONT
  seals; `PUSH0`, transient storage, and EIP-7702 all become available. **Do not
  deploy Shanghai-or-later bytecode to mainnet before then** — mainnet is a
  London-era EVM until the seal. See
  [Deploy a Smart Contract](../smart-contracts/deploy-a-smart-contract.md).
* **Account abstraction.** ERC-4337 is live on testnet at the canonical
  cross-chain addresses. See
  [Account Abstraction (ERC-4337)](../smart-contracts/account-abstraction.md) for
  current per-network availability.
* **Feeless transactions.** Already live on mainnet via Podgorica: stake into the
  Payback/Quota contract and eligible transactions get their gas refunded
  on-chain. ELEMONT does not change this, and mainnet keeps using the V1 Quota
  proxy `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6`. See
  [Feeless Transactions for Developers](../smart-contracts/feeless-transactions.md).

### Stakers & validators
* After the activation, the V2 SFC governs staking, delegation, lockups, and
  rewards, and 30% of the validator base-fee share is burned. If you integrate
  against the SFC ABI directly, re-check your bindings against V2.
* From the activation onward, new validators must register a canonical 66-byte
  `0xc0`-prefixed pubkey; malformed keys are rejected at `createValidator`. See
  [Become a Validator](../nodes-and-validators/become-a-validator.md).
* Fee-refund eligibility is driven by Payback staking — see
  [Staking → Overview](../staking/overview.md).

### Wallet users
No action is required. Existing VC balances, addresses, and the chain ID (`207`)
are unchanged by ELEMONT.

## Node operators

**Mainnet operators: follow the [Mainnet Upgrade Guide (ELEMONT)](chain-upgrade-guide.md).**
It covers the pre-flight checks, the swap procedure, activation timing, the
verification checklist, and rollback. The summary:

The mainnet ELEMONT release is **`v2.0.49-elemont`** — the final one-install binary for 2026-08-29, superseding v2.0.48 with no EVM, state-transition, receipt-encoding, chain-rule, activation-height, or protocol-capability changes. Build it from source at commit `8b88cc49d11e56635385413fe8f9eaec1969c1ac`:

**Prebuilt binary** (linux/amd64) is attached to the [`v2.0.49-elemont` release](https://github.com/VinuChain/VinuChain/releases/tag/v2.0.49-elemont):

```bash
curl -LO https://github.com/VinuChain/VinuChain/releases/download/v2.0.49-elemont/opera-v2.0.49-elemont-linux-amd64
sha256sum -c <<< "678040e9f88a98331a8cc32b7bf5b9e0ae4acdf84919390465eeee584b7f56c1  opera-v2.0.49-elemont-linux-amd64"
chmod +x opera-v2.0.49-elemont-linux-amd64
./opera-v2.0.49-elemont-linux-amd64 version   # Version: 2.0.49-elemont
```

It requires **GLIBC_2.34** or newer, so it runs on Ubuntu 22.04 and later.

**Or build from source:**

```bash
git clone https://github.com/VinuChain/VinuChain.git
cd VinuChain
git checkout v2.0.49-elemont
test "$(git rev-parse HEAD)" = 8b88cc49d11e56635385413fe8f9eaec1969c1ac
make opera          # -> build/opera
```

Requirements: **Go 1.25.13+**, a C compiler, git, and ≥ 50 GB free disk. The
build pins `go-vinu v1.20.26-quota` and `lachesis-base v0.1.6-elemont` via
`go.mod`. Note that mainnet's current binary was built with Go 1.19 — the
toolchain upgrade is part of this work.

**Upgrading an existing node** is an in-place binary swap — stop the node with a
clean `SIGINT` (never `SIGKILL`, which corrupts LevelDB), replace the `opera`
binary, and restart. The node continues from its existing datadir. Activation
then fires at the **first epoch seal** after the validator set is on the new
binary — mainnet epochs seal at most every 4 hours.

**Fresh installs** should restore from a post-activation chaindata snapshot
rather than replaying from the original genesis. Replaying a pre-activation
genesis under the post-ELEMONT binary re-stages the fork activations at the wrong
epoch seal and diverges with `wrong event epoch hash`. See
[Read-Only Node](../nodes-and-validators/read-only-node.md) and the
[Mainnet Upgrade Guide](chain-upgrade-guide.md).

> **TxIndex must stay enabled.** ELEMONT's PaybackCache restart warm-up replays
> recently-sealed blocks into the in-memory Payback cache on boot to keep
> fee-refund accounting deterministic across restarts. A node started with
> transaction indexing disabled **refuses to start** (fail-closed) rather than
> risk divergence; if a node previously ran without TxIndex it must be re-synced
> (from a snapshot) with indexing on. Check this **before** upgrade day — there
> is no in-place fix.

Verify a node is on ELEMONT after it syncs:

```bash
# Client version should report v2.0.49-elemont
curl -s -X POST http://localhost:18545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'
```

## Also running on testnet

VinuChain testnet (chain ID `206`) has been running this entire feature set for
months, and the 29 August release brings mainnet to parity with it. After the
activation the two networks carry the same capabilities.

The only flags testnet has that mainnet will **not** set are repair mechanisms,
not features:

* **`SfcV2Patch1`–`SfcV2Patch10`** — re-flash flags that brought testnet's SFC
  bytecode up to date after its early SfcV2 activation. Mainnet's first SfcV2
  activation installs the latest corrected bytecode directly. This is verifiable
  rather than assumed: the bytecode a fresh activation installs is byte-identical
  to what testnet reached after all ten patches (48,757 bytes, sha256
  `134a508b13d46647052b64f8d6691f0b939d2afaa0fa400882c6653a40a77887`).
* **`PaybackV2Patch`** — re-runs the PaybackV2 address rebinding for a chain that
  crossed that edge with a wrong address. Mainnet crosses it once, correctly.

So mainnet reaches **identical on-chain state** to testnet in one step rather than
replaying testnet's correction history.

## See also

* [Mainnet Upgrade Guide (ELEMONT)](chain-upgrade-guide.md) — the operator procedure for 29 August
* [Network Details](../network-details.md) — chain IDs, RPC/WS, explorers, key contracts
* [Public API Endpoints](../api/public-api-endpoints.md) — full RPC reference incl. the `vc_*` surface
* [Connect to Mainnet](./connect-to-mainnet.md) — wallet quick-add
* [Master Contracts Reference](../smart-contracts/contracts-master-list.md)
