---
description: VinuExplorer GraphQL
---

# GraphQL

## **What is GraphQL**

GraphQL is an open-source data query and manipulation language for APIs, and a runtime for fulfilling queries with existing data. It provides an efficient, powerful and flexible approach to developing web APIs. It allows clients to define the structure of the data required, and exactly the same structure of the data is returned from the server, therefore preventing excessively large amounts of data from being returned.

Key concepts of the GraphQL query language are:

* Hierarchical
* Strongly typed
* Client-specified queries

Advantages of GraphQL:

* Declarative integration on client (what data/operations do I need)
* A standard way to expose data and operations
* Support for real-time data (with subscriptions)

## **Query types**

There are three main query types in GraphQL schema:

1\) **Query:** fetch data

```
query {
  allPosts {
    description
    text
  }
}
```

2\) **Mutation:** change data.

```
   mutation {
     updatePost(id: 1, text: "text") {
       text
     }
   }
```

1. **Subscription:** subscribe to real-time data.

```
subscription {
  newPost(category: [1]) {
    description
    text
  }
}
```

## **Access GraphQL API**

To access Blockscout GraphQL interface you can use [GraphiQL](https://vinuexplorer.org/graphiql) - in-browser IDE for exploring GraphQL. It's built in to VinuExplorer.

From the `APIs` dropdown menu choose `GraphQL.`

<figure><img src="../../.gitbook/assets/image (3).png" alt=""><figcaption></figcaption></figure>

You can also use your favourite http client:

```
curl 'https://vinuexplorer.org/graphiql'
  -H 'Authorization: Bearer YOUR_AUTH_TOKEN'
  -d '{"query":"{transaction(hash:\"0x20f4e2074d120a5db1fc96a371a2eb4581ea71bc99e076376b8cc923abb71b3f\"){blockNumber toAddressHash fromAddressHash createdContractAddressHash value status nonce hash error gas gasPrice gasUsed cumulativeGasUsed id index input r s v}}"}'
```

## **Queries**

VinuExplorer's GraphQL API provides queries and a subscription. You can view them in the GraphQL interface in the `Docs` menu.&#x20;

Example Queries:

| Query                                           | Description                 | Example                                                                                                                                  |
| ----------------------------------------------- | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| address(hash: AddressHash!): Address            | Gets an address by hash     | {address(hash: "0xFC00FACE00000000000000000000000000000000") {hash, contractCode} }                                                      |
| addresses (hashes: \[AddressHash!]): \[Address] | Gets addresses by hashes    | {addresses(hashes: \["0xFC00FACE00000000000000000000000000000000", "0xb2fbf7291b0500896ed7557a0c6bef74c514fa15"]) {hash, contractCode} } |
| block(number: Int!): Block                      | Gets a block by number      | {block(number: 1) {parentHash, size, nonce\}}                                                                                            |
| transaction (hash: FullHash!): Transaction      | Gets a transaction by hash. | {transaction(hash: "0x20f4e2074d120a5db1fc96a371a2eb4581ea71bc99e076376b8cc923abb71b3f") {input, gasUsed\}}                              |

```
{
  address(hash: "0x...") {
    transactions(first:5) {
      edges {
        node {
          blockNumber
          createdContractAddressHash
          fromAddressHash
          gas
          hash
        }
      }
    }
  }
}
```

Note that transactions can accept the following arguments:

* first
* after
* before

[_VinuExplorer_](https://vinuexplorer.org) _is a port of_ [_Blockscout_](https://docs.blockscout.com/)_._
