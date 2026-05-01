# T-1641 W02 — Review-Feedback Mining

Source: `docs/reports/T-1061-termlink-review-feedback.md` (Claude Code @ /opt/termlink, 2026-04-07).

## Summary

Review pushed back on PTY-byte-stream parsing and offered 5 phases. All mapped 1:1 to T-1062–T-1066; the "Never" item (pre-hook PTY buffer hold) was correctly left untasked. But 5 technical-nuance observations + 1 sub-agent-governance correction were absorbed as background, never tasked. Top miss: **W4 — sub-agent `/tmp/` writes bypass PTY, so TermLink cannot solve G-015** — never reconciled, yet T-1061 was framed partly on G-015. The artefact's risks (VT-emulation creep, Claude-Code-format coupling, "deterministic" misframing) have no defending audit/test/monitor.

## All observations

| # | Observation | Tasked? | Why it matters |
|---|---|---|---|
| A1–A3 | PTY ownership / hub visibility / event bus alignments | n/a | confirmations |
| A4 | MCP server is agent-agnostic surface | T-1063 | chosen integration point |
| A5 | `orchestrator.route` proto-routing exists | T-1064 | extension not greenfield |
| A6 | T-577 orphan-process gap | T-577 (done) | pre-existing |
| W1 | PTY does NOT parse byte stream — ANSI parsing = half a terminal emulator | partial: T-1066 recalibrated post-hoc | scope guard; if lost, T-1066 drifts into VT emulation |
| W2 | "Buffer/pause stream" deadlocks the child | **None (correct)** | future agent could try and hit deadlock |
| W3 | Pre-hook blocking needs proxy-PTY MITM | **None (correct)** | same as W2 |
| W4 | Sub-agent `/tmp/*.md` writes bypass PTY — TermLink cannot solve G-015 | **NONE** | contradicts T-1061's G-015 framing |
| W5 | Multi-LLM routing ≠ session routing | T-1064+T-1065 | clean split |
| N1 | Control / data plane separation per-feature | T-1066 implicit | never made AC-explicit |
| N2 | Not all sessions are PTY-backed (`pty: Option<…>`) | **NONE** | T-1063/T-1064/T-1065 silently assume PTY |
| N3 | Bypass / route-cache / circuit-breaker stack with tunable thresholds | partial: T-1064 extends, but `PROMOTION_THRESHOLD=5`, denylist, breaker tunables never surfaced | overlaps W08 |
| N4 | Scrollback is archival, not analytical | partial: T-1066 post-hoc | analytics foundation missing |
| N5 | `pty interact` 200ms polling edge cases | **NONE** | closest "output analysis" is a documented hack |
| R1 | Risk: scope creep into terminal emulation | **NONE** | nothing prevents re-litigation |
| R2 | Risk: coupling to Claude Code output format (D4) | **NONE** | format change → silent rot |
| R3 | Risk: "deterministic" framing of heuristic parsing | **NONE** | language hygiene gap reappears in child ACs |
| R4 | Risk: opportunity cost vs orchestrator/dispatch | partial: phase ordering | no kill-switch if Phase 4 stalls |
| P1 | Phase 1 — WezTerm chrome via RPC | T-1062 | direct |
| P2 | Phase 2 — extend `orchestrator.route` task/model-aware | T-1064 | direct |
| P3 | Phase 3 — MCP-level governance | T-1063 | direct |
| P4 | Phase 4 — data-plane governance subscriber (post-hoc) | T-1066 | direct |
| P5 | "Never" — PTY buffer-hold blocking | **None (correct)** | prohibition only in this artefact |
| P6 | Extend dispatch with task-awareness (worker→task, hub completion tracking) | partial in T-1064/T-1065; **no standalone** | 2–4 wk evolution lost as discrete item |

## Lost observations — proposed follow-ups (`from-T-1641`)

1. **W4 — sub-agent `/tmp/` bypass.** Remove G-015 from T-1061's stated benefits, OR open a non-TermLink workstream (FUSE / namespace / hook-side) to govern sub-agent file writes. Decision-only inception, ~1 session.
2. **N2 — non-PTY sessions in governance paths.** Audit T-1063/T-1064/T-1065 for `pty.is_some()` assumptions; test endpoint-only behaviour. Build, 1–2 days.
3. **N3 — routing-rule parameters unconsulted.** Enumerate every threshold (`PROMOTION_THRESHOLD=5`, route-cache TTL, breaker 3-fail/60s, denylist, fallback order); surface as `fw config` + Watchtower review. Overlaps W08. Inception→build, ~1 wk.
4. **N5 — `pty interact` polling edge cases.** Regression tests for raw-mode, marker eviction, scrollback overflow. Test, ~3 days.
5. **R1/R2/R3 — drift defenses** (overlaps W10). Lint flagging new VT state tracking; portability test against output-format change; CLAUDE.md ban on "deterministic" framing of heuristic parsing. Build, ~1 wk.
6. **P6 — task-aware dispatch.** Each worker carries task assignment + completion-via-events. Build, 2–4 wk.
7. **N4 — scrollback analytical layer.** Structured line-index + timestamp extraction. Inception (overlap with T-1066) first.

## Cross-reference notes

- 5 phases → 5 child tasks 1:1, all created 2026-04-08, no horizon staggering — sequencing lost.
- T-1065 covers the half of W5 the review flagged missing (model-routing intelligence); W08 should confirm.
- No child task references W4, N2, N3-as-policy, N5, R1, R2, R3, P6, or N4 — W02's primary deliverables for the aggregator.
