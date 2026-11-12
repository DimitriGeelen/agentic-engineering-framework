# T-5009 review round 3 — opencode (subscription), 2026-11-12

Brief: docs/reports/T-5009-review-r3-brief.md. Dispatch rv-t5009-r3-opencode-e9b3958212ff. Stored verbatim below.

## Review, round 3

### 1. Proportionate — mostly. The center is right; the edges are over-built.

Running code you didn't write on your own hardware is the real risk here, and "fresh VM, no network, destroy after, treat output as data" is the standard cheap answer. That core is not paranoia — it's roughly what hosted CI does with fewer layers. Keep it. What I'd relax:

- **Drop the reader VM and the node helper.** Two VM lifecycles per run doubles failure modes and template maintenance for a benefit (parsing an untrusted filesystem) you only need if you ship artifacts. A node-side helper puts a persistent SSH surface on the one machine that sits next to your registry credentials.
- **Soften output handling.** Cap size, treat as data, parse as JSON, never execute. Full sanitising/schema validation is work without risk reduction at pilot scale.
- **Raise the 64 KB budget.** With ~1,400 test files, failed runs will blow past it constantly and you'll re-run things by hand just to see why. A few MB (compressed log + status) with truncation markers so you know when you lost the tail.

One thing is *under*-protected, not over: the credentials container and object storage sharing a node with untrusted guests. That co-tenancy matters more than anything on the I/O path. Until the standalone host is ready, the cheap fix is moving that container, not hardening channels.

Do **not** relax: no NIC, never mounting guest-produced disks on controller or node, pool-scoped token, destroy after run. These cost nothing and are the load-bearing walls. And don't build a "trusted contributor" fast lane — the pilot's whole value is shaking down the strict path you'll need for genuinely untrusted PRs.

### 2. Pick A.

One VM, one template, one code path in and out; the added token rights (upload on one storage, allocate on another) are modest and scoped. Practical pain, and mitigations:

- **Serial is your only channel**, and the websocket stream can drop or interleave bytes. Frame the result with a checksum and end-marker so truncation is *detected*, not guessed.
- **Debugging failed runs** means logs and nothing else — no artifacts, no poking around. Survivable if the budget is generous (a couple of MB, gzip+base64) and the run script always ends with a structured summary: failed tests, last N lines. If you later need artifacts, bolt a small output disk onto A then; that's the one thing B is good for.
- **Binary over console is ugly** — keep the console text, carry the payload in the framed block.
- **Parallelism**: one at a time is correct now; A doesn't prevent widening later.

B is A plus a second VM to babysit — the over-engineering you're feeling. C adds a helper and a key to your most sensitive host and involves attaching untrusted disks there; reject. D's host-only collector reintroduces a network stack in the guest plus an always-on service to defend, and the allow-list mirror solves a problem (missing deps) you don't have yet since the template carries everything.

### 3. Smallest version, runnable in days

Template VM (no NIC), pool-scoped token plus the two storage rights, ISO built from the released run script + a git bundle of the PR, run, stream console log, framed JSON status at the end (few-MB cap), destroy the VM. Skip for now: schema validation beyond JSON parsing, artifacts, parallel runs, auto-triggering.

Must not skip even for the trusted pilot: VM isolation for the code; no network; never mount anything guest-produced on controller or node; token limited to pool + those two storages, never broader; destroy after run. And before the first outside PR — not after — get the credential container off that node, or write down explicitly that you're accepting a guest escape reaching it. The dedicated host is the real fix; don't let the pilot schedule wait on it, but that's your weakest wall, not the console channel.

Bottom line for the maintainer: you're not over-protecting the guest — you're over-building the plumbing around it. Simplify to A, widen the output budget, and spend the saved effort on the co-location problem.
