---
id: T-1691
name: "v1 Ollama proxy adapter — pick proxy (litellm vs claude-code-router vs claude-bridge) + per-workflow env-redirect plumbing"
description: >
  v1 multi-provider path for the TermLink Worker via ANTHROPIC_BASE_URL env redirect. Per CONTEXT.md (Q11): Claude Code supports endpoint redirection (52 binary refs in claude 2.1.126); workflows declare env: ANTHROPIC_BASE_URL=http://localhost:PORT pointing at a proxy fronting ollama / OpenAI / OpenRouter. Inception decides WHICH proxy ships as default, how it integrates into fw doctor, and validation against a real ollama instance.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: [arc:orchestrator-rethink, multi-provider, ollama]
components: []
related_tasks: [T-1687]
created: 2026-05-02T22:56:02Z
last_update: 2026-05-02T22:56:02Z
date_finished: null
---

# T-1691: v1 Ollama proxy adapter — pick proxy (litellm vs claude-code-router vs claude-bridge) + per-workflow env-redirect plumbing

## Problem Statement

TermLink Worker via `ANTHROPIC_BASE_URL` redirect (Q11) needs a proxy that translates Anthropic protocol → Ollama API. Three candidates surveyed during grilling: **litellm** (`--anthropic_api_format`), **claude-code-router**, **claude-bridge**. This inception picks one for v1 default, validates against the existing ollama instance (192.168.10.107:11434, per MEMORY.md), and documents install + config + `fw doctor` integration. Tool-use translation is the load-bearing requirement — simple completion is easy; round-tripping `Read`/`Edit`/`Bash` calls is where proxies typically fail.

## Assumptions

- A-1: At least one of the three proxies handles Anthropic-protocol → Ollama-API translation correctly for tool-use, not just simple completion.
- A-2: Per-workflow `env: ANTHROPIC_BASE_URL` propagates through `claude -p` (TermLink dispatch path) without leaking into the parent Agent's environment.
- A-3: Working ollama instance at 192.168.10.107:11434 is reachable from the dispatch host (verified in production deployment notes).
- A-4: Latency overhead of the proxy hop is acceptable (<2× raw API call).

## Exploration Plan

- Spike S-1 (1 sess): install + run all three proxies; fire a simple-completion dispatch through each; record install footprint, latency, success.
- Spike S-2 (½ sess): tool-use translation — fire a dispatch that requires Read+Bash via each proxy; record fidelity (does the worker actually use the tools?).
- Spike S-3 (½ sess): env-redirect propagation — verify `ANTHROPIC_BASE_URL` set in workflow `env:` doesn't leak to parent Agent or sibling dispatches.

## Technical Constraints

- Ollama runs on a separate LAN host (192.168.10.107) — proxy must be reachable from the dispatch host or run locally and forward.
- Claude Code's tool-use protocol is Anthropic-flavoured; ollama models speak OpenAI-style. Proxy must translate function-call schemas, not just stream tokens.
- Subprocess env merging in `claude -p` must override `ANTHROPIC_BASE_URL` cleanly (no fallback to parent's value).

## Scope Fence

- IN: proxy selection (one of three); install path documentation; basic config file; `fw doctor` integration to detect "proxy not running" / "ollama not reachable"; validation harness `fw orchestrator test --workflow ollama-research`.
- OUT: native non-proxy adapter (would mean writing Anthropic↔Ollama translation in-framework — too big for v1); multi-model proxy load-balancing; cross-machine proxy hosting (use existing 192.168.10.107); supporting all three proxies (pick one default).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- At least one proxy supports tool-use translation reliably (≥90% success rate on a representative dispatch)
- `env:` redirect propagation works cleanly (no leak to parent or siblings)
- Latency overhead is bounded (proxy round-trip <2× raw API)
- `fw doctor` can detect proxy-not-running and ollama-not-reachable separately

**NO-GO if:**
- All three proxies fail tool-use translation reliably (defer ollama path to v2; ship multi-provider via pi only)
- Env-redirect leakage forces a per-process isolation strategy too complex for v1
- Tool-use schemas can't be round-tripped without lossy translation that degrades worker quality

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
