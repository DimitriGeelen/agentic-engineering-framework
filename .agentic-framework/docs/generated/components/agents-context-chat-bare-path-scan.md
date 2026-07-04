# chat-bare-path-scan

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/chat-bare-path-scan.sh`

## What It Does

Stop hook — chat bare-path scanner (T-2183, Slice 2 of T-2181)
Structural backstop for the bare-path regression class (T-2125 / T-2129 / T-2181):
agents must surface Watchtower handoffs as FULL URLs (http://host/review/T-XXX),
never as bare paths (`/review/T-XXX`) hand-typed into chat output. Slice 1 (T-2182)
shipped the `fw task review-batch` helper that emits correct URLs; this Slice 2 is
defence-in-depth — it catches the regression even when the helper isn't used.
Fires on every Stop event. Reads the just-completed assistant turn from the
transcript, strips code blocks + inline code (where bare paths are legitimate —
the literal regex, doc examples, CLI snippets), then regex-scans markdown
bullet/table-cell contexts for bare Watchtower paths NOT part of an http(s):// URL.

---
*Auto-generated from Component Fabric. Card: `agents-context-chat-bare-path-scan.yaml`*
*Last verified: 2026-06-13*
