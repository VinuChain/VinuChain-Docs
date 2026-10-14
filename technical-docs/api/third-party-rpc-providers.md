---
description: Managed RPC and node infrastructure providers that support VinuChain
---

# Third-Party RPC Providers

The [public endpoints](public-api-endpoints.md) at `rpc.vinuchain.org` are free
and need no sign-up. For production workloads you may want a managed provider
instead. Providers typically offer dedicated rate limits, usage dashboards and
an SLA.

{% hint style="info" %}
Third-party providers are run independently of VinuChain. Their pricing,
limits, uptime and data handling are set by each provider, so review their
terms before you depend on them. A listing here is not an endorsement. Every
provider must serve the same chain: confirm `eth_chainId` returns `0xcf`
(`207`) for mainnet.
{% endhint %}

## Providers

### NOWNodes

<figure><img src="../../.gitbook/assets/nownodes-logo.svg" alt="NOWNodes logo" width="180"><figcaption></figcaption></figure>

NOWNodes is a blockchain infrastructure provider that offers RPC, WSS and API
access to more than 120 networks, VinuChain among them. Developers can build
and scale applications without running their own nodes.

| | |
| --- | --- |
| **Network** | Mainnet (chain ID `207`) |
| **RPC endpoint** | `https://vinu.nownodes.io/` |
| **Authentication** | API key, sent in the `api-key` HTTP header |
| **VinuChain docs** | [docs.nownodes.io/vinu](https://docs.nownodes.io/vinu/) |
| **Website** | [nownodes.io](https://nownodes.io/) |

Requests without a key are rejected with `Missing API_key`. Get a key from a
NOWNodes account, then call the endpoint:

```bash
curl -s -X POST https://vinu.nownodes.io/ \
  -H 'Content-Type: application/json' \
  -H 'api-key: YOUR_API_KEY' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

## Listing a provider

If you run public VinuChain RPC infrastructure and want to be listed here, open
a pull request against the
[VinuChain docs repository](https://github.com/VinuChain/VinuChain-Docs) that
adds a section to this page. Include the provider name, a short description,
the supported networks, the endpoint URLs, the authentication method and a link
to your VinuChain-specific documentation.
