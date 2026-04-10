# Elemont Hard Fork — RPC Breaking Changes

The `v1.0.1-elemont` upgrade introduces several behaviors that affect
infrastructure consuming the node's JSON-RPC interface — indexers, block
explorers, dApps, and anything that parses transaction receipts or tracks
supply.

This page documents only the consumer-visible changes. For the validator
upgrade procedure, see the [Chain Upgrade Guide](chain-upgrade-guide.md).

{% hint style="warning" %}
**Build requirement change:** Operators building the binary from source
must upgrade to **Go 1.25+** (from Go 1.14 on the production branch).
See "Go Version Upgrade" in the [Chain Upgrade Guide](chain-upgrade-guide.md#prerequisites).
{% endhint %}

{% hint style="info" %}
**Activation timing.** All changes listed here activate at the **next
epoch seal** after a node installs the new binary. On startup, the new
binary stages the three upgrade flags (`Podgorica`, `SfcV2`, `Elemont`)
into the node's pending rules — you will see three
`Staged … upgrade from binary rules; will activate at next epoch seal`
log lines before block processing resumes. Until the next epoch seal
fires (up to ~4h after restart — the `MaxEpochDuration` cap; epochs can
seal earlier if triggered by gas, event count, or cheaters), receipts
and fee accounting continue to use pre-upgrade behavior. At the seal,
the new rules activate atomically: `feeRefund` begins appearing on
eligible receipts, the 30% base fee burn starts, and the Elemont
consensus fixes take effect — all on the same block.
{% endhint %}

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
