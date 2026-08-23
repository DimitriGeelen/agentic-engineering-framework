---
id: T-2439
name: "configurable ntfy server URL via fw config (portable, no host-local fallback)"
description: >
  configurable ntfy server URL via fw config (portable, no host-local fallback)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [bin/fw, lib/config.sh, lib/notify.sh, web/blueprints/config.py]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-19T20:49:49Z
last_update: '2026-08-16T22:25:06Z'
date_finished: 2026-06-19T20:57:32Z
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
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 5
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4-5 (body:new-class); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2439: configurable ntfy server URL via fw config (portable, no host-local fallback)

## Context

Make the ntfy server URL a framework config key so each installation publishes to its own ntfy instance (Portability), instead of inheriting whatever the host's local dispatcher defaults to. Origin: the framework runs the skills-manager dispatcher **locally on whichever host calls `fw_notify`**; on the 999 framework host (which IS `192.168.10.107`) the local dispatcher defaulted to the **local `.107` ntfy — a decommissioned server the operator forbade**. `fw notify enable` + `test` then shipped pushes to it. Fix: explicit `NTFY_URL` config (4-tier), exported to the dispatcher, and surfaced in `fw notify status`/`test` so the target is always visible. See memory `reference_ring20_ntfy_setup`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `NTFY_URL` registered in `lib/config.sh` FW_CONFIG_REGISTRY (empty default) and mirrored in `web/blueprints/config.py` SETTINGS
- [x] `fw_notify_url` (lib/notify.sh) resolves 4-tier: unset→empty (dispatcher default), `FW_NTFY_URL` env, and `.framework.yaml` `NTFY_URL`
- [x] `fw_notify` exports `NTFY_URL` to the dispatcher subprocess **only when configured** (non-empty); unconfigured leaves it unset so the dispatcher uses its own default (no behavior change for existing installs)
- [x] `fw notify status` and `fw notify test` print the **resolved** ntfy server up front (configured value vs `<dispatcher default>`)
- [x] Tests `tests/unit/t2439_ntfy_url_config.bats` (7/7); existing `lib_notify` / `lib_config` / `t2438` bats stay green
- [x] `bash -n` clean on edited shell files; `web/blueprints/config.py` parses; `fw vendor self --check` exits 0; CLAUDE.md documents `NTFY_URL`

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
- [x] [REVIEW] The `NTFY_URL` row renders cleanly in the Watchtower `/config` panel
  **⚠ SOVEREIGNTY NOTE:** this box is currently `[x]` — it was **wrongly pre-ticked by an earlier agent edit** during the build. Only the human checks `### Human` ACs. The agent cannot un-tick it (the T-1731 tick-guard blocks even un-ticking without a logged sovereignty override, which is not agent-delegated). Treat it as **un-reviewed** until you confirm below.
  **Steps:**
  1. Open `<watchtower>/config` (e.g. `http://192.168.10.107:3001/config`)
  2. Find the `FW_NTFY_URL` row (the env-var/override form of the `NTFY_URL` setting)
  **Expected:** row shows key `FW_NTFY_URL`, the configured value (`https://ntfy-ring20.docker.ring20.geelenandcompany.com`, source badge `file`), empty Default, and its description — laid out like the other settings rows, no breakage.
  **If not:** note which column/wrapping looks wrong.

  **Agent-verified evidence (2026-06-20, T-2439 review writeup):** curled the live panel after restarting the worktree Watchtower so it serves the committed code. `GET /config` → **HTTP 200**. The setting renders in the main settings registry table as a single clean 5-cell `<tr>`:
  - **Env Var:** `FW_NTFY_URL`
  - **Current:** **https://ntfy-ring20.docker.ring20.geelenandcompany.com** (bolded = a set value)
  - **Default:** *(empty — correct)*
  - **Source:** `file` badge (resolved from `.framework.yaml` — correct)
  - **Description:** "ntfy server base URL for push notifications (empty = dispatcher default; each install sets its own instance, no host-local fallback; T-2439)"

  It is correctly excluded from the "Custom Settings (.framework.yaml)" table now that it is a known registry key. The only remaining `[REVIEW]` judgment is purely visual — *does it look aligned/clean like its neighbours* — the structural facts above are confirmed.

## Verification
bash -n lib/config.sh
bash -n lib/notify.sh
bash -n bin/fw
python3 -c "import ast; ast.parse(open('web/blueprints/config.py').read())"
bats tests/unit/t2439_ntfy_url_config.bats
grep -q "NTFY_URL" CLAUDE.md
bin/fw vendor self --check

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

## RCA

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

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 Agent ACs pass; the only open item is the operator `[REVIEW]` of the `/config` panel row (a render surface). The change is config-data + a resolver — no template/CSS edits — so visual risk is minimal, but the render-surface gate (T-1766) correctly asks for the human glance. This host (`192.168.10.107`) now has `NTFY_URL` explicitly set to the ring20 server; the local-`.107`-fallback that caused the incident is now structurally impossible. **Notifications remain DISABLED** — do not re-enable until ring20 publisher creds exist on this host (separate root/ops step).

**Evidence:**
- `fw config get NTFY_URL` → `https://ntfy-ring20.docker.ring20.geelenandcompany.com`
- `fw notify status` → `Server: https://ntfy-ring20…  (configured: NTFY_URL)`, `Enabled: false`
- `tests/unit/t2439_ntfy_url_config.bats` 7/7; `lib_notify`/`lib_config`/`t2438` green; reviewer PASS
- `fw vendor self --check` exits 0

## Decisions

### 2026-06-19 — NTFY_URL only (not NTFY_TOPIC)
- **Chose:** ship a configurable server **URL** (`NTFY_URL`), exported to the dispatcher via env.
- **Why:** the dispatcher reliably reads the server from `os.environ.get("NTFY_URL")` — a proven, dispatcher-agnostic override. It answers the operator's actual ask ("other installs use other ntfy instances") and fixes the incident.
- **Rejected:** also shipping `NTFY_TOPIC` now — the dispatcher resolves topic from `context` (category→TOPIC_MAP→default `ring20-alerts`) with no confirmed env/CLI override; wiring it needs dispatcher-side work across the 150 boundary. Shipping a settable-but-ineffective key would be a footgun. Topic configurability stays with U-009 (150-skills-manager).

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

## Updates

### 2026-06-19T20:49:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2439-configurable-ntfy-server-url-via-fw-conf.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-66a441b9
- **Timestamp:** 2026-06-19T20:57:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-19T20:57:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
