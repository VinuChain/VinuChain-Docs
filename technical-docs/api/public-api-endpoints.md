---
description: Public Nodes / Public API Endpoints
---

# Public API Endpoints

### Mainnet

#### RPC

```
https://rpc.vinuchain.org
ChainID: 207
Symbol: VC
Explorer: https://vinuexplorer.org
```

#### WS

```
wss://rpc.vinuchain.org
```



### Testnet

#### RPC

```
https://vinufoundation-rpc.com
ChainID: 206
Symbol: VC
Explorer: https://testnet.vinuexplorer.org
```

#### WS

```
wss://vinufoundation-rpc.com:4100
```

---

### ELEMONT RPC Surface

Testnet exposes the complete ELEMONT RPC surface. Mainnet exposes the existing
core subset and gains the remaining methods when its node is upgraded to the
ELEMONT binary.

#### `vc_*` namespace

The `vc_*` namespace mirrors the standard `eth_*` namespace and accepts the
same arguments and returns the same types. Examples:

| Method | Description |
|---|---|
| `vc_blockNumber` | Returns the current block number. |
| `vc_call` | Executes a call without creating a transaction. |
| `vc_getRules` | Returns the active consensus rules for the current epoch, including the staged fork flags and quota contract address. |

Most common read/transaction `eth_*` methods have a `vc_*` equivalent (e.g.
`vc_chainId`, `vc_getBalance`, `vc_getTransactionReceipt`,
`vc_sendRawTransaction`). The mirror is **not** complete: filter and
subscription methods (`eth_getLogs`, `eth_newFilter`, `eth_subscribe`) are
registered only under `eth_*`, so their `vc_*` forms return
method-not-found (`-32601`). Use the standard `eth_*` methods for normal
tooling; reach for `vc_*` specifically for `vc_getRules` and
`vc_getPaybackBalance`.

{% hint style="warning" %}
**Status checked 25 August 2026:** availability still differed by network.
`vc_getRules` worked on both, but `vc_getPaybackBalance` and `eth_config` /
`vc_config` were **testnet-only pending the mainnet ELEMONT upgrade on
2026-08-29**. On `https://rpc.vinuchain.org` they returned `-32601` (method not
found), because mainnet still ran the pre-ELEMONT binary.

Check before depending on one:

```bash
curl -s -X POST https://rpc.vinuchain.org -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"rpc_modules","params":[],"id":1}'
```

See the [Mainnet Upgrade Guide](../vinuchain-mainnet/chain-upgrade-guide.md).
{% endhint %}

#### `vc_getPaybackBalance`

```
vc_getPaybackBalance(address, blockNrOrHash) → quantity
```

Returns the accrued fee-refund (payback) balance for `address` at the given
block. This call is rate-limited by the node; if the request queue is
exhausted the node returns JSON-RPC error **-32005**.

#### `eth_config` / `vc_config`

```
eth_config() → ForkConfig
vc_config() → ForkConfig
```

Returns an object describing the current, next, and last applied fork
configuration. Each fork entry includes `activationBlock`, `chainId`,
`forkId`, and `precompiles`.

For the full ELEMONT RPC reference and operator upgrade guide, see
[VinuChain ELEMONT Upgrade](../vinuchain-mainnet/elemont-upgrade.md).
