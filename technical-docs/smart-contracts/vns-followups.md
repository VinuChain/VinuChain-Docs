# VNS — Outstanding Follow-ups

Tracks deferred work items uncovered during the 2026-05-21 rentPrice
StaleAnswer incident response. Each item below has been scoped enough that
a future session or operator can pick it up without re-doing the
investigation.

## F1 — Frozen VinuSwap V3 pool TWAP (testnet)

### Symptom

`scripts/update-vns-oracle.js` resolved a **byte-identical** `poolUsd =
0.0003878450641267948` across at least six consecutive cron runs spanning
~24 hours (2026-05-20 → 2026-05-21). CoinGecko's reference price moved over
the same window from `$0.00040578` → `$0.00041382`, so the CoinGecko / pool
deviation expanded from `452 bps` (within the default 500 cap) to `648 bps`
(over the cap), gating the cron behind the deviation guard even when the
secret was eventually correct.

### Root cause

The V3 pool that backs the TWAP guard for VC/USDT on chain 207 has had no
swaps for an extended period. A TWAP window with no swaps returns the same
arithmetic-mean of older observations on every call, so the computed pool
price doesn't track real-world price movement. Testnet liquidity is too
thin to keep the TWAP refreshed via organic activity.

### Mitigation options (no decision yet)

* **Widen the deviation cap permanently.** A repo variable
  `VNS_ORACLE_MAX_DEVIATION_BPS` is already plumbed through. Setting it to
  `750`–`1000` keeps the cron alive but loosens the manipulation guard
  that the deviation check was meant to provide. Walking past `1000` bps
  (10 %) requires script-level review.
* **Rotate the pool used for the guard.** The script reads
  `~/vinuchain-lists/contracts/vns/deployment-testnet.json::oracleStack`.
  Pick a pool with higher activity (or with a wider TWAP window) and
  point the script at it.
* **Shorten the TWAP window.** `VNS_ORACLE_TWAP_WINDOW_SECONDS` defaults
  to `10 * 60 = 600 s`. A shorter window picks up new swaps faster, at
  the cost of being moveable by a single sandwiched swap.
* **Drop the pool guard on testnet.** Setting
  `VNS_ORACLE_REQUIRE_POOL_GUARD=0` (the `--require-pool-guard` flag) makes
  the cron tolerate a missing or stale pool quote. This trades the
  manipulation guard for cron survivability and is appropriate on testnet
  where real-money risk is zero, but not on mainnet.
* **Bootstrap a maker bot on the V3 pool.** Have a small process post a
  tiny WVC/USDT swap every ~5 minutes so the TWAP stays fresh. Adds an
  operational dependency but preserves the deviation guard.

### Recommendation

Short term, leave the repo variable at `VNS_ORACLE_MAX_DEVIATION_BPS=750`
(already set 2026-05-21). Long term, drop the pool guard on testnet
(`VNS_ORACLE_REQUIRE_POOL_GUARD=0` in the workflow env) and keep the
guard live on mainnet only. The deviation guard is a manipulation
protection that doesn't apply on testnet where there are no real funds
to defend.

---

## F2 — Split the deployer EOA into per-role keys

### Symptom

The EOA `0xf9c82B1117e8BeA97843042521B8FBC93044f347` is the single owner
of:

* `VinuUsdOracle`
* `ExponentialPremiumPriceOracle`
* `Root` (top-level namespace)
* The registrar / wrapper controller-set administrator
* `QuotaContractV2`
* The chain's `NodeDriverAuth` owner

Loss or compromise of this key compromises the entire VNS namespace
**plus** the VinuChain governance surface. The same risk shape played out
on the Quota V1 ProxyAdmin key `0x07b4ef…b9a5`, which is now unrecoverable
in-house.

### Acceptance criteria (when this gets scoped)

1. Three new EOAs:
   * **VNS root / governance** — controls `Root.lock(vinu)` and
     namespace administration.
   * **VNS controller administrator** — owns
     `ETHRegistrarController`, `Name Wrapper` controller-set,
     `ReverseRegistrar` controller-set.
   * **Oracle updater** — owns the two price oracles. Held by the
     scheduled GitHub Actions worker only; never used interactively.
2. `transferOwnership(...)` called on every administrator surface from
   the current `0xf9c82B…f347` EOA to the corresponding new EOA.
3. `~/vinuchain-lists/contracts/vns/deployment-testnet.json` updated with
   the new owner addresses.
4. `~/vinuchain-lists/.github/workflows/vns-oracle-update.yml` re-pointed
   at the new oracle-updater secret.
5. The VinuChain-Docs `Security status` and `Key management` sections
   updated.
6. Optionally, the controller-administrator role moved behind a
   multi-sig wallet with a time-locked rotation procedure.

### Dependencies

* New EOAs need to hold enough testnet VC for gas (cold-fund them from
  `0xf9c82B…f347`).
* Plan needs security review before execution.
* No on-chain change is contract-breaking — every owner setter is just
  `transferOwnership(newOwner)`.

---

## F3 — On-chain pause method on ETHRegistrarController

### Symptom

The `ETHRegistrarController` has no pause method. If a pricing-oracle
failure or other emergency calls for a hold on new registrations, the only
levers today are:

1. Flip `VNS_REGISTRATION_PAUSED = true` in the landing repo (only
   affects `vinuchain.org/vns`; wallets, SDKs, and the explorer can still
   register through their own UIs).
2. `transferOwnership(...)` the oracle to a `0xdead…` address (kills
   registrations everywhere, but also kills renewals — collateral
   damage).
3. Revoke the controller's role on the BaseRegistrar (kills new
   registrations everywhere, leaves renewals working through a separate
   path).

None of these are graceful. A native pause modifier on `commit`,
`register`, and `renew` would be the right primitive.

### Acceptance criteria

1. `paused()` view + `pause()` / `unpause()` owner-gated setters added to
   `ETHRegistrarController.sol`. Pattern matches OpenZeppelin
   `PausableUpgradeable`.
2. `commit`, `register`, `renew` revert with `Paused()` when paused.
3. Redeploy the controller (contract is non-upgradable; redeploy is the
   only option). Update controller-set on Base Registrar, Name Wrapper,
   Reverse Registrar, Default Reverse Registrar to the new address.
4. Revoke the old controller's role on those surfaces.
5. `deployment-testnet.json` updated with the new controller address.
6. `~/VinuChain-Landing/lib/vns/contracts.ts::VNS_REGISTRAR_CONTROLLER_ADDRESS`
   updated; `vnsRegistrarControllerAbi` augmented with the new error and
   functions; staleness banner extended to also check the on-chain pause
   bit so users see the right message.
7. Update the VinuExplorer BENS adapter to read the pause flag and
   surface it in the protocol manifest.

### Dependencies

* Existing controller `0x313b4C7CDe49a74983205c938f904b4a488bDb14` was
  redeployed on 2026-05-18 — redeploying again is an additive change with
  no migration cost, but every dependent client (wallet, SDK, explorer)
  needs the new address.
* Same redeploy procedure as the 2026-05-18 oracle-stack switch, recorded
  in `deployment-testnet.json::transactions`.

---

## F4 — CloudWatch alarm on consecutive cron failures (shipped 2026-05-21)

A failure-reporting step is now wired into `vns-oracle-update.yml`. On
each failed run it creates (or comments on the existing) GitHub issue
labelled `oracle-cron-failure` with a link to the failed run. The repo
admin receives a GitHub email notification for new issues, so three
consecutive failures show up as three comments on a single issue rather
than three new issues.

A future CloudWatch / SNS path matching the existing
`vinu-stats-lag-probe-*` Lambda pattern remains optional. It would
require:

1. A new IAM role with `cloudwatch:PutMetricData` scoped to namespace
   `VinuChain`.
2. A new Lambda (`vinu-vns-oracle-cron-probe`) that polls the GitHub
   Actions REST API every 30 min and publishes a `VnsOracleCronFailureStreak`
   metric.
3. A CloudWatch alarm gated at `>= 3` with `vinuchain-alerts` SNS as the
   action.

This is documented but not yet implemented because the GH-issue path
above gives equivalent visibility with zero AWS plumbing.

---

## F5 — Custom errors in canonical ABI (already in place)

`~/vinuchain-lists/contracts/vns/ETHRegistrarController_abi.json` already
carries every error from `ETHRegistrarController.sol` (CommitmentNotFound,
CommitmentTooNew, CommitmentTooOld, NameNotAvailable, DurationTooShort,
ResolverRequiredWhenDataSupplied, ResolverRequiredForReverseRecord,
UnexpiredCommitmentExists, InsufficientValue, MaxCommitmentAgeTooLow,
MaxCommitmentAgeTooHigh). `VinuUsdOracle_abi.json` carries all 11 errors
from that contract (StaleAnswer, AnswerOutOfBounds, AnswerChangeTooLarge,
InvalidAnswer/Bounds/MaxChangeBps/MaxAge, MaxChangeBpsAboveCeiling,
MaxAgeAboveCeiling, BoundsWidenedTooMuch, SourceTooLong).

Consumers that decode reverts in the rentPrice/register/renew path must
load **both** ABIs so they can decode revert selectors that originated in
either contract. The landing frontend's `vnsRegistrarControllerAbi`
(`~/VinuChain-Landing/lib/vns/contracts.ts`) demonstrates the merge.

---

## G010 — TypeScript 6.0.3 upgrade in `vinuexplorer-frontend` (verified working, needs clean checkout to land)

### Symptom

IDE shows `Option 'baseUrl' is deprecated and will stop functioning in
TypeScript 7.0. Specify compilerOption '"ignoreDeprecations": "6.0"' to
silence this error.` on `tsconfig.json:17`. The installed TypeScript
dependency is `5.9.2`, which only accepts `"ignoreDeprecations": "5.0"`,
so the silencing setting must lag the editor's bundled TypeScript by one
major version. Upgrading the dev dependency to `^6.0.3` (TS 6 is GA as
of 2026-04) lets the silencing setting and the deprecation suggestion
agree.

### Verified-working procedure

These exact steps were dry-run end-to-end against the current
`vinuexplorer-frontend` working tree and `tsc --noEmit` returned exit 0
with zero errors. Land them from a clean checkout because the procedure
must update `yarn.lock`; the integrity-checked nature of `yarn add`
makes it brittle when run after npm has touched node_modules in the
same tree (see "Why not landed in 2026-05-21 session" below).

```bash
# 1. From a clean repo checkout with no uncommitted node_modules state:
cd ~/vinuexplorer-frontend
git checkout main && git pull
rm -rf node_modules
yarn install --frozen-lockfile

# 2. Bump the dev dependency. This updates package.json AND yarn.lock.
yarn add --dev typescript@^6.0.3

# 3. Flip the silencing setting in tsconfig.json from "5.0" to "6.0":
#       "ignoreDeprecations": "6.0",

# 4. TS 6+ raises TS2882 on side-effect imports of style files unless
#    the module is declared ambient. Append this block to decs.d.ts:
#
#       declare module '*.css';
#       declare module '*.scss';
#       declare module '*.sass';

# 5. Re-run the typecheck. Expect zero errors.
yarn lint:tsc

# 6. Commit and push.
git add tsconfig.json decs.d.ts package.json yarn.lock
git commit -m 'chore(ts): upgrade typescript to 6.0.3, silence baseUrl deprecation'
git push origin main
```

### Acceptance pins

* `yarn lint:tsc` exit 0 with zero `TS2882` or `TS5103` errors.
* Editor warning on `tsconfig.json::baseUrl` is gone.
* No production runtime change — TS 6 emits the same JS for the Pages
  Router + Chakra + wagmi stack the explorer uses. The only behavioural
  change is type-check strictness.

### Why this didn't land in the 2026-05-21 session

The first attempt installed `typescript@^6.0.3` via `npm install
--legacy-peer-deps` to work around peer-dep conflicts that yarn would
resolve cleanly. That npm install rewrote ~9000 lines of `yarn.lock`
(rewriting `resolved` URLs from `registry.yarnpkg.com` to
`registry.npmjs.org` and dropping the transitive
`@adraffy/ens-normalize@1.10.0` entry that yarn keeps). Reverting
`yarn.lock` and running `yarn add` afterwards then hit an integrity
mismatch on `cross-spawn@7.0.6` because remnants of npm-style
node_modules persisted. The procedure above starts from a clean
`rm -rf node_modules` + `yarn install --frozen-lockfile`, which avoids
the integrity-check failure mode entirely. The TS 6 typecheck was
nevertheless **verified locally** in that session before reverting, so
the procedure is known-good.
