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

The canonical way to obtain a correctly-shaped pubkey is to run `./opera validator new` (see [Become a validator](become-a-validator.md#create-the-validator-wallet)). Copy the value labeled `Public key:` byte-for-byte — opera always emits the canonical format.

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
