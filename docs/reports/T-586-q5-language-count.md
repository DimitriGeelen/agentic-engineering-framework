# T-586 Q5: Language Count — Is bash+Python+TS Actually 3 Languages?

## Question

The Go/No-Go criterion says 3 languages (bash+Python+TS) is a NO-GO.
The proposal: TS replaces Python in core, Watchtower stays Python but is optional.
Does "optional Python for Watchtower" count as 2 or 3 languages?

## Evidence: Python in Core fw Commands

Counted every `python3` invocation across framework core (excluding `web/` and tests):

| File | python3 calls | What they do |
|------|--------------|--------------|
| `bin/fw` | 35 | YAML/JSON parse, task list/show/verify, metrics, promote, search |
| `agents/audit/audit.sh` | 21 | YAML parse, drift check, directive scoring, metrics |
| `agents/handover/handover.sh` | 7 | YAML parse, task summary generation |
| `agents/context/check-active-task.sh` | 3 | JSON parse (tool input), YAML read (focus.yaml) |
| `agents/context/check-tier0.sh` | 3 | JSON parse (tool input), regex matching |
| `agents/context/budget-gate.sh` | 2 | JSON parse (tool input + status file) |
| `agents/context/checkpoint.sh` | 2 | JSON parse (transcript token counting) |
| `agents/task-create/create-task.sh` | 2 | YAML parse (next ID, tag append) |
| `agents/task-create/update-task.sh` | 2 | YAML parse (verification, episodic) |
| `agents/resume/resume.sh` | 3 | YAML parse (discoveries, session) |
| `agents/context/lib/focus.sh` | 3 | YAML read/write focus.yaml, memory-recall |
| `lib/bus.sh` | 9 | JSON envelope handling |
| `lib/inception.sh` | 2 | YAML parse, decision recording |
| `lib/assumption.sh` | 4 | YAML read/write assumptions |
| `lib/harvest.sh` | 1 | YAML parse |
| Claude Code hooks (6 files) | 8 | JSON parse tool_input from stdin |

**Total: ~107 python3 invocations across core framework. Zero core commands work without Python.**

### Standalone Python Files in Core (not Watchtower)
- `agents/context/consolidate.py` — context consolidation
- `agents/context/lib/memory-recall.py` — memory recall
- `agents/fabric/lib/enrich.py` — component card enrichment
- `agents/docgen/generate_article.py` — article generation
- `agents/docgen/generate_component.py` — component doc generation
- `lib/ask.py` — LLM query interface
- `agents/capture/read-transcript.py` — transcript extraction

## What Python Actually Does in Core

Three categories, by frequency:

1. **YAML parsing** (~60%): Read/write `.yaml` files. Bash has no YAML parser; `import yaml` is everywhere.
2. **JSON parsing** (~30%): Parse Claude Code hook stdin, status files, API responses. Bash `jq` could replace these but isn't used.
3. **Business logic** (~10%): Task listing with filters, directive scoring, metrics prediction, memory recall.

## Can Core Work Without Python If TS Binary Replaces It?

**No, not as a simple substitution.** The Python is not a single binary — it's 107 inline heredocs and one-liners embedded throughout 20+ bash scripts. A TS replacement would need to either:

- (a) Provide a single binary with 15+ subcommands (`fw-core yaml-read`, `fw-core json-parse`, `fw-core task-list`, etc.)
- (b) Rewrite all 20+ bash scripts to call `node` instead of `python3` (same problem, different runtime)
- (c) Replace bash scripts entirely with TS (then it's TS+Python, not bash+TS+Python)

## Precedent: Multi-Language Projects

| Project | Languages | Counted as |
|---------|-----------|------------|
| Go backend + React frontend | Go + TS/JS | 2 (different layers) |
| Rails + JS frontend | Ruby + JS | 2 (different layers) |
| Django + React + Celery | Python + TS | 2 (same core runtime) |
| **This framework** | Bash + Python (inline) | **1.5** — Python is bash's stdlib, not a separate layer |

The honest comparison: Python in this framework is not a "second language" the way React is to Go. It's what `jq` + `yq` would be if they had richer APIs. Every `python3 -c "import yaml..."` is a bash one-liner that happens to use Python as a YAML/JSON utility.

## Contributor Perspective

**Today:** To add a hook, you need bash + Python one-liners (JSON parse `tool_input`).
**Proposed (bash+TS):** To add a hook, you need bash + TS/node one-liners. Same cognitive load, different runtime.
**Proposed (with Watchtower):** bash + TS + Python. Contributor touching Watchtower must know Python. Contributor touching core never touches Python.

The separability is real: `web/` has zero imports from `agents/` or `lib/`. Watchtower reads `.context/` and `.tasks/` YAML files — a data interface, not a code dependency. You could delete `web/` entirely and every `fw` command still works.

## Honest Assessment

1. **"Optional Python" is genuinely separable.** Watchtower is a read-only dashboard with no write path into core. The interface is YAML files on disk. Tested: `agents/context/context.sh` and `agents/git/git.sh` have zero Python calls.

2. **But Python is not optional in core today.** 107 invocations across 20+ files. The TS rewrite must replace ALL of these, not just Watchtower.

3. **The real language count today is 1.5** (bash + Python-as-utility), not 2. Moving to bash+TS would also be 1.5. Adding Watchtower makes it 1.5 + optional 1 = still 2 for core contributors.

4. **The 3-language concern is valid only if a contributor must know all three to do common work.** Since Watchtower changes and core changes are never in the same PR, this is 2 non-overlapping contributor profiles, not 3-language cognitive load.

## Verdict

**bash+TS core + optional Python Watchtower = 2 languages**, not 3. The Watchtower boundary is a clean data interface (YAML files), not a code dependency. A contributor adding a hook or command never touches Python. A contributor modifying the dashboard never touches bash/TS.

The NO-GO criterion ("3 languages") does not trigger — IF the Python-to-TS migration in core is complete and Python only remains in `web/`.
