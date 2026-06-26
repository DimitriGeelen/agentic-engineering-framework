---
id: T-2416
name: "diagnose ollama+openrouter LLM integration failure"
description: >
  diagnose ollama+openrouter LLM integration failure

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
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
created: 2026-06-26T12:07:24Z
last_update: 2026-06-26T12:07:24Z
date_finished: null
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
---

# T-2416: diagnose ollama+openrouter LLM integration failure

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Ollama-unavailability root cause identified with evidence: NOT a crash — `ollama.service` is in a systemd **restart-rate-limit dead state** (`StartLimitBurst` exhausted after 3–4 rapid retries on 2026-06-24 23:41). Trigger: **GPU-discovery timeout on the RTX 5060 Ti (Blackwell sm_120)** — bundled CUDA libs probe too slowly; systemd SIGTERM'd each retry. CPU fallback is viable (62 GiB RAM, 41 free). `systemctl start` alone re-loops unless GPU probe is fixed/disabled first.
- [x] OpenRouter configuration gap confirmed against LIVE main checkout: `OPENROUTER_API_KEY` unset, main `.context/secrets/` EMPTY (no `api-keys.enc` Fernet store), `.context/settings.yaml` = `provider: ollama` with no key, litellm-config.yaml has zero openrouter routes. Key path is `web/llm/manager.py:109` (env) → `web/secrets_store.get_api_key("openrouter")` (Fernet). No key on any path → `OpenRouterProvider` never registered.
- [x] LLM consumers mapped (all three broken, same root cause): `lib/ask.py` (`ollama.chat` direct, no openrouter path); `fw resolver` workers (litellm :4000 → ollama, no openrouter route); **Watchtower search** (`web/blueprints/api.py` → `web/llm/manager.py` → OllamaProvider; openrouter in code but unregistered). Operator confirmed the surface is **Watchtower search** (web/llm lane).
- [x] Remediation plan written to `docs/reports/T-2416-llm-integration-diagnosis.md` — ordered steps, operator-owned (reset-failed + CPU drop-in OR ollama upgrade; provide OpenRouter key) vs agent-fixable (add openrouter routes to litellm-config.yaml; optionally refactor `fw ask` to route through a proxy).

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
test -f docs/reports/T-2416-llm-integration-diagnosis.md
out=$(cat docs/reports/T-2416-llm-integration-diagnosis.md); echo "$out" | grep -q "Root Cause 1 — Ollama"
echo "$out" | grep -q "Root Cause 2 — OpenRouter"
echo "$out" | grep -q "Remediation Plan"

## RCA

**Symptom:** Watchtower search (and `fw ask`, and litellm-dispatched workers) return connection errors — the LLM integration is non-functional across all three consumers.

**Root cause (two, independent):**
1. **Ollama** is in a systemd restart-rate-limit dead state. A `systemctl restart` at 2026-06-24 23:41 triggered GPU-discovery on the RTX 5060 Ti (Blackwell sm_120); the bundled CUDA libs probe slower than ollama's discovery timeout, each retry was SIGTERM'd, and after 3–4 rapid failures systemd exhausted `StartLimitBurst` and stopped retrying. Dead 36h. Not a crash — killed by restart protection.
2. **OpenRouter** has no API key on any path (env `OPENROUTER_API_KEY` unset; `web/secrets_store` Fernet store absent — main `.context/secrets/` empty), so `web/llm/manager.py:129` never registers `OpenRouterProvider`. litellm-config.yaml also has zero openrouter routes. With ollama down and no openrouter fallback, every lane fails.

**Why structurally allowed (framework blindness):** Nothing monitors LLM-backend reachability. `fw doctor` has a litellm/ollama check (`test_doctor_litellm_ollama.bats`) but it evidently did not surface this as a blocking signal for 36h, and there is no alert when the *active* search provider goes unreachable. The single-provider default (`provider: ollama`, no auto-fallback) means one dead backend = total outage with no degraded mode.

**Prevention (candidate follow-ups, not done here):** (a) a doctor/audit WARN when the active web/llm provider's `is_available()` is False; (b) ollama CPU-only drop-in as the stable default on Blackwell hosts (Open Q#2 — ollama may never have used the GPU here); (c) an openrouter fallback route so a dead ollama degrades instead of failing. Full plan: `docs/reports/T-2416-llm-integration-diagnosis.md`.

## Recommendation

- **Recommendation:** Diagnosis complete — two independent, **operator-owned** blockers; agent-fixable follow-ups exist but need an API key + a host-service restart first.
- **Operator actions (unblock the search):**
  1. Ollama: `sudo systemctl reset-failed ollama`, add `Environment="CUDA_VISIBLE_DEVICES="` to `/etc/systemd/system/ollama.service.d/lan.conf`, then `sudo systemctl daemon-reload && sudo systemctl start ollama` (CPU-only, stable). OR upgrade ollama for real Blackwell support.
  2. OpenRouter: provide a key via `OPENROUTER_API_KEY` env or the Watchtower Settings/Secrets page → `web/llm` auto-registers the provider on next start.
- **Agent-fixable (offered, gated on a key existing):** add openrouter fallback routes to `.context/litellm-config.yaml` (dispatch lane); optionally refactor `lib/ask.py` to route through a proxy instead of hard-wired `ollama.chat`.
- **Evidence:** `docs/reports/T-2416-llm-integration-diagnosis.md` (full journal reconstruction, GPU hardware probe, per-lane key-path trace, 5-step remediation).

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

## Updates

### 2026-06-26T12:07:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/livefire-t2389/.tasks/active/T-2416-diagnose-ollamaopenrouter-llm-integratio.md
- **Context:** Initial task creation
