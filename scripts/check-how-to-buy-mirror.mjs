#!/usr/bin/env node
// Verifies the docs how-to-buy page still equals what vinuchain.org/buy
// rendered when it was generated, and has no price, yield or referral wording.
//   node scripts/check-how-to-buy-mirror.mjs
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const page = join(root, "technical-docs/cross-chain-bridging/how-to-buy-vc.md");

const failures = [];
const fail = (msg) => failures.push(msg);

if (!existsSync(page)) {
  console.log("how-to-buy page not present: nothing to check");
  process.exit(0);
}
const md = readFileSync(page, "utf8");

const begin = "<!-- BEGIN MIRRORED FROM vinuchain.org/buy -->\n";
const end = "<!-- END MIRRORED -->";
const start = md.indexOf(begin);
const stop = md.indexOf(end);
const recorded = md.match(/<!-- source-sha256: ([0-9a-f]{64}) -->/)?.[1];

if (start < 0 || stop < start || !recorded) {
  fail("mirror markers or source-sha256 are missing");
} else {
  const block = md.slice(start + begin.length, stop);
  const actual = createHash("sha256").update(block).digest("hex");
  if (actual !== recorded) {
    fail(`mirrored block was edited by hand (sha256 ${actual} != recorded ${recorded}); regenerate it from vinuchain.org/buy copy`);
  }
  const wording = block.match(/\b(prices?|priced|yields?|returns?|apr|apy|profits?|gains?|earn\w*|feeless|zero[- ]fee)\b/i);
  if (wording) fail(`forbidden wording in mirrored block: ${wording[0]}`);
}

const refLink = md.match(/[?&](ref|referral|aff|affiliate|invite|code)=/i);
if (refLink) fail(`referral or affiliate parameter in a link: ${refLink[0]}`);

if (failures.length) {
  for (const f of failures) console.error(`FAIL: ${f}`);
  process.exit(1);
}
console.log("how-to-buy mirror: ok");
