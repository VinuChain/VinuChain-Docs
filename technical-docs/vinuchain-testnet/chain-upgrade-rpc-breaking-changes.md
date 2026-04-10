# Elemont Hard Fork — RPC Breaking Changes

The `v1.0.1-elemont` upgrade introduces several behaviors that affect
infrastructure consuming the node's JSON-RPC interface — indexers, block
explorers, dApps, and anything that parses transaction receipts or tracks
supply.

This page documents only the consumer-visible changes. For the validator
upgrade procedure, see the [Chain Upgrade Guide](chain-upgrade-guide.md).

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

## 30% Base Fee Burn

Once the SfcV2 upgrade is active, 30% of the **base fee portion** of each
transaction's fee is burned. The remaining 70% of the base fee and **all
priority tips** are credited to the block's validator as before.

### Impact on reward accounting

- Validator reward accounting changes: validators receive less per block
  than they did under the old formula.
- Effective circulating supply decreases over time as base fees are burned.
- Staking APY estimates that assume the full fee flowed to validators need
  to be recalculated.

{% hint style="warning" %}
**Indexers tracking supply:** burned funds are transferred on-chain to the
zero address `0x0000000000000000000000000000000000000000`. If you compute
circulating supply by snapshotting balances, treat the zero-address balance
as burned (subtract it from circulating totals). There is no separate
"burned" counter — the zero-address balance is the source of truth.
{% endhint %}

---

## Payback Fee Refunds

Stakers meeting the minimum stake threshold automatically receive gas fee
refunds after each transaction they originate. This is the user-visible
effect of the Podgorica upgrade and the `feeRefund` receipt field above.

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

## See Also

- [Chain Upgrade Guide](chain-upgrade-guide.md) — full validator upgrade
  runbook including verification steps.
