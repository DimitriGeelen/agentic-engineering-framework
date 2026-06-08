# T-2256 — OR-2 scan extension draft (T-2209 Slice 1 pre-stage)

## §1 — Context

T-2209 (capability-overlay arc) decided GO 2026-06-05 per `docs/reports/T-2209-cli-mcp-overlay-inception.md` §10. The arc's Slice 1 carries one real build leg: **OR-2** — extend `agents/audit/orchestrator-mcp-scan.sh` so the framework's own MCP server (Slice 2 deliverable) is visible to drift defenses. Without OR-2, the framework's MCP tools would be invisible to the same governance scan that catches T-1641-W10-class drift on `/opt/termlink`, reproducing the original failure mode one repo over.

T-2216 (`docs/reports/T-2216-orchestrator-routing-integration.md` §16) sketches OR-2 as ~15 LoC for `probe_framework_tools()` + a baseline file + a verification block hook. This artefact is the pre-stage: it expands T-2216's sketch into a drop-in-ready draft so the Slice 1 author doesn't re-design at slice-fire time.

**Predecessor artefacts:**
- `docs/reports/T-2209-cli-mcp-overlay-inception.md` §15 + §16 — pre-arc-create survey + dispatch-template pointer
- `docs/reports/T-2216-orchestrator-routing-integration.md` §16 — OR-2 ~40 LoC estimate (verified here in §7)
- `agents/audit/orchestrator-mcp-scan.sh` — the file being extended
- `.context/audits/orchestrator-mcp-baseline.yaml` — the baseline file shape OR-2's new baseline mirrors

**Scope fence:** this artefact is **research only**. No source files under `agents/`, `bin/`, `lib/`, `web/` are modified. The Slice 1 author applies the patch when `fw arc create capability-overlay` fires (still Sovereign-blocked at time of writing).

## §2 — Current scan surface anatomy

`agents/audit/orchestrator-mcp-scan.sh` is two-layered:

- **Bash layer (lines 1-100):** environment setup, baseline file resolution, three probe functions (`probe_via_direct_read`, `probe_tools`, `probe_gate_calls`), and one supplementary probe (`probe_sessions_json` for T-1649 tag-format lint).
- **Python layer (lines 103-413, embedded heredoc):** classification, baseline diff, T-2154 convention auto-classify, YAML report emission.

The probes:

| Function | Returns | Source-code reference | Pattern |
|----------|---------|----------------------|---------|
| `probe_via_direct_read` | 0 if readable | scan.sh:48-53 | filesystem readiness test |
| `probe_tools` | sorted unique tool names | scan.sh:55-67 | grep `name = "termlink_*"` |
| `probe_gate_calls` | tool names with `check_task_governance("termlink_*")` | scan.sh:69-81 | grep gate call sites |
| `probe_sessions_json` | live sessions JSON | scan.sh:92-98 | optional, degrade-silent |

Empty-probe error handling (scan.sh:84-87):

```bash
CURRENT_TOOLS=$(probe_tools)
if [ -z "$CURRENT_TOOLS" ]; then
  echo "ERROR: probe returned empty tool list — TERMLINK_REPO=$TERMLINK_REPO unreachable" >&2
  exit 2
fi
```

**Important:** this hard-error pattern works for `termlink` because the scan only fires when `/opt/termlink` is reachable (either direct or via TermLink remote). For the **framework** leg, hard-error is wrong: the framework MCP server may not be deployed yet (pre-Slice-2), and the scan should still pass cleanly with `framework_current_count: 0`. The draft below uses a soft-empty pattern instead.

## §3 — Proposed `probe_framework_tools()` function

Mirror of `probe_tools` shape, plus soft-empty fallback. ~15 LoC.

```bash
# T-2256 / T-2209 OR-2: probe the framework's own MCP server manifest.
# Sibling to probe_tools above (which scans /opt/termlink). Returns empty
# cleanly when the framework MCP server hasn't shipped yet (pre-Slice-2);
# baseline.yaml's gated.tools=[] keeps the scan passing in that state.
FRAMEWORK_MCP_MANIFEST="${FW_MCP_MANIFEST:-$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json}"

probe_framework_tools() {
  # Manifest location TBD by Slice 2 (OSQ-E). Until then, empty.
  if [ ! -f "$FRAMEWORK_MCP_MANIFEST" ]; then
    return 0
  fi
  python3 -c "import json,sys; m=json.load(open('$FRAMEWORK_MCP_MANIFEST')); [print(t['name']) for t in m.get('tools', [])]" 2>/dev/null | sort -u
}

probe_framework_gate_calls() {
  # Same manifest carries a `gated: true|false` flag per tool (OR-1 contract).
  if [ ! -f "$FRAMEWORK_MCP_MANIFEST" ]; then
    return 0
  fi
  python3 -c "import json,sys; m=json.load(open('$FRAMEWORK_MCP_MANIFEST')); [print(t['name']) for t in m.get('tools', []) if t.get('gated')]" 2>/dev/null | sort -u
}
```

**Decision encoded:** the manifest format is JSON-with-`gated`-flags. Slice 2 ships the manifest; Slice 1's OR-2 leg only reads it. The format-decision belongs to Slice 2 (OSQ-E), so this draft commits to JSON only as a sketch — Slice 1 author finalises after Slice 2's manifest format lands.

**Alternative considered:** scrape the framework MCP server source like `probe_tools` does for `tools.rs`. Rejected because the framework MCP server's language is undetermined (Python vs Go vs Rust — OSQ-E), and the manifest format is the OR-1 contract anyway. Mirror what's already in the design.

## §4 — Proposed `framework-mcp-baseline.yaml` shape

Mirror of `orchestrator-mcp-baseline.yaml`. The draft scaffold lives at `.context/audits/framework-mcp-baseline.yaml.draft` — rename (strip `.draft`) at activation. Initial empty state:

```yaml
baseline_count: 0
gated:
  description: "Mutator tools that already invoke the framework's governance gate."
  tools: []
mutators_ungated:
  description: "Mutator tools that SHOULD gate but currently don't (ratchet target)."
  tools: []
readonly_exempt:
  description: "Read-only / passive tools — governance not required by design."
  tools: []
```

The empty-baseline state is structurally fine: scan diff of `current_tools={}` against `bl_known={}` produces `new_tools_raw=[]`, `removed_tools=[]`, `gate_drop_outs=[]` — exit 0, status `pass`. First populated baseline ships with Slice 2 (when the framework MCP server lands).

**Drift rules are identical** to the orchestrator baseline:
1. Tool listed under `gated` losing its governance call → FAIL
2. Tool in `mutators_ungated` gaining a governance call → WARN (ratchet target)
3. New tool not in any list → WARN, manual classification
4. `gated` count must not drop below `baseline_count`

## §5 — Wiring into the existing scan flow

Three plausible structures:

| Option | Description | LoC delta |
|--------|-------------|-----------|
| **A.** Separate Python invocation per scan target (one for termlink, one for framework) | Cleanest split; each baseline file processed independently; double the report emission | +~80 LoC |
| **B.** Single Python invocation with two baseline files | Reuses one classification engine; framework leg added as parallel branches; tighter report | +~40 LoC |
| **C.** Two scan scripts (current + new framework-mcp-scan.sh) | Maximum isolation; can be cron-scheduled independently; doubled boilerplate | +~150 LoC for new script |

**Recommended:** **Option B (single Python, two baselines)**. Reasons:
1. Hits the T-2216 ~15 LoC bash + ~25 LoC Python target.
2. One report file (`orchestrator-LATEST.yaml`) keeps consumers (audit cron, doctor) reading from one source of truth.
3. The classification engine is identical (set ops on tool name sets vs baseline categories); duplication would be wasteful.
4. T-2154's convention auto-classifier extends naturally — see §6.

Option C buys isolation at the cost of audit-cron complication (two cron entries, two doctor sections, two LATEST files). Reject unless Slice 1 design surfaces a genuine reason.

**Bash-layer wiring** at scan.sh:34 (right before `BASELINE=` assignment):

```bash
FRAMEWORK_BASELINE="$FRAMEWORK_ROOT/.context/audits/framework-mcp-baseline.yaml"
```

At scan.sh:83-87 (replace the existing CURRENT_TOOLS-or-error hard-bail):

```bash
CURRENT_TOOLS=$(probe_tools)
CURRENT_FRAMEWORK_TOOLS=$(probe_framework_tools)
# Hard-error only when BOTH probes return empty — that genuinely indicates
# misconfiguration (no termlink reach AND no framework MCP manifest). When
# only the framework probe is empty, that's normal pre-Slice-2 state.
if [ -z "$CURRENT_TOOLS" ] && [ -z "$CURRENT_FRAMEWORK_TOOLS" ]; then
  echo "ERROR: both probes empty — TERMLINK_REPO=$TERMLINK_REPO unreachable AND FRAMEWORK_MCP_MANIFEST=$FRAMEWORK_MCP_MANIFEST absent" >&2
  exit 2
fi
CURRENT_GATED=$(probe_gate_calls)
CURRENT_FRAMEWORK_GATED=$(probe_framework_gate_calls)
```

**Python-layer wiring** at scan.sh:102 (extend `export` list):

```bash
export CURRENT_TOOLS CURRENT_GATED BASELINE LATEST SESSIONS_JSON APPLY_MODE \
       CURRENT_FRAMEWORK_TOOLS CURRENT_FRAMEWORK_GATED FRAMEWORK_BASELINE
```

Inside the Python heredoc, after the existing baseline load (scan.sh:226-232), add a parallel framework-baseline branch that reuses the same `bl_known` / `gate_drop_outs` / `ratchet_candidates` set ops. Emit findings under a new key `framework_findings:` in the YAML report so downstream consumers (doctor, audit cron) can read both legs without parsing changes.

## §6 — Convention-classifier reuse decision

T-2154's `classify_by_convention()` (scan.sh:131-160) auto-classifies new `termlink_agent_*` / `termlink_channel_*` tools by the action-verb-suffix convention. Does it extend to `mcp__framework__*`?

**Argument FOR extending:**
- The verb whitelist (post/send/edit/react/pin/quote/redact/reply/star/ack/forward/reauth/poll_start/poll_end/poll_vote/typing_emit) is semantically about *write actions*, not termlink-specific.
- Reusing the classifier preserves the 7-batch zero-misclassification track record.

**Argument AGAINST extending:**
- Framework verb shape is `fw <verb> <args>` (e.g. `task_update`, `work_on`, `context_focus`). These don't follow the `<namespace>_<verb-suffix>` pattern the classifier expects.
- Verbs like `task_update`, `work_on`, `inception_start` are mutators by intent, but `update`, `on`, `start` are not in the current whitelist.
- The framework's verb vocabulary is different enough that a separate whitelist (or no auto-classification) is the safer call.

**Recommended:** **separate path — no auto-classification on framework leg**, at least initially. Slice 2 ships the framework MCP server with a manifest that explicitly carries `gated: true|false` per tool (per OR-1). The manifest is the source of truth, not heuristic classification.

The convention classifier can be retrofitted later if a third scan target ever needs it (e.g. a third-party MCP server in a consumer project). T-1761's "bounded blast radius" discipline applies.

**Decision encoded:** `classify_by_convention(name)` returns `'unknown'` for any name not starting with `termlink_agent_` or `termlink_channel_` (scan.sh:147-148). That behaviour is correct for `mcp__framework__*` — they get manual review by default, which is appropriate while the framework MCP surface is still designed.

## §7 — LoC budget validation

T-2216 §16 estimated **~15 LoC**. Let me total the additions in this draft:

| Block | Lines |
|-------|-------|
| `FRAMEWORK_MCP_MANIFEST` env-var assignment | 1 |
| `probe_framework_tools()` body | 5 |
| `probe_framework_gate_calls()` body | 5 |
| `FRAMEWORK_BASELINE` assignment | 1 |
| Bash hard-error refactor (replace 4 lines with 8) | +4 |
| Python `export` extension | 1 |
| Python parallel baseline branch (mirror existing set-ops) | ~20 |
| Python report `framework_findings:` key addition | ~5 |
| **Bash total** | **~17 LoC** |
| **Python total** | **~25 LoC** |
| **Combined** | **~42 LoC** |

T-2216's "~15 LoC" was specifically the new bash function (`probe_framework_tools()` ≈ 15 LoC). The full integration is ~42 LoC across both layers. Still well within Slice 1's scope — Slice 1's main work is `fw --json` extension across 16 verbs + `schema_version` field, of which ~42 LoC of audit-scan extension is a side-pocket leg.

**Re-confirms T-2216's verdict:** OR-2 is one real build leg in Slice 1, not a separate slice.

## §8 — Edge cases (mandatory enumeration)

The Slice 1 author must handle these three cases at minimum:

### EC-1: Framework MCP server not yet deployed

**State:** `$FRAMEWORK_MCP_MANIFEST` file doesn't exist (Slice 1 ships before Slice 2).

**Expected behaviour:** `probe_framework_tools()` returns empty (exit 0). Diff against empty baseline produces no findings. Scan exits 0 / status `pass`. No FAIL, no WARN.

**Anti-pattern to avoid:** treating absent manifest as an error (existing `probe_tools` pattern). The framework leg must degrade silently when the server isn't there.

### EC-2: Cross-host scan via TermLink remote

**State:** scan runs on a host where the framework repo is mounted (so manifest is readable) but the framework MCP server is running on a different host. OR: scan runs in a context where `$FRAMEWORK_ROOT` resolves to a vendored consumer (`.agentic-framework/`) and the manifest isn't co-located.

**Expected behaviour:** path resolution via `FW_MCP_MANIFEST` env-var with sensible default (`$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json`). Operators can override via env-var for cross-host scenarios (mirror of `FW_TERMLINK_REPO` pattern at scan.sh:37).

**Anti-pattern to avoid:** hard-coded path that doesn't honour `$FRAMEWORK_ROOT` (would silently miss the manifest on every consumer project).

### EC-3: Baseline file absent on first run

**State:** `framework-mcp-baseline.yaml` doesn't exist (Slice 1 ships, but operator hasn't renamed `.draft` yet).

**Expected behaviour:** existing pattern at scan.sh:40-44 (hard-bail with explicit error message). Slice 1 close-gate verifies the file exists in `## Verification`.

**Anti-pattern to avoid:** silently treating absent baseline as empty (would mask real misconfiguration where someone deleted the baseline).

## §9 — Verification block addition (per OR-6)

Slice 1's `## Verification` adds:

```bash
# OR-2: framework MCP scan extension exercises clean on this slice
bin/fw audit | grep -q "framework-mcp.*PASS"
```

Note: in this draft the scan emits findings under `framework_findings:` in `orchestrator-LATEST.yaml`. The `fw audit` invocation aggregates and surfaces a `framework-mcp` line in its summary. Slice 1 author may need to extend `bin/fw audit`'s summary formatter to emit a `framework-mcp` line — see audit.sh's existing `orchestrator-mcp-scan` summary line for the pattern to mirror.

## §10 — Rejected paths

- **Option C (separate scan script `framework-mcp-scan.sh`)** — rejected per §5 analysis; ~150 LoC overhead for isolation we don't yet need.
- **Verb-convention reuse on `mcp__framework__*`** — rejected per §6; framework verb shape doesn't match the termlink convention.
- **Auto-classification on framework leg** — rejected per §6; Slice 2's manifest format already carries `gated: true|false`, so heuristic classification is redundant.
- **Hard-coded JSON manifest format** — partially rejected; this draft commits to JSON for the sketch but explicitly defers final format decision to Slice 2 design. Slice 1 author updates the parser when Slice 2's format lands.

## §11 — Open questions

- **OQ-1:** Does T-2154's `--apply` auto-classify mode extend to framework leg? Likely no (§6 decision). But Slice 1 design should explicitly answer: does the framework leg need an apply-mode at all, or is manual baseline update sufficient at the scale of ~10-30 framework tools (vs hundreds for termlink)?
  - resolution_path: Slice 1 design call. Author defaults to NO unless tool count grows.
- **OQ-2:** Should `mcp__framework__*` tools be cross-referenced against `fw` CLI verbs to detect drift between the MCP surface and the underlying CLI? E.g. if `fw task update` exists but `mcp__framework__task_update` doesn't, that's a coverage gap.
  - resolution_path: deferred — this is a higher-level governance check (coverage scan, not drift scan). Could be a separate audit (`fw audit coverage-scan`) in a future slice.

## §12 — Operational consequences

**Pre-Slice-1 (now):** This artefact + draft scaffold land. No source files modified. Slice 1 author has a drop-in starting point.

**Post-Slice-1, Pre-Slice-2:** Scan extension ships. `probe_framework_tools()` returns empty (manifest absent). Scan still exits 0 / status `pass`. Operator running `bin/fw audit` sees `framework-mcp: PASS (0 tools)` confirming the extension is wired but inactive.

**Post-Slice-2:** Slice 2 ships the framework MCP server + manifest. Operator promotes `.draft` baseline to active. Next scan cycle picks up the populated manifest. Drift defenses now cover both `termlink_*` and `mcp__framework__*` surfaces.

## §13 — Cross-references

- `agents/audit/orchestrator-mcp-scan.sh` — file extended in Slice 1
- `.context/audits/orchestrator-mcp-baseline.yaml` — shape mirrored
- `.context/audits/framework-mcp-baseline.yaml.draft` — drop-in scaffold (T-2256 deliverable)
- `docs/reports/T-2209-cli-mcp-overlay-inception.md` §15-§16 — pre-arc-create survey + Slice 1 readiness
- `docs/reports/T-2216-orchestrator-routing-integration.md` §16 — original OR-2 sketch (~15 LoC)
- `docs/dispatch-templates/iw-slice-worker.md` — dispatch template Slice 1 author uses
- `agents/audit/audit.sh` — `fw audit` aggregator; Slice 1 author extends its summary formatter

## §14 — Provenance

```
session_started: 2026-06-08T11:35:00Z
session_concluded: 2026-06-08T11:55:00Z
agent_model: claude-opus-4-7
fw_version: 1.6.9
predecessors:
  - T-2209: capability-overlay arc inception (GO 2026-06-05)
  - T-2215: CLI error survey verdict (B-vs-C empirical lens)
  - T-2216: orchestrator-routing integration verdict (OR-2 ~15 LoC estimate)
  - T-2253: bundle ↔ CLAUDE.md §Arc-Scoped cross-link
followup:
  - capability-overlay arc Slice 1 build task — applies this draft as one of its build legs
```
