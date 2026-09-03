---
description: Validator calls reference
---

# Validator Calls

### Create validator

Create a new validator

Current minimum stake is `sfcc.minSelfStake()`

`pubkey` is a public key used to authenticate future validator's consensus messages. `pubkey` cannot be changed after the call.

#### Pubkey format

`pubkey` MUST be the canonical lachesis-base wire format: 66 bytes, beginning with the `0xc0` Secp256k1 type-byte followed by a 65-byte uncompressed secp256k1 public key (`0x04` marker + 32-byte X coordinate + 32-byte Y coordinate). As a hex string with the `0x` prefix that is 134 characters total: `0xc004` + 128 hex characters.

The canonical way to obtain a correctly-shaped pubkey is to run `./opera validator new` (see [Become a validator](become-a-validator.md#create-a-new-validator-key)). Copy the value labeled `Public key:` byte-for-byte — opera always emits the canonical format.

**Do not** construct the pubkey by other means. Submitting a 65-byte payload that begins with `0x04` (the bare uncompressed key without the `0xc0` type-byte) is the most common failure mode — it superficially looks like an ECDSA pubkey but is not the format lachesis-base verifies signatures against. A validator admitted with that shape produces no verifiable consensus events, earns zero uptime, and any stake delegated to it earns zero rewards.

`createValidator` rejects `pubkey.length != 66` with `"invalid pubkey length"` and `pubkey[0] != 0xc0` with `"invalid pubkey type"`.

The call creates a self-delegation with the specified amount. Validator uses the same calls as other delegators. Visit [delegation calls](./delegation-calls.md), [reward calls](./reward-calls.md), [stake lockup calls](./lockup-calls.md) for additional details.

```
sfcc.createValidator("0xc004...", {from:"0xAddress", value: web3.toWei("amount", "vc")})
```

#### **Checks**

* Self-stake amount is greater or equal to `sfcc.minSelfStake()`
* This address wasn't used for other validator
* `pubkey.length == 66` (rejects payloads of any other length)
* `pubkey[0] == 0xc0` (rejects payloads with any other type-byte, including the 65-byte `0x04`-prefixed bare uncompressed-secp256k1 shape)

### Reactivate validator (mainnet and testnet, self-service)

`reactivateValidator(uint256)` is available on **both** mainnet (chain 207) and testnet (chain 206) — the deployed SFC bytecode is identical on both chains and `version()` reports `"305"` on both. It is a validator **self-service** call: the validator's own immutable `auth` address can call it, and the SFC owner can also call it as a lost-key fallback.

```
sfcc.reactivateValidator(<VID>, { from: "<YOUR_VALIDATOR_AUTH_ADDRESS>" })
```

#### **Checks**

* Available on both mainnet (chain 207) and testnet (chain 206) — the deployed SFC bytecode is identical on both chains.
* The transaction sender must be the validator's own `auth` address (self-service), or `sfcc.owner()` as a lost-key fallback. Any other sender reverts with `"not authorized to reactivate"`.
* The validator must already exist and be deactivated. On the self-service (`auth` key) path the status must be offline-only (`status == 8`); any other status reverts with `"self-reactivation allowed only from offline status"`.
* The validator must not be slashed / double-sign marked — `"cheaters cannot be reactivated"`.
* Self-stake must still be greater than or equal to `sfcc.minSelfStake()`.
* On the self-service (`auth` key) path only, the anti-flap cooldown after `deactivatedTime` must have elapsed — otherwise `"reactivation cooldown not elapsed"`. The SFC owner is not subject to this cooldown.

If an external validator operator needs reactivation, they should first bring the node back online in synced validator mode, then call `reactivateValidator(<VID>)` themselves from the validator's `auth` address. Only contact official VinuChain channels if the `auth` key is lost (the SFC owner can call it as a fallback). See [Troubleshooting -> Reviving a dead or long-offline validator](troubleshooting.md#id-8.-reviving-a-dead-or-long-offline-validator-testnet).
