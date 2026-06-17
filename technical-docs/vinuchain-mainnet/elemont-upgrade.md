# VinuChain ELEMONT Upgrade

The **ELEMONT** upgrade is VinuChain mainnet's hard-fork to the modern EVM and the
V2 staking contract. It is **live on mainnet** (chain ID `207`). This page is the
single reference for what ELEMONT changed, the new RPC surface it exposes, and
what node operators need to know.

> **TL;DR** — Mainnet now runs SfcV2 (V2 staking + 30% base-fee burn), the
> Shanghai / Cancun / Prague EVM (including EIP-7702 set-code transactions), the
> Elemont consensus fixes, and canonical-pubkey validation for validators — on
> top of the already-live Llr and Podgorica (Payback) features. The node also
> exposes a branded `vc_*` JSON-RPC namespace, `vc_getPaybackBalance`, and
> `eth_config`. Fee-refund (feeless) transactions and ERC-4337 account
> abstraction both work on mainnet.

## What activated on mainnet

| Feature | What it means |
|---|---|
| **SfcV2** | V2 SFC (staking) bytecode at `0xFC00FACE…0000`, with a **30% burn of the validator base-fee share**. |
| **Shanghai** | `PUSH0`, warm coinbase, and Shanghai transaction rules. |
| **Cancun** | Transient storage (`TLOAD`/`TSTORE`), `MCOPY`, `BLOBBASEFEE`, and the Cancun `SELFDESTRUCT` semantics. |
| **Prague** | **EIP-7702 set-code transactions** (type `0x04`) — EOAs can delegate to contract code, the foundation for account-abstraction UX on ordinary wallets. |
| **Elemont** | Consensus-critical correctness fixes (merged no-cheaters view, full ABI decode of epoch advances, cheater-fee zeroing, deterministic vector-clock tie-breaking, stable median-time sort, empty-pubkey validator skip at epoch seal). |
| **ElemontPubkeyValidation** | Validator pubkeys must be the canonical 66-byte `0xc0`-prefixed Secp256k1 form at every on-chain ingress (`createValidator`, `_rawCreateValidator`, `updateValidatorPubkey`). Malformed keys are rejected. |

Berlin, London (EIP-1559 base fee), **Llr**, and **Podgorica** (the Payback /
fee-refund system) were already active on mainnet before ELEMONT and remain so.

You can confirm the live rule set at any time:

```bash
curl -s -X POST https://vinuchain-rpc.com \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getRules","params":["latest"],"id":1}' \
  | python3 -m json.tool
# Expect Upgrades.{Berlin,London,Shanghai,Cancun,Prague,Llr,Podgorica,SfcV2,Elemont,ElemontPubkeyValidation} = true
# and Economy.QuotaCacheAddress = 0x1c4269fbbd4a8254f69383eef6af720bcd0acda6
```

## New RPC surface

ELEMONT ships a richer RPC surface, available on the public mainnet endpoint
`https://vinuchain-rpc.com`:

| Method | Purpose |
|---|---|
| `vc_*` namespace | The full `eth_*` JSON-RPC surface is mirrored under a branded `vc_` namespace — e.g. `vc_blockNumber`, `vc_call`, `vc_getBalance`, `vc_getTransactionReceipt`, `vc_sendRawTransaction`, `vc_getRules`. (Filter/subscription methods such as `eth_getLogs` / `eth_subscribe` remain under `eth` only.) |
| `vc_getRules(blockTag)` | Active network rules for the epoch, including every upgrade flag and `Economy.QuotaCacheAddress`. |
| `vc_getPaybackBalance(address, blockTag)` | The wallet's currently available Payback quota in wei (its fee-refund cap for the next transaction). Process rate-limited; overload returns error `-32005`. |
| `eth_config` / `vc_config` | Returns the current / next / last fork configuration — `chainId`, `forkId`, the per-fork `activationBlock` (VinuChain forks at block height), and the precompile map. |

See [Public API Endpoints](../api/public-api-endpoints.md) for the full endpoint
list.

## What this means for you

### dApp developers
* **Modern EVM.** Solidity targeting the `shanghai`, `cancun`, or `prague` EVM
  versions compiles and runs on mainnet — `PUSH0`, transient storage, and
  EIP-7702 are all available. See
  [Deploy a Smart Contract](../smart-contracts/deploy-a-smart-contract.md).
* **Account abstraction.** ERC-4337 works on mainnet at the canonical
  cross-chain addresses. See
  [Account Abstraction (ERC-4337)](../smart-contracts/account-abstraction.md).
* **Feeless transactions.** Stake into the Payback/Quota contract and eligible
  transactions get their gas refunded on-chain. See
  [Feeless Transactions for Developers](../smart-contracts/feeless-transactions.md).

### Stakers & validators
* The V2 SFC governs staking, delegation, lockups, and rewards; 30% of the
  validator base-fee share is burned.
* New validators must register a canonical 66-byte `0xc0`-prefixed pubkey;
  malformed keys are rejected at `createValidator`. See
  [Become a Validator](../nodes-and-validators/become-a-validator.md).
* Fee-refund eligibility is driven by Payback staking — see
  [Staking → Overview](../staking/overview.md).

### Wallet users
No action is required. Existing VC balances, addresses, and the chain ID (`207`)
are unchanged. Transactions benefit from the modern EVM and, for Payback-eligible
wallets, on-chain fee refunds.

## Node operators

The current node release is **`v2.0.39-elemont`**. Build it from source:

```bash
git clone https://github.com/VinuChain/VinuChain.git
cd VinuChain
git checkout v2.0.39-elemont
make opera          # -> build/opera
```

Requirements: **Go 1.25+**, a C compiler, git, and ≥ 50 GB free disk. The build
pins `go-vinu v1.20.24-quota` and `lachesis-base v0.1.6-elemont` via `go.mod`.

**Upgrading an existing node** is an in-place binary swap — stop the node with a
clean `SIGINT` (never `SIGKILL`, which corrupts LevelDB), replace `build/opera`,
and restart. The node continues from its existing datadir.

**Fresh installs** should restore from a current post-ELEMONT chaindata snapshot
rather than replaying from the original genesis. Replaying an old genesis through
the fork activations can diverge with `wrong event epoch hash`; a recent snapshot
seals every activated flag and avoids the replay. See
[Read-Only Node](../nodes-and-validators/read-only-node.md) and
[Chain Upgrade Guide](../vinuchain-testnet/chain-upgrade-guide.md).

> **TxIndex must stay enabled.** ELEMONT's PaybackCache restart warm-up replays
> recently-sealed blocks into the in-memory Payback cache on boot to keep
> fee-refund accounting deterministic across restarts. A node started with
> transaction indexing disabled **refuses to start** (fail-closed) rather than
> risk divergence; if a node previously ran without TxIndex it must be re-synced
> (from a snapshot) with indexing on.

Verify a node is on ELEMONT after it syncs:

```bash
# Client version should report v2.0.39-elemont
curl -s -X POST http://localhost:18545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'
```

## Also running on testnet

VinuChain testnet (chain ID `206`) runs the full ELEMONT release **plus** several
capabilities that are exercised on testnet ahead of their own mainnet releases.
These are **testnet-only** today and are **not** part of the mainnet ELEMONT
feature set:

* **PaybackV2** — a non-proxy `QuotaContractV2` (with receiver-funded
  `stakeFor`/`unstakeFor` staking) that replaces the original Quota proxy.
  Mainnet continues to run Payback on its original Quota proxy
  `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6`.
* **BLS12-381 precompiles** (EIP-2537, precompiles `0x0b`–`0x11`).
* **Latest-EVM** — the `P256VERIFY` precompile (`0x0100`) and the EIP-7825
  per-transaction gas cap.

## See also

* [Network Details](../network-details.md) — chain IDs, RPC/WS, explorers, key contracts
* [Public API Endpoints](../api/public-api-endpoints.md) — full RPC reference incl. the `vc_*` surface
* [Connect to Mainnet](./connect-to-mainnet.md) — wallet quick-add
* [Master Contracts Reference](../smart-contracts/contracts-master-list.md)
