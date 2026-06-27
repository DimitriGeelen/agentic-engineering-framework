---
id: T-2417
name: "remediate LLM integration: OpenRouter fallback routes + route fw ask through litellm proxy"
description: >
  remediate LLM integration: OpenRouter fallback routes + route fw ask through litellm proxy

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/task-create/update-task.sh, bin/fw, lib/ask.py, lib/review.sh]
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
created: 2026-06-27T06:28:55Z
last_update: 2026-06-27T06:47:14Z
date_finished: 2026-06-27T06:47:14Z
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

# T-2417: remediate LLM integration: OpenRouter fallback routes + route fw ask through litellm proxy

## Context

Operator-approved follow-up to T-2416 diagnosis. Two AGENT-FIXABLE changes:
(A) add OpenRouter fallback routes to `.context/litellm-config.yaml` so ollama
aliases fail over to a cloud model when ollama errors; (B) route `lib/ask.py`
through the litellm proxy (was hard-wired `import ollama; ollama.chat`) so it
inherits ollama-primary + openrouter-fallback routing, with graceful degradation
to direct-ollama if the proxy is down. Both INERT for OpenRouter until the
operator sets `OPENROUTER_API_KEY`. Diagnosis: docs/reports/T-2416-llm-integration-diagnosis.md.

## Acceptance Criteria

### Agent
- [x] `.context/litellm-config.yaml` parses (yaml.safe_load) and adds, for each ollama-backed alias, an `-openrouter` sibling alias with `api_key: "os.environ/OPENROUTER_API_KEY"` routing to an `openrouter/...` model
- [x] `.context/litellm-config.yaml` declares `litellm_settings.fallbacks` mapping each primary ollama alias → its `-openrouter` sibling
- [x] `.context/litellm-config.yaml` resolves the raw model name `fw ask` uses (`qwen3:14b` and `dolphin-llama3:8b`) as a proxy alias with an openrouter fallback, so ask.py routes without a 400
- [x] `lib/ask.py` calls the litellm proxy (`http://localhost:4000/v1`, key from `general_settings.master_key`) as primary, falling back to direct `ollama.chat` when the proxy is unreachable; public CLI output unchanged
- [x] Hermetic tests pass: config-shape test + ask.py proxy/fallback test (mocked, no live calls); `python3 -c "import ast; ast.parse(...)"` on ask.py

<!-- No Human ACs: all deliverables are config + Python, agent-verifiable via
     yaml.safe_load, mocked unit tests, and ast.parse. Not a render surface. -->

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

python3 -c "import yaml; d=yaml.safe_load(open('.context/litellm-config.yaml')); names=[m['model_name'] for m in d['model_list']]; assert any(n.endswith('-openrouter') for n in names), 'no openrouter sibling'; assert 'qwen3:14b' in names, 'no raw qwen3 alias'; assert d.get('litellm_settings',{}).get('fallbacks'), 'no fallbacks'; print('config OK')"
python3 -c "import ast; ast.parse(open('lib/ask.py').read()); print('ask.py parses')"
python3 -m pytest tests/unit/test_ask_proxy_routing.py -q 2>&1 | tail -5
## RCA

**Symptom (from T-2416):** Watchtower search + `fw ask` had no OpenRouter
failover; `fw ask` was hard-wired to direct ollama, so an ollama outage broke
it with no cloud fallback path even when an OpenRouter key was available.

**Root cause:** (1) the litellm proxy config had zero openrouter routes/fallbacks;
(2) `lib/ask.py` bypassed the proxy entirely (`import ollama; ollama.chat`), so it
could never inherit any routing/fallback the proxy provided; (3) the proxy's
alias namespace was `claude-*` impersonation names for `claude -p`, with no alias
for the raw model names `fw ask` selects (`qwen3:14b`).

**Why structurally allowed:** the proxy and `fw ask` evolved independently — the
proxy was built for `claude -p` impersonation, `fw ask` predates it (T-264). No
gate connects "we run a routing proxy" to "all LLM consumers route through it".

**Prevention:** `tests/unit/test_ask_proxy_routing.py` pins both the config shape
(openrouter siblings + fallbacks + raw-name aliases all resolvable) and ask.py's
proxy-primary/direct-fallback behaviour. A future drift (removing the fallbacks or
re-hard-wiring ask.py) now fails a unit test.

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

### 2026-06-27 — proxy-primary with non-silent direct-ollama fallback
- **Chose:** `fw ask` calls the litellm proxy first; on ANY proxy exception it
  prints a stderr warning and falls back to direct `ollama.chat`. Escape hatch
  `FW_ASK_NO_PROXY=1` forces the legacy direct path.
- **Why:** the proxy gives ollama→openrouter failover, but `fw ask` (healing,
  briefing, precedent mining) must never hard-break if litellm is down. Non-silent
  fallback respects "never silently work around errors" (CLAUDE.md).
- **Rejected:** proxy-only (breaks `fw ask` when litellm down); opt-in env flag
  default-off (operator approved routing through the proxy, so default-on).

### 2026-06-27 — thinking mode via extra_body, best-effort in proxy mode
- **Chose:** pass ollama's `think` through `extra_body={"think": ...}`; read
  `reasoning_content` back if litellm surfaces it, else "". The direct-ollama
  fallback preserves full `think` + `response.message.thinking`.
- **Why:** `think` is ollama-specific; litellm `drop_params: true` drops it
  cleanly when unsupported. The answer content (what `fw ask` prints) is
  unaffected; separate thinking text is secondary and only shown in `--json`.
- **Rejected:** adding raw-name aliases without `drop_params` handling (risks
  proxy 400s on the ollama backend).

### 2026-06-27 — live `fw ask` validation deferred to post-merge
- **Chose:** ship on hermetic tests + direct proxy probes; do NOT restart the
  live proxy from this worktree.
- **Why:** the live litellm proxy runs from the MAIN checkout (relative-path
  config), so it serves main's config — the new `qwen3:14b` raw alias only
  resolves after merge-back + proxy restart. Additionally `rag_retrieve`
  (embeddings cold-start) hangs in this worktree, upstream of and unrelated to
  this change. Full end-to-end `fw ask` is therefore a post-merge verification.
- **Rejected:** restarting the live proxy (would disrupt other sessions; brief
  forbade it).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-27T06:28:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/livefire-t2389/.tasks/active/T-2417-remediate-llm-integration-openrouter-fal.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e8629a96
- **Timestamp:** 2026-06-27T06:47:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-27T06:47:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
