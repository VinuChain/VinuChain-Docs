# Elemont — RPC Breaking Changes

This page documents JSON-RPC behavior that affects infrastructure
consuming the node's interface — indexers, block explorers, dApps, and
anything that parses transaction receipts, tracks supply, or uses the
`eth_*` / `debug_*` / `trace_*` namespaces.

For the validator upgrade procedure, see the
[Chain Upgrade Guide](chain-upgrade-guide.md).

{% hint style="info" %}
**Latest release: `v2.0.7-elemont`** — supersedes v2.0.6-elemont. This
release is a **node-internal hotfix only**: it raises the per-peer
in-flight event-processing quota in the gossip handler so that legitimate
sync chunks (up to 500 events per chunk, 6 in-flight per session peer)
are no longer rejected with the warning `Peer exceeded event processing
quota`. There are **no JSON-RPC surface changes, no new methods, no new
error responses, no consensus changes, no new upgrade flags, and no
receipt or event format changes**. Existing receipts, method selectors,
response shapes, batch caps, concurrency caps, and rate-limit codes are
all identical to v2.0.6. See [§ v2.0.7-elemont Additions](#v207-elemont-additions)
below.

All v2.0.2/v2.0.3/v2.0.4/v2.0.5/v2.0.6 sections below remain in force.
{% endhint %}

{% hint style="info" %}
**Prior release: `v2.0.6-elemont`** — supersedes v2.0.5-elemont. This
release adds a new JSON-RPC method `vc_getPaybackBalance` and an RPC-safe
payback accessor with a process-wide concurrency cap. There are **no
consensus changes, no new upgrade flags, and no receipt or event format
changes**; existing receipts, method selectors, and response shapes are
identical to v2.0.5. See [§ v2.0.6-elemont Additions](#v206-elemont-additions)
below.
{% endhint %}

{% hint style="info" %}
**Prior release: `v2.0.5-elemont`** — supersedes v2.0.4-elemont. This
release adds the `SfcV2Patch2` upgrade flag for testnet, which re-flashes
the SFC contract bytecode at `0xFC00FACE00000000000000000000000000000000`
with the current Cycle-158 source. There are **no RPC surface changes**;
the receipt format, method signatures, and response shapes are identical
to v2.0.4. See [§ v2.0.5-elemont Additions](#v205-elemont-additions) below.

All v2.0.2/v2.0.3/v2.0.4 sections below remain in force; they describe
earlier activations still relevant to infrastructure operators.
{% endhint %}

{% hint style="info" %}
**Latest release: `v2.0.4-elemont`** — supersedes the tagged-but-never-
rolled v2.0.3-elemont. All v2.0.3 additions (defensive RPC caps from
`go-vinu v1.20.14-quota`) apply in v2.0.4 as well. v2.0.4 additionally
bumps lachesis-base to `v0.1.6-elemont`, which carries consensus and
reliability fixes that have **no direct RPC consumer impact** — see
[§ v2.0.4-elemont Additions](#v204-elemont-additions) below. Both
releases take effect **immediately on binary restart** (no epoch-seal
wait).

Most v2.0.3/v2.0.4 caps sit far above typical usage envelopes —
consumer impact is limited to high-volume clients that batched heavily
or submitted large `stateOverride` blobs. See
[§ v2.0.3-elemont Additions](#v203-elemont-additions) below.

All v2.0.2-elemont sections below remain in force; they describe the
one-time consensus-changing activations.
{% endhint %}

{% hint style="warning" %}
**Build requirement (v2.0.2+):** Operators building from source need
**Go 1.25+** (up from Go 1.14 on the pre-v2.0.2 branch). See
[Chain Upgrade Guide — Prerequisites](chain-upgrade-guide.md#prerequisites).
{% endhint %}

{% hint style="info" %}
**Activation timing.**

- **v2.0.3-elemont caps** (batch size, concurrency, state override):
  active immediately on restart. Purely a local-node policy, no epoch
  seal required.
- **v2.0.2-elemont consensus changes** (`feeRefund`, base fee burn,
  Elemont consensus fixes): activate at the **next epoch seal** after a
  node first installs a v2.0.2+ binary. On startup you see three
  `Staged … upgrade from binary rules; will activate at next epoch seal`
  log lines before block processing resumes. Until the seal fires
  (up to ~4h after restart — the `MaxEpochDuration` cap; epochs may seal
  earlier from gas, event count, or cheaters), receipts and fee
  accounting continue to use pre-upgrade behavior. At the seal the new
  rules activate atomically on the same block.
- **v2.0.2+ → v2.0.3 / v2.0.4 upgrades**: if your node already sealed
  an epoch under v2.0.2-elemont, no second activation occurs on v2.0.3
  or v2.0.4. The consensus flags are latched; both are pure binary
  swaps.
- **v2.0.4-elemont lachesis-base bump** (vecengine cap, dagprocessor
  drain fix, kvdb flushable, semaphore metric, gossip deadlock fix):
  active immediately on restart. Internal consensus-engine plumbing
  only — no RPC surface change, no receipt change, no new error
  responses for consumers.
{% endhint %}

---

## v2.0.7-elemont Additions

v2.0.7-elemont is a **pure node-internal hotfix** on top of v2.0.6-elemont.
No consensus rules change, no upgrade flags, no receipt format changes,
no JSON-RPC surface changes, no new methods, and no new error responses
on existing endpoints. Nodes on mixed v2.0.6 / v2.0.7 remain fully
compatible and produce identical state roots.

### What changed

The per-peer in-flight quota in the gossip handler
(`gossip/peer_ratelimit.go`) was sized smaller than a single legitimate
DAG sync chunk:

| Quota                       | v2.0.6 cap | v2.0.7 cap | Sized to                                                |
| --------------------------- | ---------- | ---------- | ------------------------------------------------------- |
| `peerEventQuota` (DAG events) | 200        | 3,250      | `ParallelChunksDownload * DefaultChunkItemsNum + softLimitItems` (matches `DagProcessor.EventsBufferLimit.Num`) |
| `peerStreamQuota` (BV/BR/EP)  | 100        | 3,250      | Same formula                                              |

Because the dagstreamleecher delivers chunks of up to
`DefaultChunkItemsNum = 500` events with `ParallelChunksDownload = 6`
chunks in flight per active sync session (sessions are per-peer via
`IsValidSession`), v2.0.6 dropped every legitimate chunk during catch-up
and logged `Peer exceeded event processing quota` on every drop. v2.0.7
raises both per-peer caps to match the dagprocessor's own buffer
(`EventsBufferLimit.Num = 3,250`).

### DoS guarantee preserved

`gossip/config.go::Config.Validate()` still enforces
`EventsSemaphoreLimit ≥ 2 × EventsBufferLimit`, so the global
event-processing semaphore is at least 6,500 items. A single peer
remains bounded to ≤50% of total capacity (3,250 of ≥6,500). v2.0.7 also
adds a startup sanity assertion that fails fast if anyone ever shrinks
the per-peer cap below the processor buffer in a future change, so this
class of regression cannot recur silently.

### Who is affected

- **Validator and RPC operators**: no consumer-facing action needed.
  After the binary swap, the warning storm stops on the next chunk.
- **dApps, wallets, indexers, explorers**: no action — the JSON-RPC
  surface is byte-for-byte identical to v2.0.6.
- **Network analysts / observability**: any alerting on the
  `Peer exceeded event processing quota` log line should be updated to
  reflect that the warning is now an actual abuse signal rather than
  background sync noise.

### Activation

Immediate on restart. No epoch-seal wait, no staging log, no flag
transition.

---

## v2.0.6-elemont Additions

v2.0.6-elemont is a **pure RPC addition** on top of v2.0.5-elemont. No
consensus rules change, no upgrade flags, no receipt format changes, no
new error responses on existing endpoints. Nodes on mixed v2.0.5 /
v2.0.6 remain fully compatible and produce identical state roots.

### New method: `vc_getPaybackBalance`

| Field            | Value                                                                              |
| ---------------- | ---------------------------------------------------------------------------------- |
| Namespace        | `vc` (not `eth`)                                                                   |
| Method           | `vc_getPaybackBalance`                                                             |
| Params           | `[address]` — 20-byte hex string. Optional second param: block number or `"latest"` (default) |
| Returns          | Hex-encoded wei value (`*hexutil.Big`). Returns `0x0` for the zero address, when Podgorica is inactive, or when the caller stakes below minimum |
| Error `-32005`   | Rate-limit rejection when the process-wide in-flight cap is saturated              |

**Example:**

```bash
curl -s -X POST http://localhost:18545/ \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"vc_getPaybackBalance","params":["0xABCDEF0123456789ABCDEF0123456789ABCDEF01"],"id":1}'
```

Returns the currently available payback balance for the address at the
latest sealed block.

### Concurrency cap and rejection code

Each call executes up to five EVM `StaticCall`s against the payback
proxy and SFC contracts (≈500k gas total), so the handler is gated by a
process-wide semaphore:

| Knob                        | Value      |
| --------------------------- | ---------- |
| Max in-flight calls         | 8          |
| Acquire timeout             | 2 seconds  |
| Rejection error code        | `-32005`   |
| Rejection error message     | `payback query rate-limited` |

Clients should treat `-32005` as a transient rate-limit signal and retry
with backoff. High-volume callers (indexers, scanners) should stagger
requests or open multiple RPC endpoints rather than request a higher
cap.

### Why a new namespace instead of `eth_`?

The accessor is intentionally RPC-safe: it never reads or writes
`PaybackCache.blkCtx` and never mutates `StakesMap`, so concurrent RPC
traffic cannot corrupt in-flight block-processing state. Placing it in
the `vc` namespace keeps it distinct from Ethereum-standard methods and
signals to consumers that it exposes VinuChain-specific accounting
(fee-refund quota under the Podgorica upgrade) rather than EVM state.

### Who is affected

- **dApps, wallets, block explorers**: no action needed. Existing
  `eth_*` / `debug_*` / `trace_*` behavior is unchanged.
- **Scanners/indexers that want payback balance data**: replace any
  prior workaround (reading SFC state directly via `eth_call`) with
  `vc_getPaybackBalance`. The new method returns the final refund
  amount after the five internal StaticCalls that compute it.
- **Clients calling `eth_getPaybackBalance`**: that method never shipped
  in any public release. If you have custom client code referencing it
  from an internal branch, switch to `vc_getPaybackBalance`.

### Activation

Immediate on restart. No epoch-seal wait, no staging log, no flag
transition — the method is registered when the RPC server starts.

---

## v2.0.5-elemont Additions

v2.0.5-elemont ships the same RPC surface as v2.0.4-elemont. The only
addition is the `SfcV2Patch2` upgrade flag (testnet only):

| Scope | Change | Consumer impact |
| --- | --- | --- |
| `SfcV2Patch2` (testnet) | Re-flashes SFC contract bytecode at `0xFC00FACE00000000000000000000000000000000` with current Cycle-158 45,240-byte source at next epoch seal | None for RPC consumers — no new methods, fields, or response shape changes. dApps calling `staticCall` on the SFC will now interact with the corrected bytecode |
| SFC contract verification | After the epoch seal that fires `SfcV2Patch2`, the contract at `0xFC00FACE00000000000000000000000000000000` can be verified on testnet explorer using the current SFC source at [`vinuchain-lists/contracts/vinuchain/SFC.sol`](https://github.com/VinuChain/vinuchain-lists/blob/main/contracts/vinuchain/SFC.sol) and solc 0.5.17 | Infrastructure operators running their own Blockscout instance against testnet can now complete contract verification |

**Who is affected:**

- **Most consumers:** No action needed. The receipt format, method selectors, and ABI for SFC external functions are unchanged.
- **dApps relying on SFC internal state:** The corrected bytecode includes Cycle-158 hardening (reentrancyguard fix, slashing refund timelock, precision fixes). Behavior is compatible with all existing delegations and staking state; no migration is needed.
- **Explorer operators:** Blockscout verification against testnet will succeed after the epoch seal fires the patch.

**Activation timing:** `SfcV2Patch2` fires at the **next epoch seal** after a node running v2.0.5-elemont starts. The node logs:

```text
INFO Staged SfcV2Patch2 upgrade from binary rules; will activate at next epoch seal
```

...at startup, and then at the seal:

```text
INFO Re-applying SFC V2 bytecode upgrade (patch 2)   block=<N>
```

Mainnet is unaffected — `SfcV2Patch2` is not set in mainnet rules.

---

## v2.0.4-elemont Additions

v2.0.4-elemont ships the same RPC surface as v2.0.3-elemont. The only
additions are consensus-engine internals in lachesis-base
`v0.1.6-elemont`:

| Scope | Change | Consumer impact |
| --- | --- | --- |
| `vecengine` | Cap per-validator branch allocation | None — prevents Byzantine vector memory inflation; no observable behavior on healthy networks |
| `dagprocessor` / `gossip` | Drain queued events on quit, prevent checker-exit deadlock | None — only affects clean shutdown paths |
| `kvdb` | Clear flushable write buffer only after successful batch write | None — removes a race that could lose writes on crash mid-batch |
| `semaphore` | Zero metric after termination, clamp underflow | None — metric/debug plumbing |

RPC consumers (indexers, dApps, wallets) **do not need to change
anything** for the v2.0.3 → v2.0.4 bump. All v2.0.3 migration
checklist items below still apply.

---

## v2.0.3-elemont Additions

The following caps and behaviors ship with **`v2.0.3-elemont`** via the
upstream `go-vinu v1.20.14-quota` fork. They are **defensive hardening**
— DoS mitigations, not protocol changes — but high-volume clients may
see new error responses where previously the node accepted unbounded
input.

| Cap / change | RPC method(s) | New limit | Error on exceed |
| --- | --- | --- | --- |
| JSON-RPC batch size ceiling | Any batched call (`POST` with a JSON array) | **100 messages per batch** | `invalid request: batch too large` |
| In-flight RPC concurrency | All HTTP & WS RPC methods | **50 concurrent requests** (new default; configurable via `--rpc.maxconcurrent`) | HTTP 503 Service Unavailable |
| `StateOverride.code` byte cap | `eth_call`, `eth_estimateGas`, `debug_traceCall` | **`MaxCodeSize` (24,576 bytes)** per account | `code size exceeds MaxCodeSize` |
| `StateOverride.stateDiff` entry count | `eth_call`, `eth_estimateGas`, `debug_traceCall` | **1,000 entries per account** | `stateDiff size exceeds 1000 entries` |
| Receipt `feeRefund` byte cap (P2P ingress) | Internal — peer-to-peer receipt RLP decoding | **32 bytes / 256-bit integer** | Peer connection drops offending receipt |
| Graceful shutdown error response | Any RPC method during node shutdown | (new) handler returns proper JSON-RPC error on shutdown instead of silent connection drop | `handler is stopping` |

### Who is affected

- **Batch size (100 msgs):** indexers and explorers sometimes batch
  block-range queries. 100 covers >99% of observed batch sizes on the
  existing testnet; clients hitting this should paginate.
- **Concurrency (50):** the default prevents goroutine flooding on a
  single node. Operators with heavy analytics workloads can raise it via
  `--rpc.maxconcurrent=N` in the node flags; set to 0 for unlimited.
- **`stateOverride` caps:** tools that simulate large contracts
  (`eth_call` with injected contract code) must stay under 24,576 bytes.
  `stateDiff` entry cap of 1,000 is larger than most account storage
  layouts; affects only stress-test or fuzzer workloads.
- **`feeRefund` byte cap:** internal P2P validation only. No consumer
  impact — the cap matches the on-chain 256-bit integer type and
  prevents malformed peer data from entering the node.
- **Graceful shutdown error:** clients that reconnect after an
  interrupted request now receive a descriptive JSON-RPC error instead
  of a bare TCP close. Improves debuggability; no contract break.

### Operator configuration

The concurrency cap accepts a CLI flag:

```bash
opera --rpc.maxconcurrent 100    # allow 100 in-flight RPC requests
opera --rpc.maxconcurrent 0      # disable the cap entirely
```

The batch size cap (100) and `stateOverride` caps are hard-coded.
Clients that batch aggressively should reduce batch size rather than
request a higher cap.

### Migration checklist for v2.0.3-elemont

- [ ] Indexers: split any batch >100 messages into chunks of ≤100
- [ ] Analytics: if you run 50+ concurrent `eth_call` against a single
      node, either set `--rpc.maxconcurrent` to your peak or distribute
      the load across multiple RPC endpoints
- [ ] Tooling: ensure `stateOverride.code` blobs stay under 24,576 bytes
      per account
- [ ] Error handling: accept the new `invalid request: batch too large`
      and `handler is stopping` error strings in retry logic

---

## New `feeRefund` Field in Transaction Receipts

Transaction receipts now include an optional `feeRefund` field (hex-encoded
wei value) for transactions where the sender received a gas fee refund from
the payback system. The field is **omitted** when there is no refund, so
receipts without an associated refund look identical to pre-upgrade
receipts.

{% code title="Example receipt fragment" overflow="wrap" %}

```json
{
  "transactionHash": "0x...",
  "gasUsed": "0x5208",
  "feeRefund": "0x2386f26fc10000"
}
```

{% endcode %}

### Impact on receipt consumers

- Most JSON parsers silently ignore unknown fields, so this is
  non-breaking for typical dApp usage.
- If your pipeline performs strict receipt schema validation, update the
  schema to allow an optional `feeRefund` field (hex string).
- If you compute or compare receipt hashes off-chain, update your encoder
  to include `feeRefund` when present — the on-chain receipt root includes
  it once Podgorica is active.

**Source:** the field is emitted by `ethapi/api.go` only when
`receipt.FeeRefund` is non-nil, so older nodes continue to return receipts
without the field.

The same `feeRefund` key also appears on the transaction object returned
by `eth_getTransactionByHash`, `eth_getTransactionByBlockHashAndIndex`,
and `eth_getTransactionByBlockNumberAndIndex` — not only on receipts.
Clients that read refund amounts off the transaction response (rather
than pulling the receipt) should handle it there as well.

---

## SFC V2 Contract Upgrade

Once the SfcV2 upgrade is active, the Staking for Consensus (SFC) smart
contract is replaced with the V2 implementation. The upgrade activates at
the **next epoch seal** after the binary is installed.

### Contract bytecode replacement

The on-chain SFC contract at `0xfc00face00000000000000000000000000000000`
is rewritten with new bytecode. The V2 contract:

- Maintains **backward compatibility** with existing delegation and staking
  state — all delegations, stakes, and validator registrations remain valid
  and functional.
- Updates the logic for fee distribution, rewards calculation, and validator
  interactions to align with the new fee burn mechanism (see below).
- Does **not** change the function selectors (on-chain ABI) used by the
  driver contract or internal transactions — dApps and on-chain contracts
  calling the SFC continue to work without modification.

**Impact on smart contracts:** If your on-chain contract directly reads SFC
state (e.g., via `staticCall`), you should verify the call succeeds after
the upgrade. Staking, delegation, and withdrawal operations should remain
unaffected.

---

## 30% Base Fee Burn (SfcV2)

Once the SfcV2 upgrade is active, 30% of the **base fee portion** of each
transaction's fee is burned. The remaining 70% of the base fee and **all
priority tips** are credited to the block's validator as before.

{% hint style="info" %}
**London fork requirement:** The base fee burn only applies if the London
upgrade is also active. VinuChain has had London enabled since genesis, so
the burn is active immediately when SfcV2 activates. If running on a network
without London, the burn does not apply (base fees are not defined).
{% endhint %}

### Burn mechanism

The burn is calculated **per transaction** at the end of block processing:

```text
baseFeeUsed = baseFee × gasUsed
burnAmount = baseFeeUsed × 30%
(capped at the validator's fee share, so it never exceeds what they'd earn)
validatorEarnings = transactionFee - feeRefund - burnAmount
```

- **Base fee only** — priority tips (miner tips) are never burned; they
  continue to flow entirely to the validator.
- **Per-block accrual** — the burn happens in the same transaction that
  credits the validator, not in a separate post-block settlement.
- **Order of operations** — refunds (Podgorica) are calculated first, then
  the burn is applied to what remains.

### Impact on reward accounting

- **Validator rewards decrease** — validators receive 70% of base fees
  instead of 100%, a ~30% reduction in base-fee-derived revenue.
- **Circulating supply decreases** — burned base fees accumulate at the zero
  address, reducing the effective circulating supply over time.
- **APY recalculation required** — staking APY estimates that assume 100% of
  fees flow to validators will overstate actual validator returns by ~30%
  (on base fee components only).
- **Block reward structure** — the burn does not affect priority tips or
  post-internal transaction rewards; only the base fee is affected.

{% hint style="warning" %}
**Indexers tracking supply:** burned funds are transferred on-chain to the
zero address `0x0000000000000000000000000000000000000000`. If you compute
circulating supply by snapshotting balances, treat the zero-address balance
as burned (subtract it from circulating totals). There is no separate
"burned" counter — the zero-address balance is the source of truth.

**Example:** If 1,000 VC has accumulated at the zero address since the SfcV2
activation, subtract 1,000 from your circulating supply total.
{% endhint %}

---

## Cheater Fee Zeroing (Elemont)

When the Elemont upgrade is active, validators flagged as cheaters in an
epoch have **all** their accumulated transaction fees for that epoch zeroed
out at epoch seal time. This is applied when submitting the `SealEpoch`
transaction to the SFC contract.

### Impact on rewards

- **Cheater penalties increase** — instead of losing future rewards, cheaters
  lose all fees earned in the epoch they're caught, including fees from
  transactions before they were flagged.
- **Interaction with base fee burn** — the burn mechanism still applies
  per-transaction during block processing, but the final fee (after burn)
  is discarded anyway if the validator is later marked a cheater.

**Example scenario:**

1. Validator `A` produces 10 blocks in epoch N, earning 100 VC in fees (after
   30% burn).
2. Validator `A` is detected as a cheater during epoch N.
3. At epoch seal, instead of receiving 100 VC, validator `A` receives 0 VC.

---

## Database & State Compatibility

**No state resync required.** All three upgrades (SfcV2, Podgorica, Elemont)
are compatible with the existing LevelDB chain state. The binary upgrade does
not change the storage schema or require database migration:

- **Existing delegations/stakes** remain valid under SFC V2 — no state
  migration happens.
- **Chain state** from blocks before the upgrade is unchanged and remains
  queryable.
- **Block history** is preserved — querying old blocks (before SfcV2/Elemont
  activation) returns pre-upgrade results.
- **No snapshot import needed** — a simple binary swap and restart is
  sufficient; no full resync from genesis.

Validators who miss the upgrade window can recover by installing the new
binary and restarting (see "Recovering a validator that missed the upgrade"
in the [Chain Upgrade Guide](chain-upgrade-guide.md)).

---

## Payback Fee Refunds

Stakers meeting the minimum stake threshold automatically receive gas fee
refunds after each transaction they originate. This is the user-visible
effect of the Podgorica upgrade and the `feeRefund` receipt field above.

### How payback refunds work (without creating supply)

**Key principle:** Refunds are a **redistribution** of existing transaction
fees, not new money creation. The on-chain mechanics are:

1. User submits a transaction with a declared `gasPrice`.
2. EVM execution consumes the full `gasUsed × gasPrice` from the sender's
   account (same as pre-Podgorica).
3. Full fee is credited to the validator (pre-refund, the fee is already
   out of the sender's balance).
4. **After epoch seal** — the payback system queries the sender's stake via
   the SFC contract. If the sender meets the minimum stake threshold, a
   **refund amount is returned from the validator's earned fees**.
5. The validator's total earnings decrease by the refund amount; the sender's
   balance increases by it.

**Result:** No new VC is created; the refund is simply moved from validator
earnings to the eligible staker. The total money supply is unchanged.

### Impact on gas accounting

- The `feeRefund` field appears in receipts for eligible senders only.
- Effective gas cost is lower for qualifying stakers — dApps showing "gas
  spent" metrics from receipts should subtract `feeRefund` from the raw
  `gasUsed * effectiveGasPrice` calculation.
- Refunds are applied **after** EVM execution. They do not change the
  declared `gasPrice`, `gasLimit`, or the `gasUsed` reported in the
  receipt.
- A transaction's nominal fee still leaves the sender's balance during
  execution; the refund is a separate state transition in the same block.

---

## Performance & Reliability Improvements

The Elemont release includes several performance optimizations and reliability
fixes across RPC, tracing, gas accounting, and pruning subsystems.

### RPC concurrency limiting

The `MaxConcurrentRPC` configuration now enforces HTTP/WebSocket request
concurrency limits in-process. Requires the go-vinu v1.20.9+ upgrade.

**Impact:**

- Prevents RPC endpoint saturation under load
- Queues excess requests gracefully instead of accepting unlimited connections
- Operators can tune `MaxConcurrentRPC` to match server capacity

### TX tracing optimizations

Several fixes improve the stability and efficiency of the `trace_*` RPC
namespace:

- **Unbounded memory accumulation fix** — `trace_filter` with `Count==0` now
  caps results at 10,000 entries per request instead of accumulating
  unbounded results across up to 1000 blocks (could reach 100s of MB).
- **Span map leak fix** — toggling tracing on/off no longer leaks in-flight
  span objects in memory.
- **Trace storage error propagation** — errors during trace storage are now
  properly logged at info level instead of silently swallowed.
- **Bounds checking** — `traceBlock` replay path now guards array indices
  to prevent panics on malformed receipts.

**Impact:** Trace endpoints no longer cause OOM errors on high-throughput
chains.

### FeeHistory response fix

`eth_feeHistory` response now properly copies the tips slice per entry
instead of sharing the same backing array. Pre-fix, mutating one entry could
corrupt all other entries.

**Impact:** RPC consumers using `feeHistory` results to estimate gas prices
no longer risk data corruption.

### Gas accounting fixes

- **Block vote gas overflow** — the consensus layer's block vote gas
  calculation now uses overflow-safe addition, preventing vote spam if
  governance sets `BlockVotesBaseGas` to a large value.
- **Gas oracle div-by-zero** — the gas price oracle guards against
  `MaxAllocPeriod=0` set via governance, preventing division by zero
  panics.
- **MinGasPrice validation** — governance cannot set `MinGasPrice` to zero,
  preventing EVM execution on zero-cost transactions.

### Pruning improvements

- **Negative flag validation** — `--prune-keep-epochs` and
  `--prune-keep-blocks` now reject negative values with a clear error
  instead of wrapping to large unsigned values.
- **Receipt pruning** — new `opera snapshot prune-receipts` subcommand
  for fine-grained receipt retention control.
- **Pruning recovery** — if a pruning operation is interrupted (node
  crash), the next startup automatically resumes the interrupted prune.
- **Snapshot config tuning** — restored Snapshots `count=128` for better
  snapshot distribution.

**Impact:** Pruning is more robust, error messages are clearer, and recovery
from node crashes is automatic.

### EVM execution guards

- `eth_call` now enforces `MaxCodeSize` limit even when code is provided
  via state overrides, preventing oversized contract simulations.

---

## Build & Tooling Changes

### Minimum Go Version: 1.14 → 1.25+

The Elemont release requires **Go 1.25 or later** to build from source.
The previous production branch (`main`) supported Go 1.14.

#### Impact on Node Operators

- **Pre-built binaries:** If you download the pre-built `opera` binary
  from the release page, Go is already compiled in — no action needed.
- **Building from source:** You must upgrade your Go toolchain before
  running `make opera`.

#### Upgrading Go

Detailed upgrade instructions are in the [Chain Upgrade Guide](chain-upgrade-guide.md#prerequisites) under "Go Version Upgrade (1.14 → 1.25+)".

Quick verification:

```bash
go version
# Expected: go version go1.25.N linux/amd64 (or later, or different arch)
```

---

## See Also

- [Chain Upgrade Guide](chain-upgrade-guide.md) — full validator upgrade
  runbook including verification steps.
