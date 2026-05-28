# Account Abstraction (ERC-4337)

VinuChain supports [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) account
abstraction, letting users transact through smart-contract accounts (paying gas
via paymasters, batching calls, using custom signature schemes) without any
change to the underlying protocol. The standard ERC-4337 stack is deployed at
its canonical, cross-chain addresses, so existing tooling (account SDKs,
bundler clients, paymaster services) works against VinuChain unmodified.

## Availability

| Network | Chain ID | ERC-4337 |
| --------- | ---------- | ---------- |
| Testnet | 206 | **Live** |
| Mainnet | 207 | Not yet deployed |

The stack is currently available on **testnet**. Mainnet deployment will follow
once the testnet rollout has been validated.

## Deployed contracts (testnet)

| Contract | Address |
| ---------- | --------- |
| EntryPoint v0.7 | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| SimpleAccountFactory | `0x27e13cC69A1d0cb6205153f89Be711B1872CfFd6` |

The EntryPoint lives at the same canonical address used on Ethereum and other
EVM chains. It is deployed deterministically through the
[Arachnid deterministic-deployment proxy](https://github.com/Arachnid/deterministic-deployment-proxy)
at `0x4e59b44847b379578588920cA78FbF26c0B4956C`, so the address is identical
everywhere the proxy exists.

## Bundler endpoint

A public ERC-4337 bundler (Skandha) is available on testnet:

```
https://bundler-testnet.vinuexplorer.org/rpc
```

It exposes the standard `eth_*` bundler RPC methods. Confirm the supported
EntryPoint before submitting:

```bash
curl -s -X POST https://bundler-testnet.vinuexplorer.org/rpc \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_supportedEntryPoints","params":[]}'
# -> ["0x0000000071727De22E5E9d8BAf0edAc6f37da032"]
```

## Submitting a UserOperation

The flow is the standard ERC-4337 flow — nothing VinuChain-specific:

1. Compute your smart-account address from the `SimpleAccountFactory` (or your
   chosen factory) and fund it, or attach a paymaster.
2. Build and sign a `UserOperation` for EntryPoint v0.7.
3. Send it to the bundler with `eth_sendUserOperation`, passing the EntryPoint
   address as the second parameter.
4. Poll `eth_getUserOperationReceipt` for inclusion.

```bash
curl -s -X POST https://bundler-testnet.vinuexplorer.org/rpc \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_sendUserOperation",
       "params":[<userOp>, "0x0000000071727De22E5E9d8BAf0edAc6f37da032"]}'
```

SDKs such as [permissionless.js](https://docs.pimlico.io/permissionless),
[userop.js](https://github.com/stackup-wallet/userop.js), and the
[aa-sdk](https://accountkit.alchemy.com/) can be pointed at the testnet RPC
(`https://vinufoundation-rpc.com`) and the bundler endpoint above.

## Exploring UserOperations

Indexed UserOperations are available through the VinuExplorer account-abstraction
API, for example:

```
https://testnet.vinuexplorer.org/api/v2/proxy/account-abstraction/operations
```

## Node operators

Submitting the deployment and bundler transactions requires admitting
pre-EIP-155 (chain-id-less) transactions over RPC, which a node enables with the
`--rpc.allow-unprotected-txs` flag. This flag is intended for non-mainnet
networks; it is refused on mainnet (NetworkID 207) by a node-level guard. On
mainnet, only the single canonical Arachnid deployer transaction is admitted
(pinned by exact transaction hash) so the EntryPoint can be placed at its
canonical address without otherwise relaxing replay protection.
