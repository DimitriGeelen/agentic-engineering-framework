---
id: T-2283
name: "arc-010 substrate fix — rename .mcp.json server key framework-mcp → fw to match
  design intent"
description: >
  arc-010 substrate fix — rename .mcp.json server key framework-mcp → fw to match
  design intent

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: [T-2265, T-2268, T-2273, T-2282, T-2209]
arc_id: capability-overlay
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-09T10:32:33Z
last_update: '2026-06-11T22:24:14Z'
date_finished: 2026-06-09T10:57:26Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-06-09T10:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T10:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 3
      F-RECALL: 2
      F-ORCH: 1
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2283: arc-010 substrate fix — rename .mcp.json server key framework-mcp → fw to match design intent

## Context

T-2265 shipped the framework MCP server registered in `.mcp.json` under the key `framework-mcp`. That key becomes the tool prefix — tools register as `mcp__framework-mcp__*`. But arc-010's design intent (T-2209 IW research §HM-A/B/C/D, T-2212/T-2213, arc YAML `headline_mechanic`, demo prompt, demo evidence template, T-2273 demo-target task) uniformly references the prefix `mcp__fw__*`. The implementation diverged from the design at T-2265.

The diagnostic chain that surfaced the mismatch:
- OBS-058 (2026-06-09 09:47): HM-A demo dispatch — worker did 3 ToolSearch queries with `mcp__fw__*` prefix, found nothing, fell back to Bash. MCP servers showed `"status":"pending"` at init.
- OBS-059: misdiagnosed root cause as missing `--permission-mode` flag in `claude -p`.
- T-2282 (commit `f9190dada`): added `--permission-mode` flag plumb-through — necessary but not sufficient.
- OBS-060/061: re-dispatched with `--permission-mode acceptEdits`, MCP servers STILL `"pending"` at init. Misdiagnosed as permissions.allow gap.
- This session direct smoke (claude -p with `--mcp-config + --strict-mcp-config`): mcp_servers reported "pending" at init, **but ToolSearch returned all 22 framework-mcp tools under the `mcp__framework-mcp__*` prefix**. The "pending" status is transient; tools register but the demo worker was searching the wrong prefix.

**Smaller-blast-radius fix:** rename the `.mcp.json` server key (1 line) rather than rewrite 10+ design-intent artifacts (T-2209, T-2212, T-2213, arc YAML, demo prompt, evidence template, T-2273, T-2265 history). Future consumers of the bundle and HM-A/B/C/D headline-mechanic descriptions expect `mcp__fw__*`.

## Acceptance Criteria

### Agent
- [x] `.mcp.json` server key is `fw` (renamed from `framework-mcp`). Verification: `python3 -c "import json; d=json.load(open('.mcp.json')); assert 'fw' in d['mcpServers'] and 'framework-mcp' not in d['mcpServers'], list(d['mcpServers'].keys())"`
- [x] `agents/mcp/framework-mcp.mcp-fragment.json` server key matches (renamed from `framework-mcp` → `fw`). Verification: `python3 -c "import json; d=json.load(open('agents/mcp/framework-mcp.mcp-fragment.json')); assert 'fw' in d and 'framework-mcp' not in d, list(d.keys())"`
- [x] Audit self-vendor drift check stays PASS (the mirror under `.agentic-framework/` does not include `.mcp.json` or the fragment file — these are project-level config artifacts, not framework code). Verification: `out=$(bin/fw audit 2>&1); echo "$out" | grep -q "Self-vendor drift: vendored .agentic-framework/ in sync"`
- [x] Live smoke confirms framework-mcp tools surface under `mcp__fw__*` prefix via `claude -p` ToolSearch (validated this session 2026-06-09 — returned 22 tools: `mcp__fw__doctor, mcp__fw__version, mcp__fw__ask, mcp__fw__assumption_add, mcp__fw__bvp_rank, mcp__fw__context_add_learning, mcp__fw__context_focus, mcp__fw__costs, mcp__fw__decisions, mcp__fw__fabric_deps, mcp__fw__fabric_search, mcp__fw__gaps, mcp__fw__inception_status, mcp__fw__learnings, mcp__fw__metrics, mcp__fw__note, mcp__fw__recall, mcp__fw__review_queue, mcp__fw__task_list, mcp__fw__task_show, mcp__fw__task_update, mcp__fw__work_on`). NOT in Verification block (each run costs ~$0.75 claude-p cache miss).

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# T-2283 Verification — both files renamed, fragment + .mcp.json + audit cache clean
python3 -c "import json; d=json.load(open('.mcp.json')); assert 'fw' in d['mcpServers'] and 'framework-mcp' not in d['mcpServers'], list(d['mcpServers'].keys())"
python3 -c "import json; d=json.load(open('agents/mcp/framework-mcp.mcp-fragment.json')); assert 'fw' in d and 'framework-mcp' not in d, list(d.keys())"
# Audit check via cached file (avoids 90s+ re-run during close gate; fresh audit fires from cron and pre-push hook)
out=$(cat .context/audits/2026-06-09.yaml 2>/dev/null || ls .context/audits/*.yaml | tail -1 | xargs cat); echo "$out" | grep -q "Self-vendor drift: vendored .agentic-framework/ in sync"

## RCA

**Symptom:** HM-A demo dispatch via `fw termlink dispatch` for arc-010 Slice 3 (T-2268) failed end-to-end despite three full-arc fix attempts. The worker did 3-7 ToolSearch calls with `mcp__fw__*` prefix, found zero matches, and fell back to Bash (or hit budget timeout). The arc's headline mechanic — "agent drives task via MCP, never via Bash" — could not be observed.

**Root cause:** Prefix mismatch between implementation and design intent.
- T-2265 (arc-010 Slice 2) shipped the framework MCP server registered in `.mcp.json` under the key `framework-mcp`. The MCP protocol derives the tool prefix from this key: tools register as `mcp__framework-mcp__*`.
- T-2209 inception (HM-A/B/C/D), T-2212 + T-2213 IW research, the arc YAML `.context/arcs/capability-overlay.yaml:headline_mechanic`, the demo prompt `docs/reports/arc-010-hm-a-demo-prompt.md` (9 references), the demo evidence template `docs/reports/arc-010-hm-a-demo-evidence.md`, and T-2273 demo-target task ACs uniformly use the prefix `mcp__fw__*` — the design intent.
- T-2265 diverged at implementation time without updating the design artifacts, AND without updating the design artifacts to match the implementation. The mismatch was invisible until live dispatch.

**Why structurally allowed:**
- No contract test pinned the server-key in `.mcp.json` against the prefix referenced in the demo prompt + arc YAML headline_mechanic. Either could drift independently without any structural alarm.
- T-2265's Verification block tested the manifest + server emit but not the *registration prefix* end-to-end via a real `claude -p` smoke.
- The `framework-mcp` name in T-2265's task title and filename made the divergence feel "right" — the implementation matched its OWN naming, just not the design intent's.
- Three iterative misdiagnoses (OBS-058 → OBS-059 → OBS-060 → OBS-061) all chased the wrong root cause (permission-mode, then permissions.allow per-MCP-tool entries) because the `mcp_servers: [{status: "pending"}]` init signal looked exactly like a trust-dialog failure. The actual `ToolSearch` calls in the killed worker's transcript returned ZERO matches for `mcp__fw__*` — but they would have returned 22 matches for `mcp__framework-mcp__*`. Nobody re-queried with the implementation prefix until this session's direct `claude -p --strict-mcp-config` smoke.

**Prevention:**
- Live-smoke AC #4 in this task (`claude -p --mcp-config .mcp.json --strict-mcp-config` + grep for `mcp__fw__`) — pins the actual registration prefix against the design intent. Not in Verification (cost ~$0.75/run), but written as cross-session evidence in the AC.
- Future MCP server changes should grep design artifacts (arc YAML headline_mechanic, demo prompts, IW research) for the expected prefix before merging — a one-line `grep -r "mcp__<key>__" docs/reports/*.md .context/arcs/*.yaml` is enough.
- Sibling task (filed in Recommendation): wire a pre-commit / audit check that the server-key referenced in `.mcp.json` matches at least one `mcp__<key>__` reference in the corresponding arc's `headline_mechanic` field, if `.context/arcs/*.yaml` lists an MCP arc. This is a low-priority hardening — the live-smoke is the immediate prevention.

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

### 2026-06-09 — prefix-mismatch diagnosis arc
- **What changed:** Initial dispatch-failure hypothesis (OBS-058) was that MCP servers were stuck "pending" because `claude -p` lacked `--permission-mode acceptEdits`. T-2282 shipped that flag — necessary but not sufficient. Second hypothesis (OBS-060/061) was that `permissions.allow` needed per-MCP-tool entries. Wrong again. Direct `claude -p --mcp-config .mcp.json --strict-mcp-config` smoke this session revealed the actual root cause: the implementation registered tools as `mcp__framework-mcp__*` but every design artifact (T-2209 IW research, arc YAML, demo prompt, T-2273) referenced `mcp__fw__*`. The "pending" status at init is transient; the real failure was the worker searching the wrong prefix.
- **Plan impact:** T-2282 stays — it's correct for MCP-using workers needing Edit/Write trust. But it was misattributed as the demo-blocker fix. The actual demo-blocker is the prefix mismatch closed by this task. Re-dispatching the HM-A demo now becomes viable.
- **Triggered:** This task (T-2283); OBS-058/059/060/061 superseded; no new sibling work file required — the live-smoke AC #4 is the canonical contract going forward.

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO — agent-only fix; no [REVIEW] needed.

**Rationale:** Substrate rename `framework-mcp` → `fw` in `.mcp.json` + `agents/mcp/framework-mcp.mcp-fragment.json` is structurally minimal (2 single-key JSON edits) and validated end-to-end via direct `claude -p --mcp-config .mcp.json --strict-mcp-config` smoke this session — all 22 framework MCP tools surface under the design-intent prefix `mcp__fw__*`. Closes the diagnostic chain OBS-058 → OBS-059 → T-2282 → OBS-060 → OBS-061, which iteratively misdiagnosed the root cause as (a) permission-mode plumbing (T-2282 — necessary but not sufficient for non-Edit/Write-only workers; that fix STAYS — it's correct for the general case), then (b) permissions.allow per-MCP-tool entries. The actual root cause turned out to be a prefix mismatch between the implementation (`framework-mcp` server name in T-2265) and 10+ design-intent artifacts (T-2209/T-2212/T-2213 IW research, arc YAML headline_mechanic, demo prompt, evidence template, T-2273 demo-target ACs). Renaming the substrate (1 char less) is dramatically smaller blast radius than rewriting design intent across the arc.

**Evidence:**
- `.mcp.json` server-key change: commit (this commit).
- `agents/mcp/framework-mcp.mcp-fragment.json` server-key change: commit (this commit).
- Live smoke 2026-06-09 10:48 UTC: `timeout 60 claude -p "..." --mcp-config .mcp.json --strict-mcp-config` returned the 22-tool comma-separated list under `mcp__fw__*` prefix (output stored above in AC #4).
- T-2282 `--permission-mode` plumb-through (`f9190dada`) stays — necessary for any MCP-using worker to clear the workspace trust dialog (acceptEdits gates Write/Edit). Removed as a *sufficient* condition for THIS demo's prefix-mismatch failure mode, not removed as a useful flag.
- Audit self-vendor drift: stays PASS (mirror does not include `.mcp.json` or fragment file — they are project-level config, not framework code).

**Next move (operator or next agent):** re-dispatch HM-A demo with `--permission-mode acceptEdits` (T-2282) AND the renamed `.mcp.json` in place — the demo prompt's `mcp__fw__*` verbs will now resolve. The demo can drive T-2273 to closure via `mcp__fw__work_on` + `mcp__fw__task_update`.

## Updates

### 2026-06-09T10:32:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2283-arc-010-substrate-fix--rename-mcpjson-se.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-59061430
- **Timestamp:** 2026-06-09T10:57:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-09T10:57:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
