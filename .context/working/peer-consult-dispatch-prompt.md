# Cross-repo coordination: v2 peer-consult seam (TermLink-side response)

You are a TermLink-side agent. The framework agent (in /opt/999-Agentic-Engineering-Framework) needs your concurrence on a transport-vs-semantics seam before either repo ships v2 peer-consult code.

## Background (read first)

1. Read /opt/999-Agentic-Engineering-Framework/.tasks/completed/T-1804-cross-agent-conversation-arc--joint-aef-.md — the framework-side inception that proposed the seam and shipped GO.
2. Skim /opt/999-Agentic-Engineering-Framework/.tasks/completed/T-1797-termlink-worker-primitive-libtermlinkworker.md for context on what's already shipped framework-side.
3. Read the canonical agent guide for TermLink at your project root (CLAUDE.md, AGENTS.md, or README).

## The seam to evaluate

- **TermLink owns** transport: channels, events, delivery, inbox, **wakeup signal**.
- **AEF (framework) owns** semantics: when to consult, task-context anchoring, conversation audit, spawn-on-event bridge.

## The wakeup question

T-1804 identified three options for waking a non-running responder agent:
- **(i)** TermLink-side hook — TermLink fires $WAKEUP_CMD on undeliverable message
- **(ii)** AEF-side daemon — long-lived TermLink subscriber per host
- **(iii)** Cron+inbox — pickup pattern with periodic poll

The framework-side GO recommendation prefers (i) — a bounded TermLink-side change (≤1 new event class or hook). (ii) is rejected as design smell. (iii) is the existing fallback.

## What to deliver

Write your response to a file under your project's docs/reports/ directory named v2-peer-consult-seam-response.md (e.g., docs/reports/v2-peer-consult-seam-response.md).

Include:
1. **Seam acknowledgement** — do you agree TermLink owns transport-only and AEF owns semantics? If not, where do you want the boundary?
2. **Wakeup choice** — (i) / (ii) / (iii), with TermLink-side rationale. If (i), sketch the proposed event/hook surface in concrete terms (≤1 new event class).
3. **Bounded cost estimate** — what would TermLink-side need to ship for the chosen option? (Aim: ≤1 new event class, ≤1 hook config field, ≤1 new CLI verb.)
4. **Constraints / vetoes** — any TermLink-side reasons the proposed seam doesn't work that the framework agent missed.
5. **Cross-machine question** — TermLink hub is per-machine; cross-machine routing goes through termlink remote. Does (i) work across machines, or only single-host?

## Important

- Do NOT write code. This is a coordination artifact, not a build task.
- Do NOT modify files outside your project root.
- If TermLink has its own task system, file an inception task for the response (mirror of T-1804). If not, just write the artifact.
- Keep the response under 600 lines.

## Final reply format (≤5 lines)

  DONE
  docs/reports/v2-peer-consult-seam-response.md
  One-sentence summary: seam OK + wakeup choice / NOT OK + reason
  Key numbers: e.g., "(i) chosen | new event class: peer.consult.miss | new hook: pty-on-undeliverable"
