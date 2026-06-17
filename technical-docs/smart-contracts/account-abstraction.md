# Account Abstraction (ERC-4337)

VinuChain supports [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) account
abstraction, letting users transact through smart-contract accounts (paying gas
via paymasters, batching calls, using custom signature schemes) without any
change to the underlying protocol. The standard ERC-4337 stack lives at its
canonical, cross-chain addresses, so existing tooling (account SDKs, bundler
clients, paymaster services) works against VinuChain unmodified.

The ELEMONT upgrade enables ERC-4337 on mainnet: Prague's **EIP-7702 set-code
transactions** are live, and the canonical
[Arachnid deterministic-deployment proxy](https://github.com/Arachnid/deterministic-deployment-proxy)
transaction is allowlisted so the EntryPoint can be placed at its canonical
address on mainnet (chain `207`).

## Availability

| Network | Chain ID | ERC-4337 |
| --------- | ---------- | ---------- |
| Mainnet | 207 | **Live** |
| Testnet | 206 | **Live** |

## Canonical contracts (both networks)

| Contract | Address |
| ---------- | --------- |
| EntryPoint v0.7 | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| SimpleAccountFactory | `0x27e13cC69A1d0cb6205153f89Be711B1872CfFd6` |

The EntryPoint lives at the same canonical address used on Ethereum and other EVM
chains. It is deployed deterministically through the Arachnid
deterministic-deployment proxy at
`0x4e59b44847b379578588920cA78FbF26c0B4956C`, so the address is identical
everywhere the proxy exists.

## Bundlers

A public ERC-4337 bundler (Skandha) is available on testnet:

```
https://bundler-testnet.vinuexplorer.org/rpc
```

It exposes the standard bundler RPC methods. Confirm the supported EntryPoint
before submitting:

```bash
curl -s -X POST https://bundler-testnet.vinuexplorer.org/rpc \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_supportedEntryPoints","params":[]}'
# -> ["0x0000000071727De22E5E9d8BAf0edAc6f37da032"]
```

A bundler is simply an ERC-4337-aware relayer pointed at a node's RPC. To submit
UserOperations on **mainnet**, run a bundler (e.g. Skandha) against the mainnet
RPC `https://vinuchain-rpc.com`, or use any hosted bundler that supports
VinuChain mainnet. The EntryPoint address and UserOperation flow are identical on
both networks.

## Submitting a UserOperation

The flow is the standard ERC-4337 flow — nothing VinuChain-specific:

1. Compute your smart-account address from the `SimpleAccountFactory` (or your
   chosen factory) and fund it, or attach a paymaster.
2. Build and sign a `UserOperation` for EntryPoint v0.7.
3. Send it to a bundler with `eth_sendUserOperation`, passing the EntryPoint
   address as the second parameter.
4. Poll `eth_getUserOperationReceipt` for inclusion.

```bash
curl -s -X POST <bundler-endpoint> \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_sendUserOperation",
       "params":[<userOp>, "0x0000000071727De22E5E9d8BAf0edAc6f37da032"]}'
```

SDKs such as [permissionless.js](https://docs.pimlico.io/permissionless),
[userop.js](https://github.com/stackup-wallet/userop.js), and the
[aa-sdk](https://accountkit.alchemy.com/) can be pointed at the VinuChain RPC
(`https://vinuchain-rpc.com` for mainnet, `https://vinufoundation-rpc.com` for
testnet) and a bundler endpoint.

## Exploring UserOperations

Indexed UserOperations are available through the VinuExplorer account-abstraction
API, for example (testnet):

```
https://testnet.vinuexplorer.org/api/v2/proxy/account-abstraction/operations
```

The mainnet explorer at [vinuexplorer.org](https://vinuexplorer.org) surfaces the
same account-abstraction views.

## How it works at the protocol level

ERC-4337 needs two things from the chain, both delivered by ELEMONT:

* **EIP-7702 set-code transactions** (Prague) let EOAs delegate to contract code.
* **Placing the EntryPoint at its canonical CREATE2 address.** The Arachnid
  deterministic-deployer transaction is pre-EIP-155 (chain-id-less). A node only
  admits such transactions over RPC when started with the
  `--rpc.allow-unprotected-txs` flag, which is **refused on mainnet (NetworkID
  207)** by a node-level guard. To still allow the canonical deployment, mainnet
  admits **only the single canonical Arachnid deployer transaction** (pinned by
  exact transaction hash) so the EntryPoint can be placed at its canonical
  address without otherwise relaxing replay protection.
