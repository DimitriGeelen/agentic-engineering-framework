# T-1268: Cross-machine update propagation friction — research artifact

**Status:** Inception complete (recommendation written 2026-04-23)
**Owner:** agent
**Linked task:** `.tasks/active/T-1268-cross-machine-update-propagation-frictio.md`

## Problem (recap)

Agents detect drift in artefacts that sit outside their current project boundary but cannot self-heal it. Two recurrences in session 2026-04-15:

1. **Boundary-blocked update** — Global `/root/.agentic-framework` install. Agent in `/opt/999-...` could not run `fw update` against the global install because the boundary gate (`agents/context/check-project-boundary.sh`) blocked the cross-repo edit. Agent handed `cd /root && /root/.agentic-framework/bin/fw update` to the human.
2. **Toolchain-missing update** — TermLink binary update needed `cargo` on the target host. Host lacked cargo, so agent could pull source (0.9.400 → 0.9.872) but not rebuild. Workaround: build elsewhere, scp in.

The boundary gate is correct (A1). The cargo dependency is incidental, not architectural. The question is what affordance closes the loop on each class.

## Spike A — Completion rate of copy-pasteable update commands

**Method:** grep `.context/working/.gate-bypass-log.yaml` and last 30 handovers for explicit "copy-pasteable" markers + completion follow-through (subsequent doctor-clean / commit landing the suggested change).

**Findings:**
- 0 explicit "copy-pasteable" string matches in bypass log or last 30 handovers
- T-1268 itself only appears in 2 handovers (the originating session and one follow-up)
- 24 concerns mention "drift" but most are doc/code drift, version-pin drift, config drift — not specifically the cross-machine class T-1268 names

**Conclusion:** **Cannot measure A2 directly** — the framework doesn't instrument copy-paste handoffs. We measure recurrence by *number of times the agent re-encounters the same blocked action*, but that telemetry doesn't exist either. **A2 is unverified**, but the *recurrence proves* that drift persists: T-1268 was filed because the same problem re-occurred between sessions, not closed in the first.

**Implication for design:** The pending-updates registry (Spike D) provides exactly the missing telemetry — every blocked update gets a structured record that can be aged-out and counted.

## Spike B — Boundary-blocked actions enumeration

**Method:** grep for boundary gate references and distinct error sites.

**Findings:**
- Boundary enforcement is **centralized in one file**: `agents/context/check-project-boundary.sh` (PreToolUse hook)
- Allowed exceptions: `/tmp/**`, `/root/.claude/**`, `/etc/cron.d/**`, `PROJECT_ROOT/**`
- Origin: T-559 (agent created 6 tasks on another project)
- Block surface: any Write/Edit/NotebookEdit with file_path outside the allowlist; Bash commands matching cd+write patterns targeting other projects
- **Single block site** means a single "what to do instead" affordance can serve all cases

**Distinct blocked-action classes observed in field:**
- B1: `fw update` against global `/root/.agentic-framework` (this is T-1268 case 1 — file-write to another project)
- B2: Cross-project task creation (T-559 origin — write to `.tasks/active/` outside PROJECT_ROOT)
- B3: Edit consumer project's CLAUDE.md from framework session (would-be cross-repo edit)
- B4: Push patches to a sibling project's git tree

All four would benefit from the same mechanism: agent registers the intended action, framework surfaces it to the human (or to a session on the target project), human confirms or session-on-target executes.

## Spike C — TermLink binary distribution options

**Trade-off matrix:**

| Option | Cost | Reach | Toolchain on target | Status |
|---|---|---|---|---|
| C1: GitHub Releases prebuild matrix | Medium (CI matrix + gh release workflow) | Universal | None | **Recommended** |
| C2: Homebrew bottle (extend Linuxbrew) | High (formula maintenance per platform) | macOS+Linux | brew | Partial |
| C3: `cargo install --git` (status quo) | Zero | Universal | cargo (fails the case) | Current |
| C4: Self-extracting curl-bash installer | Low | Universal | curl, bash | Useful as wrapper around C1 |
| C5: OCI image | Medium | Universal | docker | Orthogonal |

**Recommendation:** **C1 + C4** — publish per-platform release tarballs (linux-x86_64, linux-aarch64, darwin-x86_64, darwin-aarch64) and a `curl install.sh | sh` wrapper that detects platform and pulls the right artefact. Eliminates the cargo dependency on target hosts. C3 stays for source-of-truth/dev installs.

## Spike D — "Pending updates" registry design

**Sketch:**

```
.context/working/pending-updates.yaml
  - id: PU-001
    detected_at: 2026-04-23T10:00:00Z
    target_path: /root/.agentic-framework
    target_kind: global-install
    blocked_command: fw update
    rationale: "Global install at v1.5.76, latest v1.5.115"
    suggested_action: "cd /root && /root/.agentic-framework/bin/fw update"
    last_reminded_at: 2026-04-23T10:00:00Z
    remind_after: 86400  # seconds (24h)
    resolved_at: null
```

**Surfaces:**
- `fw doctor` lists unresolved entries with one-line summary
- Watchtower renders a "Pending Updates" panel with one-click copy
- Optional: 24h cron pings via `fw notify` (T-notify already exists)

**Resolution detection:**
- Heuristic: re-run the inferred check (e.g. `fw upgrade --dry-run` for global install) — if drift gone, mark resolved
- Manual: `fw pending resolve PU-XXX --notes "ran the update"`

**Cost:** ~150 LoC shell + 1 Watchtower template + 2 unit tests. Half-session.

## Spike E — Cross-machine dispatch via TermLink remote exec

**Sketch:** `termlink remote exec <host> "<command>"` already exists. Pattern would be: agent on host A registers a pending-update with `target_host: B`; if termlink session on B exists, framework can offer "execute remotely" affordance.

**Risks:**
- Authority model: agent on A holding task-context T-XXX shouldn't auto-mutate host B without explicit per-host approval. Same Tier 0 logic must apply at the boundary.
- Network/secret considerations: `termlink remote` already crosses trust boundary; piggy-backing destructive commands on it inherits and amplifies that exposure.
- Target session must hold task context too — otherwise the remote `fw update` itself would fail the task gate on the target.

**Recommendation:** **Defer to a follow-up inception.** The pending-updates registry (D) closes the loop without requiring cross-machine authority decisions. Add E only if measured residual friction justifies it.

## Dialogue Log

(No live dialogue — agent-driven inception. Spike measurements + design sketches done from session evidence and code inspection.)

## Recommendation

**Recommendation:** **GO (partial scope)** — build C1+C4 (TermLink prebuild matrix + curl installer) and D (pending-updates registry). Defer E (cross-machine dispatch) to a follow-up inception once residual friction is measured.

**Rationale:** The two T-1268 recurrences are symptomatic of the broader class A5 ("agent can diagnose drift but cannot fix in place"), but the right structural answer differs by class. For boundary-blocked updates, the answer is *not* to weaken the gate (A1 holds) — it's to give the agent a write-able registry that surfaces the intent to the human / target session. For toolchain-missing binary updates, the answer is to remove the toolchain dependency, not to ship cargo to every host. C1+C4 and D are scoped, testable, reversible, and address measurable friction. E is interesting but adds a cross-machine authority surface that warrants its own scoping.

**Evidence:**
- Boundary gate is centralized (one file, one allowlist) — a single registry primitive serves all 4 observed blocked-action classes (Spike B)
- Pending-updates registry is the missing telemetry: today we cannot measure copy-paste completion rate (Spike A failed to produce A2 numbers — there's no instrumentation)
- TermLink binary already supports `cargo install --git`; adding GitHub Releases prebuilds is mechanical (Spike C, C1)
- Half-session cost for D, ~1-day for C1+C4 release matrix
- Reversible: pending-updates entries are append-only and can be ignored; release matrix doesn't replace cargo install

**Build decomposition (after GO):**
- B1: `.context/working/pending-updates.yaml` schema + `fw pending {register,list,resolve}` CLI
- B2: `fw doctor` integration (surface unresolved entries)
- B3: Watchtower `/pending` page with one-click copy
- B4: Optional cron (`fw pending remind`) — 24h ping for stale entries
- B5: TermLink GitHub Releases matrix (.github/workflows/release.yml in /opt/termlink)
- B6: TermLink `install.sh` curl-bash installer

Each <1 session. B1+B2 alone close case 1 (boundary-blocked). B5+B6 close case 2 (toolchain-missing). B3+B4 are quality-of-life.

**Reversibility:** Every B-unit is additive. No existing surface is removed. Can ship B1+B2+B5 first and stop if B3/B4/B6 prove unnecessary.

**Out of scope (deferred):** Spike E (cross-machine dispatch) — separate inception once D's telemetry shows whether residual friction justifies it. Modifying the boundary gate (A1 unchanged).
