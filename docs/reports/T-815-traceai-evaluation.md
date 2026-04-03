# T-815: traceAI Evaluation — OpenTelemetry AI Observability

## Research Question

How does traceAI (github.com/future-agi/traceAI) stack against our 4 constitutional directives? Is there value in adopting patterns, integrating, or learning from their approach?

## Directives Under Evaluation

1. **D1 Antifragility** — System strengthens under stress; failures are learning events
2. **D2 Reliability** — Predictable, observable, auditable execution; no silent failures
3. **D3 Usability** — Joy to use/extend/debug; sensible defaults; actionable errors
4. **D4 Portability** — No provider/language/environment lock-in; prefer standards

## Repo Facts

- **Stars:** 109 | **Forks:** 15 | **License:** MIT
- **Language:** Python (primary), TypeScript, Java, C#
- **Created:** 2025-04-15 | **Last push:** 2026-03-17
- **Test files:** 209 | **Open issues:** 2
- **Size:** 9.3MB across 4 language implementations
- **50+ framework integrations** as separate packages

---

## D1: Antifragility — "System strengthens under stress; failures are learning events"

**Score: WEAK**

**What they do well:**
- Import failures degrade gracefully (`Protect = None` with warning, not crash)
- Span creation failure falls back to `INVALID_SPAN` — tracing can't kill the app
- Optional dependencies are truly optional

**What's missing:**
- **No learning from failures.** Errors are caught and logged, but there's no feedback loop. A failed span export doesn't inform future behavior.
- **No healing patterns.** If the observability backend goes down, traceAI doesn't adapt — it just silently drops data.
- **No failure classification.** All errors are treated the same: catch, log, continue. No escalation ladder, no pattern recognition.
- **Sampling strategies are on the roadmap** — meaning high-volume production environments can overwhelm the system today.

**Our framework comparison:** We classify failures (code/dependency/environment/design/external), record patterns, and use them to prevent recurrence. traceAI survives failures but doesn't learn from them.

**Learnable pattern:** Their `INVALID_SPAN` fallback is elegant — a null object pattern that prevents cascading failures. Our hooks could benefit from similar null-object fallbacks when external tools fail.

---

## D2: Reliability — "Predictable, observable, auditable execution; no silent failures"

**Score: MIXED**

**What they do well:**
- OpenTelemetry spans create a complete execution trace — every LLM call, tool invocation, and retrieval is captured with timestamps, token counts, and model parameters
- Application errors are recorded on spans with status codes and stack traces:
  ```python
  span.set_status(trace_api.Status(trace_api.StatusCode.ERROR, str(exception)))
  span.record_exception(exception)
  raise  # re-raises — doesn't swallow
  ```
- Semantic attributes are comprehensive: model, tokens, prompts, tool calls, latency
- `suppress_tracing()` context manager gives explicit control over when tracing is active

**What's missing:**
- **Tracing failures ARE silent.** If span creation fails, a warning is printed to stdout (`print(f"Error creating span: {e}")`) — not logged, not recorded, not alerted. This violates "no silent failures."
- **No audit trail of tracing itself.** You can't answer "did all my spans actually export?" or "how many were dropped?"
- **No verification gate.** There's no way to assert that tracing is working correctly before deploying.

**Our framework comparison:** We audit everything — every gate decision, every bypass, every failure. traceAI observes the application but doesn't observe itself.

**Learnable pattern:** Their semantic conventions for AI operations (model name, token counts, prompt content, tool calls) are well-designed. If we ever emit structured events from `fw costs` or hooks, adopting these attribute names would give us OTel compatibility for free.

---

## D3: Usability — "Joy to use/extend/debug; sensible defaults; actionable errors"

**Score: STRONG**

**What they do well:**
- **3-line setup:**
  ```python
  register(project_name="my-app")
  AnthropicInstrumentor().instrument()
  # ... use Anthropic normally, tracing happens automatically
  ```
- **TraceConfig with 3-tier defaults:** explicit arg > env var > sensible default. All defaults maximize observability (nothing hidden unless you ask).
- **Privacy-first configuration:** `hide_inputs`, `hide_outputs`, `pii_redaction` — all accessible via env vars (`FI_HIDE_INPUTS=true`), no code changes needed for compliance.
- **Per-package instrumentors:** You only install what you use. `pip install traceai-anthropic` — no bloated monolith.
- **Uninstrument support:** Every instrumentor can be cleanly removed at runtime (stores original method references for restoration).

**What's missing:**
- **Error messages are poor.** `print(f"Error creating span: {e}")` is not actionable. No suggestion of what to do, no link to docs.
- **Documentation gaps:** No testing patterns documented. No troubleshooting guide.

**Our framework comparison:** We have stronger error messages (actionable, with next steps) but weaker defaults story. Their env-var config pattern is something we could adopt — our hooks use hardcoded paths where env vars would give operators control without code changes.

**Learnable pattern:** The 3-tier config resolution (explicit > env var > default) is clean and production-friendly. Our `TraceConfig` equivalent could be `FW_BUDGET_THRESHOLD`, `FW_HANDOVER_AUTO`, etc.

---

## D4: Portability — "No provider/language/environment lock-in; prefer standards"

**Score: EXCELLENT**

**What they do well:**
- **OpenTelemetry is THE standard.** By building on OTel, traces work with any compatible backend: Datadog, Grafana Tempo, Jaeger, Honeycomb, AWS X-Ray — zero code changes.
- **4 language implementations:** Python, TypeScript, Java, C# — same concepts, same semantic conventions.
- **50+ provider integrations** via separate packages. Adding a new provider doesn't touch core.
- **No proprietary wire format.** Everything is standard OTel spans with standard attributes.
- **Provider-agnostic core:** `fi_instrumentation` handles span lifecycle; provider packages only add provider-specific attributes. Clean separation.

**What's missing:**
- **FutureAGI platform coupling:** The `register()` function and some features point to their commercial platform. The open-source version works without it, but the default path nudges toward their SaaS.

**Our framework comparison:** We share the same principle (D4) but execute differently. We prefer file-based standards (YAML, Markdown, shell) over wire protocols. Their OTel approach is more industry-standard for runtime data; our approach is more portable for governance data (works without any infrastructure).

**Learnable pattern:** Their plugin architecture — separate packages per provider, common core — is exactly what our `fw` could adopt for multi-agent-provider support. A `fw-provider-claude` package alongside `fw-provider-openai` would keep the core portable while supporting provider-specific features.

---

## Summary Scorecard

| Directive | traceAI | Evidence |
|-----------|---------|----------|
| D1 Antifragility | **Weak** | Survives failures but doesn't learn. No healing loop. |
| D2 Reliability | **Mixed** | Excellent app observability, but tracing failures are silent. |
| D3 Usability | **Strong** | 3-line setup, env-var config, privacy controls. |
| D4 Portability | **Excellent** | OTel-native, 4 languages, 50+ providers, no lock-in. |

## Patterns Worth Adopting

1. **Null object fallback** (`INVALID_SPAN`) — prevent cascading failures in hooks
2. **3-tier config resolution** (explicit > env var > default) — for framework settings
3. **Semantic conventions for AI ops** — if we ever emit structured telemetry
4. **Per-provider plugin packages** — for multi-agent-provider support
5. **Privacy-by-config** (env var redaction controls) — for sensitive project data

## Recommendation

**NO-GO on integration** — traceAI solves runtime telemetry, which our `fw costs` already covers at the level we need (JSONL parsing). Their OTel approach is overkill for our bash/file-based architecture.

**GO on pattern adoption** — Items 1-2 above (null object fallback, 3-tier config) are directly applicable to our framework with zero dependency on traceAI.

## Dialogue Log

### Exchange 1 — Initial look
- **User asked:** "please have a look at this [traceAI URL]"
- **Agent provided:** High-level summary — what it is, features, comparison table
- **Outcome:** User wants deeper investigation against 4 directives

### Exchange 2 — Governance correction
- **User asked:** "investigate further, how does it stack against our 4 directives"
- **Agent error:** Launched research agent WITHOUT creating a task first
- **User correction:** "err agent ??!!!! FRAMEWORK GOVERNANCE !!!!!!"
- **Lesson:** Even research/exploration requires a task. No exceptions.
