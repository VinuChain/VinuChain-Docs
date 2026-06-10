# Feeless Transactions for Developers

VinuChain is **determinably feeless**: eligible wallets get their gas fees
**refunded** after a transaction is mined. This page is the developer-facing
guide to integrating with that system — the Payback/Quota contract, the
staking interface, the on-chain refund signal, and the `vc_` RPC namespace —
with a copy-paste end-to-end example you can run against the public testnet.

> **"Feeless" means refunded, not zero-charge.** A Payback-eligible
> transaction still debits the sender's balance for `gasUsed × gasPrice` when
> it executes, exactly like any EVM transaction. The protocol then credits a
> separate `feeRefund` back to the sender in the same state transition. The
> net cost is zero (or partial) **after** the refund, but the wallet must hold
> enough balance to pay the gas up front. Code that assumes a literal
> zero-cost transaction (e.g. estimating with `gasPrice: 0`) will not work —
> send a normal transaction and read the refund from the receipt.

## How the refund works

The refund is computed and applied by the node during block processing
(`evmcore/state_transition.go`), not by a smart contract call you make. The
flow for a refunded transaction is:

1. The sender's wallet must have at least `minStake()` VC staked into the
   Payback/Quota contract (directly, or via `stakeFor`).
2. When the transaction executes, the node looks up the wallet's currently
   available Payback **quota** (an amount denominated in wei).
3. The fee `gasUsed × gasPrice` is charged as usual, then a `feeRefund` of
   `min(fee, availableQuota)` is added back to the sender's balance.
4. The granted `feeRefund` is recorded on the transaction receipt.

If the wallet's available quota is `0` (not staked, below `minStake()`, or
quota already exhausted for the period), `feeRefund` is `0x0` and the
transaction simply pays normal gas. If the quota is smaller than the fee, the
refund is **partial**.

> **Congestion guard.** When network demand pushes the EIP-1559 base fee above
> the chain-configured floor, the node **suppresses Payback refunds** so fee
> escalation can still deter spam (`refundGas` in
> `evmcore/state_transition.go`). Under congestion an otherwise-eligible
> transaction can return `feeRefund: 0x0`. This is expected behavior, not a
> failure.

## Eligibility: staking for Payback

### The minimum stake

A wallet only becomes refund-eligible once its Payback stake reaches the
contract's `minStake()`. On the active testnet QuotaContract V2 this is
`1000 VC` (verified live: `minStake()` returns
`1000000000000000000000` wei). The value is owner-configurable via
`setMinStake(uint256)`, so always read it from the contract rather than
hard-coding it. Below the minimum, transactions pay normal gas and show
`feeRefund: 0x0`.

### Quota is dynamic (anti-spam)

The Payback quota a wallet accrues is **not** a flat per-stake allowance — it
scales with the wallet's share of total stake and with elapsed time, and
shrinks as the total Payback stake across all users grows. In practice
(see [Staking → Overview](../staking/overview.md)):

* The more VC a single wallet stakes for Payback, the larger its quota.
* The more VC staked for Payback in total by everyone, the smaller each
  wallet's share.
* `minStake()` is only an **eligibility floor**, not an automatic spam
  throttle. Each refunded transaction consumes that wallet's available quota.
  Once exhausted, later transactions pay normal gas and receive a partial
  refund or `feeRefund: 0x0` until quota accrues again.

You can read a wallet's current available quota directly with the
`vc_getPaybackBalance` RPC method (below) — it returns the wei amount the node
would use as the refund cap for that wallet's next transaction.

## The Payback / Quota contract

| | Value |
|---|---|
| **Active contract (testnet)** | `0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4` |
| **Network** | VinuChain Testnet (chain ID `206`) |
| **RPC** | `https://vinufoundation-rpc.com` |
| **Explorer** | [testnet.vinuexplorer.org](https://testnet.vinuexplorer.org) |

> The testnet contract address above supersedes an earlier 2026-05-15
> deployment that had different `stakeFor` withdrawal semantics. Do not use the
> older address. Confirm the address the node is actually enforcing at any time
> with `vc_getRules("latest")` → `Economy.QuotaCacheAddress` (see below).
> The mainnet PaybackV2 contract is part of a later rollout; until then,
> integrate and test on testnet.

### Getting the ABI

The canonical ABI is published in the ecosystem registry
[Vinuchain-Lists](https://github.com/VinuChain/Vinuchain-Lists) at
`contracts/vinuchain/QuotaContractV2_abi.json`. The Solidity source lives in
the same directory (`QuotaContractV2.sol`). For this guide you only need the
four staking functions and the read-only views, so the inline minimal ABI in
the example below is enough to get started.

### Staking interface

The QuotaContract V2 exposes the following developer-facing functions
(selectors `stake()`, `stakeFor(address)`, `unstake(uint256)`, and
`unstakeFor(address,uint256)` are the ones the node recognizes as
Payback-staking transactions):

| Function | Signature | Notes |
|---|---|---|
| Stake for yourself | `stake() payable` | Credits `msg.sender`; `msg.value` is the staked VC. |
| Stake for another wallet | `stakeFor(address delegator) payable` | `msg.sender` funds and **keeps withdrawal ownership**; `delegator` receives the Payback quota credit. |
| Unstake your own stake | `unstake(uint256 amount) → uint256 wrID` | Opens a withdrawal request; funds unlock after `holdTime()`. |
| Unstake third-party-funded stake | `unstakeFor(address delegator, uint256 amount) → uint256 wrID` | Only the funding wallet (the original `stakeFor` caller) may call this for that `delegator`. |
| Complete a withdrawal | `withdrawStake(uint256 wrID)` | Callable once `block.timestamp ≥ unlockTime`. |

Read-only views used by the node and useful to dapps: `minStake()`,
`getStake(address)`, `totalStake()`, `quotaFactor()`, `feeRefundBlockCount()`,
`holdTime()`.

> **`stakeFor` ownership.** With `stakeFor(receiver)`, the *funding* wallet
> supplies the VC and is the only party that can withdraw it (via
> `unstakeFor(receiver, amount)`). The *receiver* gets the Payback quota for
> transactions it signs but has **no claim** on the staked principal. This lets
> a sponsor underwrite a user's gas without handing over funds.

## The `feeRefund` receipt field

When a transaction receives a Payback refund, the node adds a `feeRefund`
field (a hex-encoded wei amount) to the transaction receipt. Read it with the
standard `eth_getTransactionReceipt`:

```bash
curl -s -X POST https://vinufoundation-rpc.com \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0xYOUR_TX_HASH"],"id":1}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('feeRefund'))"
```

* A non-zero `feeRefund` (e.g. `0x...`) is the wei amount that was credited
  back to the sender.
* `feeRefund` is **absent or `0x0`** when no refund was granted (wallet not
  eligible, quota exhausted, or refunds suppressed under congestion).

The field is also surfaced on `eth_getTransactionByHash` for the same
transaction.

## The `vc_` RPC namespace

VinuChain mirrors the standard `eth_` JSON-RPC namespace under a branded `vc_`
namespace and adds Payback-specific methods. The methods relevant to feeless
integration:

| Method | Purpose |
|---|---|
| `vc_getRules(blockTag)` | Returns the active network rules for the epoch. `result.Economy.QuotaCacheAddress` is the Payback contract the node is currently enforcing; `result.NetworkID` is the chain ID. |
| `vc_getPaybackBalance(address, blockTag)` | Returns the wallet's currently available Payback quota in wei (the refund cap for its next transaction). `0x0` for ineligible wallets. Rate-limited per node. |

The `vc` namespace mirrors the core Ethereum RPC services for branding, so the
common read/transaction methods are available under `vc_` as well (e.g.
`vc_chainId`, `vc_getBalance`, `vc_getTransactionReceipt`, `vc_sendRawTransaction`).
It is **not** a complete alias of every `eth_` method — namespaced extras such as
the filter/subscription methods (`eth_newFilter`, `eth_getLogs`,
`eth_subscribe`) are only registered under `eth`, so their `vc_` forms return
method-not-found. For normal tooling just use the standard `eth_` methods; reach
for `vc_` specifically for `vc_getRules` and `vc_getPaybackBalance`.

Verify the active contract and chain ID live:

```bash
# Active Quota contract address the node is enforcing
curl -s -X POST https://vinufoundation-rpc.com \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getRules","params":["latest"],"id":1}' \
  | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print('chainId', r['NetworkID']); print('quota', r['Economy']['QuotaCacheAddress'])"

# Available Payback quota (wei) for a wallet
curl -s -X POST https://vinufoundation-rpc.com \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getPaybackBalance","params":["0xYOUR_ADDRESS","latest"],"id":1}'
```

## End-to-end example (ethers.js, testnet)

This script stakes the minimum for Payback, waits for the quota to accrue,
sends an ordinary transaction, and reads the `feeRefund` from its receipt — all
against the live testnet at `https://vinufoundation-rpc.com` (chain `206`).

> **Prerequisites**
> * Node 18+ and `ethers` v6: `npm i ethers@6`
> * A funded testnet key with **more than `minStake()` VC plus gas headroom**
>   (≥ ~1001 VC). Get testnet VC from the
>   [faucet](https://faucet.vinuscan.com).
> * Run with `PRIVATE_KEY=0x... node feeless.mjs` — never hard-code keys.

```javascript
// feeless.mjs — stake -> send tx -> observe the Payback refund (testnet)
import { ethers } from "ethers";

const RPC = "https://vinufoundation-rpc.com";          // VinuChain testnet
const QUOTA = "0x89D1cBD9DEAaB4dFf6f800a336FBDd9A5c6829e4"; // QuotaContract V2

// Minimal ABI: the staking writes + the views we read.
const QUOTA_ABI = [
  "function stake() payable",
  "function stakeFor(address delegator) payable",
  "function unstake(uint256 amount) returns (uint256 wrID)",
  "function minStake() view returns (uint256)",
  "function getStake(address) view returns (uint256)",
];

const pk = process.env.PRIVATE_KEY;
if (!pk) throw new Error("set PRIVATE_KEY=0x... in your environment");

const provider = new ethers.JsonRpcProvider(RPC);
const wallet = new ethers.Wallet(pk, provider);
const quota = new ethers.Contract(QUOTA, QUOTA_ABI, wallet);

const send = (method, params = []) =>
  provider.send(method, params); // works for eth_* and vc_* alike

async function main() {
  const me = await wallet.getAddress();
  console.log("network:", (await provider.getNetwork()).chainId); // 206n
  console.log("wallet :", me);

  // 1) Ensure the wallet meets minStake() for Payback.
  const minStake = await quota.minStake();
  const staked = await quota.getStake(me);
  console.log("minStake:", ethers.formatEther(minStake), "VC");
  console.log("staked  :", ethers.formatEther(staked), "VC");

  if (staked < minStake) {
    const top = minStake - staked;
    console.log("staking", ethers.formatEther(top), "VC for Payback...");
    const tx = await quota.stake({ value: top });
    await tx.wait();
    console.log("staked in tx", tx.hash);
  }

  // 2) Let quota accrue. Quota grows with elapsed time since staking, so a
  //    freshly-staked wallet may show 0 for a short while. Poll vc_.
  let available = 0n;
  for (let i = 0; i < 12; i++) {
    const hex = await send("vc_getPaybackBalance", [me, "latest"]);
    available = BigInt(hex);
    console.log(`available payback quota: ${available} wei`);
    if (available > 0n) break;
    await new Promise((r) => setTimeout(r, 5000));
  }
  if (available === 0n) {
    console.log("quota still 0 — accrues with time; re-run later to see a refund");
  }

  // 3) Send an ordinary self-transfer. Pay gas normally; the refund comes back.
  const balBefore = await provider.getBalance(me);
  const tx = await wallet.sendTransaction({ to: me, value: 1n });
  console.log("sent tx", tx.hash);
  const receipt = await tx.wait();

  // 4) Read the Payback refund off the receipt (raw RPC keeps the custom field).
  const raw = await send("eth_getTransactionReceipt", [tx.hash]);
  const feeRefund = raw.feeRefund ? BigInt(raw.feeRefund) : 0n;
  const gasCost = receipt.gasUsed * receipt.gasPrice;

  console.log("gas paid   :", ethers.formatEther(gasCost), "VC");
  console.log("feeRefund  :", ethers.formatEther(feeRefund), "VC");
  console.log("net cost   :", ethers.formatEther(gasCost - feeRefund), "VC");
  console.log(
    feeRefund >= gasCost
      ? "fully feeless: the whole fee was refunded"
      : feeRefund > 0n
      ? "partially refunded (quota smaller than the fee, or congestion)"
      : "no refund this time (quota 0, below minStake, or congestion)"
  );

  // 5) (Optional) Begin unstaking. Funds unlock after the contract holdTime.
  // const u = await quota.unstake(minStake); await u.wait();
  // console.log("unstake requested:", u.hash);
}

main().catch((e) => { console.error(e); process.exit(1); });
```

Expected first-run output (abridged) once quota has accrued:

```
network: 206n
minStake: 1000.0 VC
staking 1000.0 VC for Payback...
available payback quota: ... wei
sent tx 0x...
gas paid   : 0.0000... VC
feeRefund  : 0.0000... VC
net cost   : 0.0 VC
fully feeless: the whole fee was refunded
```

## FAQ

**Why was my refund only partial?**
The refund is capped at the wallet's available quota: `min(fee, quota)`. If the
quota is smaller than `gasUsed × gasPrice`, you get a partial refund. Quota also
shrinks as total network-wide Payback stake grows.

**I staked but `feeRefund` is `0x0` — why?**
Most commonly: (1) your stake hasn't reached `minStake()`; (2) quota hasn't
accrued yet (it grows with elapsed time since your stake — poll
`vc_getPaybackBalance`); (3) you've already consumed your quota; or (4) the
network is congested and refunds are suppressed.

**Who owns funds staked with `stakeFor`?**
The funding wallet (the `stakeFor` caller) keeps ownership and is the only
party that can withdraw, via `unstakeFor(receiver, amount)`. The receiver only
gets the Payback quota for transactions it signs.

**Can I send a transaction with `gasPrice: 0`?**
No. Payback is a refund, not a fee waiver — the wallet must pay gas up front and
is reimbursed afterward. Send a normal transaction and read the refund from the
receipt.

## See also

* [Staking → Overview](../staking/overview.md) — the staking model and quota
  semantics in user terms.
* [Network Details](../network-details.md) — canonical chain IDs, RPCs, and the
  active Quota contract address.
* [Whitepaper → Quota System](../../whitepaper/whitepaper/quota-system.md) — the
  theory and original quota formulas, with an implementation note mapping them
  to the shipped Payback model.
