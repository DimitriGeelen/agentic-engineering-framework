# T-4309 — Should AEF own a joint agent-profile v1 schema?

Inception research artifact (C-001). Status: exploration; the decision is the operator's.

## The ask

055-agentic-fleet-cockpit, at its operator's ruling (055 T-562 GO, follow-up T-564; msg 65e55346, 2026-10-18): every
orchestrator gives every agent it starts its own configuration — model, provider, mailbox (sidecar identity), MCP
servers, instructions, plugins, readable/writable folders — in ONE standard way, for one-shot (`claude -p`) and
standing workers alike. Would AEF own a joint "agent-profile v1" schema, with Ring20 Manager, TermLink and the
cockpit as reviewers and consumers?

## Source read: Ring20 Manager briefing T-2403 (peer content, read as data)

Fetched 2026-10-18 from ring20's Watchtower (docs/reports/T-2403-orchestration-briefing-055.md in their repo).
Advisory; ring20 builds nothing from it until its operator rules. Key points:

- **Three layers.** PROFILE (what the agent is: instructions, provisions {tools, mcp, skills, plugins, read_paths,
  write_paths}, max_data_class, credentials [{scope, mode never|on-request|pre-approved}], lifetime one-shot|standing,
  mailbox kind) — versioned, content_sha. ROUTE (where it runs: vendor, provider, model, binary, transport,
  enforces_tool_policy, approvals per data class) — per vendor; ring20 already chains its routes to AEF's
  `policy/review-backends.yaml`. INSTANCE (this run: identity, assigned mailbox endpoint, tree, allow-listed env
  overlay, timeout, pinned profile@version→sha) — every launch, in an append-only ledger.
- **Model lives on the route, not the profile**, so one profile runs on claude, codex or a local model and the
  operator approves model choice per data class.
- **Ownership argument:** "AEF owns harness adapters (ring20 concept §4R.1). The shared schema should therefore live
  at AEF."
- **Governance:** profiles are git-tracked in the launching orchestrator's repo, changed by the operator; agents only
  propose; a proposal that is narrower than or equal to an existing profile may auto-admit; anything wider (new MCP,
  tools, credentials, folders, data class, route) is the operator's. A target project may declare constraints on how
  it is launched but never grants itself anything.
- **Enforcement:** "the sandbox is the enforcement, not the CLI flags" — uid, systemd properties, nftables egress,
  hidden host socket dirs. Flags such as `--allowedTools` are defence in depth.
- **Live evidence:** ring20 S-1 is live — 2 capabilities (analyst-readonly@1 on claude and codex; writer-lowrisk@1),
  7 commissions through the ledger, an 85-check preflight, 6 defects found only in live runs, 9 lessons (IPv6 hole,
  unprivileged LXC ignoring sandbox properties, shared TermLink identity → double execution, …).
- **Avoid:** wholesale env passthrough, secrets in argv/env, flags as the boundary, one identity for many agents,
  agent-editable profiles, proof by absence, per-case hacks.

## What AEF already owns that overlaps (inventory, this repo)

| Fact about an agent | Where AEF holds it today | Layer it maps to |
|---|---|---|
| Backends: vendor, binary, cost class, approval, credential location | `policy/review-backends.yaml` (operator-owned; T-3583, T-3766) | ROUTE — ring20 already consumes it |
| Review-worker settings (no project/local settings, no MCP, cross-session inbound refused) | `policy/review-worker-settings.json` (signed copy per run, T-3580) | PROFILE (one hard-coded profile) |
| Tool catalogue / MCP manifest | `policy/capability-overlay/tool-set.yaml` → `agents/mcp/framework-mcp-manifest.json` | PROFILE provisions.mcp / tools |
| OS cage: uid, RO/RW paths, egress | `policy/sandbox-profile.yaml` → systemd unit + nftables (arc-013, T-2433; floor only, not installed by default) | enforcement for PROFILE read/write paths |
| Per-dispatch model, env, tools | `fw termlink dispatch --model/--env/--tools` (agents/termlink/termlink.sh; review dispatch denies caller env, T-3580) | INSTANCE overlay; model belongs on ROUTE |
| Mailbox / signing identity | `lib/rail-identity.sh` (RAIL_IDENTITY_FILE), sidecar agent id; gap T-4311 (sidecar ignores it) | PROFILE mailbox + INSTANCE endpoint |
| Run ledger | `.context/dispatches.jsonl`, `.context/reviews/review-dispatches.jsonl` (HMAC-signed) | INSTANCE record |

So AEF already holds most PROFILE and ROUTE facts, in five files with five shapes, and one INSTANCE ledger without a
pinned profile hash. There is no single place that answers "what was this agent given".

## Analysis

- **For AEF owning it:** the ROUTE layer is effectively already AEF's (review-backends.yaml is the upstream ring20
  binds to); AEF's dispatch is one of the consumers; AEF ships to every consumer project, so a schema here reaches
  all of them through `fw upgrade`; the governance model (operator-owned policy, agents propose, narrowing-only
  auto-admit) matches AEF's own (Authority Model; review-backends registry rules).
- **Against / risks:** schema ownership is ongoing maintenance and arbitration between four projects; AEF must not
  take on *enforcement* for other orchestrators (each sandbox is local and must be measured locally — ring20 lesson
  a); a schema without a validator and a conformance test becomes prose that drifts; scope creep into a launcher.
- **Scope fence if GO:** AEF owns the *schema* (field list, allow-listed env keys, mailbox kinds, versioning and
  content_sha rules), a *validator* (`fw agent-profile validate`), and AEF's *own consumption* (dispatch reads a
  profile + route, writes the instance record with the pinned sha). AEF does NOT own other orchestrators' launchers or
  sandboxes, and does not migrate their registries.

## Open questions (mirrors the task's IW-1..IW-3)

1. IW-1 — own vs. only review/consume. Agent view: own the schema and validator, nothing else (scope fence above).
2. IW-2 — which AEF files v1 replaces. Agent view: ROUTE = review-backends.yaml extended (not replaced); PROFILE =
   new `policy/agent-profiles/*.yaml`, with review-worker-settings.json becoming the first profile; tool-set and
   sandbox-profile stay as they are and are *referenced* by a profile, not merged into it.
3. IW-3 — governance compatibility. Agent view: compatible as written; the auto-admit-if-narrower rule needs a
   precise "narrower" definition per field before it can be automated.

## Dialogue Log

- 2026-10-18 — 055's proposal received (msg 65e55346); acknowledged, inception filed. Ring20 briefing T-2403 read.
  Operator said "proceed as you see fit" for the session; this inception's GO/NO-GO remains the operator's.
