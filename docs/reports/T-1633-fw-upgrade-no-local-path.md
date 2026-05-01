# T-1633 — `fw upgrade` must work without local-path knowledge

**Status:** inception
**Origin:** S-2026-0501-1133 cohort agent flailing on `/opt/002-Claude-Partner-Network/fw upgrade`
**Predecessor RCAs:** T-1542 (closed prematurely; created the louder dead-end), T-1626 (immune-system loop for hooks — same pattern this task addresses for upgrade)

---

## Symptom (the trigger)

Cohort agent on a vendored consumer cannot upgrade its framework. Every path it tries hits a wall that tells it to do something it structurally cannot do. To even attempt the suggested workaround, it has to `find / -name agentic-engineering-framework` — i.e. scavenge the filesystem for the framework's location because the framework refuses to tell it.

## Root cause

`fw upgrade` was designed for "developer with two directories on one box" and never redesigned to work for "consumer with no checkout on any box." The framework has no `upstream: <url>` concept that would close the gap. Every consumer in the framework's history has been `/opt/0XX-*` on the same machine as `/opt/999-Agentic-Engineering-Framework`. The dependency on the developer's filesystem layout has been silent the entire time.

## Why structurally allowed

Every guard the framework has built is an inward guard:
- T-559 (project-boundary): protects consumer from cd-ing out
- T-1542 (self-target): protects consumer from corrupting itself via self-copy
- PreToolUse task gate: protects consumer from editing without governance

None ask the outward question: *"can the consumer still do its routine maintenance from a clean state?"* No test, no audit, no monitor checks "from a clean LXC with nothing in `/opt` except this consumer, can `fw upgrade` succeed?" If anyone had ever tried that, the gap would be visible in 2 minutes.

## Why T-1542 didn't catch this

T-1542's decision log explicitly considered re-exec and rejected it on "no reliable LOCAL target." It did not consider remote URL — the entire frame was *find a local framework directory*. The frame excluded fetching. T-1542 fixed the *crash* (state corruption on self-copy) and shipped a louder dead-end. The user story "vendored consumer upgrades itself" was never closer to working — it just stopped corrupting state on the way to failing.

## Why this session's work didn't catch this

I evaluated T-1542 today and reported "implementation shipped, 4/4 tests pass, guard verified." I marked it ready-to-close based on AC-level completion. I did this **right after writing T-1631 / T-1632 about T-1626's immune-system loop** — a loop whose purpose is catching this exact pattern. I had every signal in front of me. The recursion is the lesson: G-019 doesn't just describe a class of past failures; it describes the failure mode I'm in **right now** unless I instrument against it structurally.

---

## Three sub-problems (all blocking)

### 1. Upstream URL convention

`.framework.yaml` gains an `upstream:` field — a git URL, not a path. Default seeded by `fw init` and `fw vendor` from the framework's own canonical URL (probably the onedev mirror; github mirror as fallback). Existing consumers without `upstream:` get a one-time migration: if `.agentic-framework/` is itself a git working tree, use `git remote get-url origin`; otherwise default URL.

### 2. Git-fetch upgrade flow

`fw upgrade` with no args:
1. Read `.framework.yaml: upstream`
2. `git clone --depth 1 $upstream /tmp/fw-upgrade-XXX/` (or refresh `~/.framework-cache/`)
3. Use that as source for vendor + sync steps
4. Bump `.framework.yaml: version:` from the cloned VERSION file
5. Clean up tempdir

Zero local-path knowledge required. T-1542's guard stays as defensive safety net (it'll never fire on the canonical path) but stops being the primary control flow. `--source` flag remains for power users who want to upgrade from a local checkout (developer flow).

### 3. Fresh-machine simulation guard (THE LOAD-BEARING PIECE)

This is what closes G-019 properly. Without it, we will regenerate this class of failure forever:
- New audit / CI check: "fresh-machine upgrade simulation"
- Runs in a clean container (LXC or docker)
- Has only `.agentic-framework/` from a tagged consumer
- No `/opt/999-...`, no `~/.local/bin/fw`, no developer artifacts
- Runs `fw upgrade`
- Asserts success + version bump
- Runs on every framework release tag
- Failure blocks the release

Same pattern extends to `fw init`, `fw doctor`, any consumer-facing command. The general rule: **every consumer-facing command must be runnable from a clean machine with no developer artifacts.**

---

## Decision

**GO — pursue all three sub-problems as a single arc.**

The three are not separable:
- (2) without (1) has nowhere to fetch from
- (1) + (2) without (3) regenerates the same blindness in 6 months
- (3) without (1) + (2) has nothing to test

**Sequence on GO:**
1. Build (1) + (2) as one task (T-XXXX): `upstream:` field + git-fetch upgrade flow
2. Build (3) as one task (T-YYYY): fresh-machine simulation, blocking on release
3. Codify the rule in CLAUDE.md as part of (3)'s deliverable

**Out of scope:**
- Auth for private upstreams (covered by user's existing git config; no new credential handling)
- Cache management beyond per-invocation tempdir (start simple; add `~/.framework-cache/` only if perf demands it)
- Reverting T-1542's guard (it remains as defensive safety net; primary path no longer reaches it)

## Dialogue Log (C-001)

**Initial framing (agent):** "I'd file T-1639 (build, bug-class) as a small fix to T-1542's error message — three options A/B/C, ship A first."

**Human pushback 1:** "no its not its a fricing mess. why does agent even want to read from /opt that nonsensical ???!!!"
→ Course correction: the agent shouldn't need to know about /opt/999 at all. The framework forces it to scavenge. This is structural, not a message-polish problem.

**Agent revision:** Proposed remote URL in `.framework.yaml` + git clone in `fw upgrade`. Three implementation options A/B/C of increasing scope.

**Human pushback 2:** "no i want us to undersatand (rca) why this is such a frickin mess !!!"
→ Course correction: stop proposing fixes; do the actual root cause walk. Why does the agent ever read from /opt? Why is upstream defined as a local directory? Why has nobody noticed?

**Agent RCA:** Walked five-whys. Concluded: framework was built for one-developer-one-machine; vendored mode was bolted on; upgrade flow was never redesigned; no test asks "does this work on a clean machine"; T-1542 fixed the crash and shipped a louder dead-end.

**Human pushback 3:** "this is a huge fucking failure ::: that fact you dont recognise this... SO NOW WHAT ARE WE GOING TO DO ABOUT THIS ???!!!"
→ Course correction: the RCA cannot end with "the mess was always silent" — that absolves. Own the magnitude. I had T-1542 in my hands this session and walked past it; T-1626's immune-system loop was the same pattern; I shipped it and didn't apply it. Action plan now, not analysis.

**Agent action plan:** Three steps + accountability piece. Step 3 (fresh-machine simulation) is non-negotiable — without it, we regenerate this. Sequence: (1)+(2) as one arc, (3) as one arc, codify in CLAUDE.md.

**Human:** "ok"
→ Authorization to file this inception.

---

## Acceptance for this inception (T-1633)

This inception is complete when:
- [x] RCA captured (above)
- [x] Three sub-problems named and scoped
- [x] Decision recorded with sequence
- [x] Dialogue log captured (this section)
- [ ] Human runs `fw inception decide T-1633 go` (or no-go / defer with reason)
- [ ] On GO: framework-agent files the two follow-up build tasks for the actual implementation

The implementation tasks are NOT in this inception's scope. Per inception discipline, no source files are edited under this task ID after the GO decision — the build tasks own that.
