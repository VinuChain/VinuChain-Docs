<!-- markdownlint-disable MD013 -->

# VinuChain ELEMONT Upgrade

ELEMONT is VinuChain mainnet's move to the V2 staking contract, modern EVM
rules, and PaybackV2. It is scheduled to begin on **29 August 2026 at 10:00
UTC** on mainnet chain ID `207`.

## What you need to do

Use this page to identify your action and the observable state that completes
it.

| You are a | Required action | Finished when |
| --- | --- | --- |
| Mainnet node operator | Native systemd/script node: follow the [Mainnet Upgrade Guide](chain-upgrade-guide.md). Container node: require a coordinator-approved deployment-specific runbook and use the same checkpoints. | Your node runs `v2.0.49-elemont`, all five seals are active, and its block hash matches mainnet at the same height. |
| Payback fee-refund staker | [Withdraw from the old Quota contract and stake on V2](#if-you-stake-in-the-payback-fee-refund-contract). | The old withdrawal is complete and `getStake(yourAddress)` on V2 shows the intended amount. |
| Validator delegator | No mandatory migration. Consider claiming accumulated rewards before the upgrade. | Your balance and delegation remain visible. If you choose to claim, repeat until the pending amount reaches zero. |
| dApp, bridge, exchange, indexer, or bot operator | Test the [breaking changes](#dapp-and-infrastructure-checks) against testnet and gate features by active rules. | Your integration works with the new SFC/Quota addresses and the EVM rules it uses have sealed. |
| Wallet holder | No action. | Your address, VC balance, and chain ID remain unchanged. |

{% hint style="warning" %}
**Status checked 25 August 2026:** mainnet had not activated ELEMONT and still
used the V1 SFC and V1 Payback/Quota proxy. Trust the live rule probe below over
this dated observation or a calendar estimate.
{% endhint %}

## Upgrade status

| Item | Value |
| --- | --- |
| Network | VinuChain Mainnet |
| Chain ID | `207` (`0xcf`) |
| Window opens | 29 August 2026, 10:00 UTC |
| Node release | [`v2.0.49-elemont`](https://github.com/VinuChain/VinuChain/releases/tag/v2.0.49-elemont) |
| Release commit | `8b88cc49d11e56635385413fe8f9eaec1969c1ac` |
| Pre-upgrade mainnet client | `v2.0.0-rc.1` |
| Mainnet RPC | `https://rpc.vinuchain.org` |
| Testnet RPC | `https://vinufoundation-rpc.com` |

Ask mainnet what is active now:

```bash
curl --fail --max-time 15 -sS -X POST https://rpc.vinuchain.org \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getRules","params":["latest"],"id":1}' \
  | python3 -m json.tool
```

Before activation, `Upgrades` contains `Berlin`, `London`, `Llr`, and
`Podgorica`, and `Economy.QuotaCacheAddress` is:

```text
0x1c4269fbbd4a8254f69383eef6af720bcd0acda6
```

The SFC version is another direct signal:

```bash
curl --fail --max-time 15 -sS -X POST https://rpc.vinuchain.org \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"0xFC00FACE00000000000000000000000000000000","data":"0x54fd4d50"},"latest"],"id":1}'
```

- `0x333034...` is `"304"`, the current V1 SFC.
- `0x333035...` is `"305"`, the ELEMONT V2 SFC after seal 1.

## Activation sequence

Restarting on the new binary stages the upgrade. Consensus rules change only
when an epoch seals. The EVM stages are ordered, so completion takes five
consecutive seals and can take up to roughly 20 hours after the 10:00 UTC swap.

| Seal | Newly active capabilities |
| --- | --- |
| 1 | `SfcV2`, `Elemont`, `ElemontPubkeyValidation`, `Shanghai`, `PaybackV2` |
| 2 | `Cancun` |
| 3 | `Prague` |
| 4 | `VinuBLS12381` |
| 5 | `VinuLatestEVM` |

Do not use projected clock times as activation proof. Query `vc_getRules` and
wait for the flag required by your application.

## What ELEMONT changes

| Feature | Mainnet effect |
| --- | --- |
| `SfcV2` | Replaces the SFC runtime at `0xFC00FACE00000000000000000000000000000000` with Cycle-165 V2, including corrected reward cursors, self-service validator reactivation, and a 30% burn of the validator base-fee share. `version()` becomes `"305"`. |
| `Shanghai` | Adds `PUSH0`, warm coinbase, Shanghai transaction rules, and the EIP-3860 initcode limit. |
| `Cancun` | Adds selected non-blob Cancun behavior: transient storage, `MCOPY`, and EIP-6780 `SELFDESTRUCT`. Blob transactions and `BLOBBASEFEE` remain disabled. |
| `Prague` | Adds EIP-7702 set-code transactions, type `0x04`. |
| `Elemont` | Activates consensus correctness fixes for epoch processing, cheater accounting, vector clocks, time ordering, and malformed validator records. |
| `ElemontPubkeyValidation` | Requires canonical 66-byte `0xc0`-prefixed Secp256k1 validator public keys at every on-chain validator ingress. |
| `VinuBLS12381` | Adds the EIP-2537 BLS12-381 precompiles at `0x0b` through `0x11`. |
| `VinuLatestEVM` | Adds `P256VERIFY` at `0x0100`, `CLZ`, MODEXP changes, and the EIP-7825 per-transaction gas cap. |
| `PaybackV2` | Changes `Economy.QuotaCacheAddress` from the V1 proxy to `QuotaContractV2` at `0x5D989A2d65d049e2198D91d8ddc31C918f2544AB`. Stake left on V1 remains withdrawable but stops earning fee refunds. |

Berlin, London, Llr, and Podgorica are already active and remain active.

## RPC changes

The core branded RPC namespace and `vc_getRules` are already live on mainnet.
The ELEMONT binary adds the methods marked below. Method availability does not
prove that its corresponding consensus flag has sealed; use `vc_getRules` for
that.

| Method | Status | Purpose |
| --- | --- | --- |
| Core `vc_*` methods, including `vc_blockNumber` and `vc_getTransactionByHash` | Already live | Provide VinuChain-branded aliases for core Ethereum-compatible queries. Filters and subscriptions stay under `eth_*`. |
| `vc_getRules(blockTag)` | Already live | Returns the active rule set and `Economy.QuotaCacheAddress`. |
| `vc_getPaybackBalance(address, blockTag)` | Added by `v2.0.49-elemont` | Returns the address's available fee-refund quota in wei. Overload is returned as JSON-RPC error `-32005`. |
| `eth_config` / `vc_config` | Added by `v2.0.49-elemont` | Returns chain/fork configuration, activation blocks, and the active precompile map. |

See [Public API Endpoints](../api/public-api-endpoints.md) for the endpoint
inventory.

## dApp and infrastructure checks

Test on VinuChain testnet, chain ID `206`, before 29 August. Testnet already
exposes the target capabilities at `https://vinufoundation-rpc.com`.

| Change | Active from | Required check |
| --- | --- | --- |
| EIP-3860 initcode limit of 49,152 bytes | Seal 1 | Ensure planned contract deployment initcode is within the limit. |
| SFC ABI V1 to V2 | Seal 1 | Regenerate or verify direct SFC bindings and test reward/validator calls against V2. |
| Payback contract replacement | Seal 1 | Stop hard-coding the V1 proxy as active; read `Economy.QuotaCacheAddress` or use the V2 address after the flag seals. |
| Canonical validator public keys | Seal 1 | Supply a 66-byte `0xc0`-prefixed key to validator create/update calls. |
| Cancun opcodes | Seal 2 | Do not deploy bytecode using transient storage or `MCOPY` before `Cancun` is true. |
| EIP-7702 transaction type `0x04` | Seal 3 | Gate set-code transactions until `Prague` is true. |
| BLS12-381 precompiles | Seal 4 | Gate calls until `VinuBLS12381` is true. |
| EIP-7825 transaction gas cap of 16,777,216 | Seal 5 | Keep every transaction gas limit at or below `2^24`; this is lower than mainnet's 20,500,000 block gas limit. |
| `P256VERIFY` and latest-EVM behavior | Seal 5 | Gate calls until `VinuLatestEVM` is true. |

Mainnet remains a London-era EVM until the relevant seals. Do not send
Shanghai-or-later bytecode or transaction types early.

## Staking and rewards

Existing validator delegations and balances do not migrate to a new address;
the SFC stays at `0xFC00FACE00000000000000000000000000000000` and its runtime changes in place.

V2 settles outstanding rewards in chunks of at most 100 epochs per transaction.
If a position is more than 100 epochs behind, the first `claimRewards`
transaction can pay only part of the displayed pending amount. Nothing is
lost: repeat the claim until the pending amount reaches zero.

To avoid multiple post-upgrade claim transactions, claim accumulated rewards
through the [VinuChain staking app](https://vinuchain.org/staking) before
seal 1. This is optional and does not change the total entitlement.

## If you stake in the Payback fee-refund contract <a href="#if-you-stake-in-the-payback-fee-refund-contract" id="if-you-stake-in-the-payback-fee-refund-contract"></a>

**Action required.** At seal 1, fee-refund accounting moves from the V1 Quota
proxy to V2. Your principal on V1 remains safe and withdrawable, but stake left
there no longer earns fee refunds after the switch.

| Contract | Address |
| --- | --- |
| V1 Quota proxy to exit | `0x1c4269fbbd4a8254f69383eef6af720bcd0acda6` |
| Mainnet `QuotaContractV2` to enter | `0x5D989A2d65d049e2198D91d8ddc31C918f2544AB` |

Both contracts were verified on 25 August 2026 with a 10 VC minimum and a
one-day withdrawal hold. The protocol values the chain enforces are still
determined by the active address returned from `vc_getRules`.

### Migrate

Before signing any transaction, confirm the wallet is on VinuChain mainnet,
chain ID `207`, and compare the entire contract address with the table above.

1. Open the [V1 contract page](https://mainnet.vinuexplorer.org/address/0x1c4269fbbd4a8254f69383eef6af720bcd0acda6?tab=contract), connect the staking wallet, and call `unstake(uint256 amount)`. Enter the amount in wei (`1 VC = 10^18 wei`). Save the transaction hash and the returned withdrawal-request ID (`wrID`) from the `Undelegated` event.
2. Wait until the request's `unlockTime` has passed. The configured hold is one day. On the same V1 contract, call `withdrawStake(uint256 wrID)` with the saved ID. Verify the VC returns to the same wallet.
3. Wait until `vc_getRules` reports `PaybackV2: true` and `Economy.QuotaCacheAddress` equals `0x5D989A2d65d049e2198D91d8ddc31C918f2544AB`.
4. Open the [verified V2 contract page](https://mainnet.vinuexplorer.org/address/0x5D989A2d65d049e2198D91d8ddc31C918f2544AB?tab=contract), connect the same wallet, and call payable `stake()` with at least 10 VC as the transaction value.
5. Read `getStake(yourAddress)` on V2 and confirm it shows the intended amount. Then check the available quota:

```bash
curl --fail --max-time 15 -sS -X POST https://rpc.vinuchain.org \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"vc_getPaybackBalance","params":["0xYOUR_ADDRESS","latest"],"id":1}' \
  | python3 -m json.tool
```

Starting the V1 unstake about one hold period before seal 1 can shorten the
post-switch gap, but the unstaked amount stops contributing as soon as you call
`unstake`. Do not stake on V2 until seal 1 is confirmed. If you lose the `wrID`,
read the wallet's active withdrawal requests from the V1 contract; do not
create another request to guess the ID.

## Testnet parity

After seal 5, mainnet and testnet expose the same user-facing protocol
capabilities. They do **not** have identical chain state, contract addresses,
or activation history.

Testnet's `SfcV2Patch`, `SfcV2Patch2` through `SfcV2Patch10`, and
`PaybackV2Patch` flags record repairs applied after earlier testnet activations.
Mainnet does not replay those flags: its first SFC V2 activation installs the
same final Cycle-165 runtime, and its first PaybackV2 activation uses the correct
mainnet V2 address.

## See also

- [Mainnet Upgrade Guide](chain-upgrade-guide.md) — the node-operator procedure
- [Feeless Transactions for Developers](../smart-contracts/feeless-transactions.md) — Payback integration
- [Staking Overview](../staking/overview.md) — validator delegation and Payback staking
- [Network Details](../network-details.md) — chain IDs, endpoints, and contract addresses
- [Account Abstraction](../smart-contracts/account-abstraction.md) — EIP-7702 and ERC-4337 context
