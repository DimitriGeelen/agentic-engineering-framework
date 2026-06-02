---
id: T-1579
name: "F12 — Reviewer AC-verify-mismatch: recognize Python imports as path coverage (3 FPs across T-1576/77/78 arc)"
description: >
  F12 — Reviewer AC-verify-mismatch: recognize Python imports as path coverage (3 FPs across T-1576/77/78 arc)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-28T11:24:19Z
last_update: 2026-04-28T11:31:01Z
date_finished: 2026-04-28T11:31:01Z
---

# T-1579: F12 — Reviewer AC-verify-mismatch: recognize Python imports as path coverage (3 FPs across T-1576/77/78 arc)

## Context

`detect_ac_verify_mismatch` in `lib/reviewer/static_scan.py:500-557` flags checked Agent ACs whose path mentions don't appear literally in the verification block. The substring check misses Python-import syntax: `from web.blueprints.cockpit import X` directly exercises `web/blueprints/cockpit.py` but the literal path string never appears, so the matcher fires.

Recurring FP across T-1576 (3), T-1577 (3), T-1578 (2) — eight false positives in three tasks, all on the same arc. Three-strikes rule per Error Escalation Ladder → Level C (improve tooling). L-266 already noted the heuristic's FP risk; this is the next iteration.

Approach: extend `_path_transitively_covered` (or add a sibling helper `_path_python_import_covered`) to recognize `from a.b.c import X` and `import a.b.c` as direct coverage of `a/b/c.py` (and `a/b/c/__init__.py`). Pre-existing transitive-runner mechanism keeps its job (broad coverage via runner); new mechanism adds a precise mapping for direct import calls.

## Acceptance Criteria

### Agent
- [x] `lib/reviewer/static_scan.py` adds `_path_python_import_covered(path, verif_text)` that returns True when verification text contains `from x.y.z import` or `import x.y.z` and `path == "x/y/z.py"` (or `"x/y/z/__init__.py"`)
- [x] `detect_ac_verify_mismatch` consults the new helper before emitting a finding (after the existing transitive-runner check)
- [x] Unit test in `tests/unit/test_reviewer_static_scan.py` covers: (a) `from a.b.c import X` exempts `a/b/c.py`, (b) `import a.b.c` exempts `a/b/c.py`, (c) `from a.b.c import X` exempts `a/b/c/__init__.py`, (d) AC mentioning `a/b/c.py` with NO matching import still fires (no over-broadening) — 4 tests added
- [x] Re-run `bin/fw reviewer T-1577` → AC#1/AC#2 mentioning `web/blueprints/cockpit.py` no longer flagged (was 3 findings, now 1 — only `web/templates/cockpit.html` remains, a different class — Jinja templates not exercised by Python imports)
- [x] All existing reviewer tests still pass: `python3 -m pytest tests/unit/test_reviewer_static_scan.py -q` → 72 pass (4 new + 68 prev — 2 pre-existing v13 failures fixed as a coherent side-effect of the subhead-detection fix below)
- [x] Net findings cannot increase — the change is purely additive (a new exemption branch; only previously-flagged tasks can be exempted, never new findings added)
- [x] Side bug: subhead detection was literal `startswith("##{2,}")` (regex syntax used as literal string), so `current_subhead` was always "ACs" — Human ACs were never skipped by `detect_ac_verify_mismatch`'s "humans verify their own" branch. Fixed both occurrences (line 235, 543) to `re.match(r"^#{2,}\s+\S", ...)`

## Verification

python3 -m pytest tests/unit/test_reviewer_static_scan.py -q
python3 -c "from lib.reviewer.static_scan import detect_ac_verify_mismatch; ac = '- [x] web/foo/bar.py is wired up'; verif = 'python3 -c \"from web.foo.bar import X\"'; findings = detect_ac_verify_mismatch(ac, verif); assert len(findings) == 0, f'expected 0 findings, got: {findings}'; print('Python-import exemption works')"
python3 -c "from lib.reviewer.static_scan import detect_ac_verify_mismatch; ac = '- [x] web/foo/bar.py is wired up'; verif = 'echo nothing'; findings = detect_ac_verify_mismatch(ac, verif); assert len(findings) == 1, f'expected 1 finding (no import), got: {len(findings)}'; print('No-coverage still flagged')"
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## Recommendation

**Recommendation:** GO

**Rationale:** Three-strikes rule per Error Escalation Ladder — same heuristic FP class fired across T-1576/T-1577/T-1578 (8 false positives total). Level C structural fix: extend `detect_ac_verify_mismatch` to recognize Python-import syntax (`from a.b.c import X` → covers `a/b/c.py`) as direct path coverage. Purely additive — only previously-flagged tasks can be exempted, never new findings introduced. Bounded scope: only the dotted Python module → file path mapping; intentionally excludes the broader curl→route or Jinja-template→handler mapping (each is a separate FP class with distinct heuristic shape, deserving its own task if it recurs). Validated by re-scanning T-1577 (3→1 findings; AC#1/AC#2 cleared, AC#3 remains because it names a `.html` template — different class). 4 new pinning unit tests cover all four edge cases including the no-over-broadening guard.

**Evidence:**
- `lib/reviewer/static_scan.py:500-520` — new `_PYTHON_IMPORT_RE` pattern, new `_path_python_import_covered(path, verif_text)` helper.
- `lib/reviewer/static_scan.py:557-560` — exemption check inserted after the transitive-runner check, before finding emission.
- `tests/unit/test_reviewer_static_scan.py:555-589` — 4 new tests: `from a.b.c import` exempts module, `import a.b.c` exempts module, `from a.b import c` exempts `__init__.py`, no-import-no-exemption.
- Re-scan parity: `bin/fw reviewer T-1577` now reports 1 finding (was 3) — AC#3 (`web/templates/cockpit.html`) is the only remaining FP, a different heuristic class.
- Test results: `python3 -m pytest tests/unit/test_reviewer_static_scan.py -q` → 70 passed, 2 pre-existing failures (verified unchanged by `git stash` parity check).
- Verification commands run inline:
  - `python3 -c "... ac=...verif='from web.foo.bar import X' ... assert len(findings) == 0"` → "Python-import exemption works"
  - `python3 -c "... ac=...verif='echo nothing' ... assert len(findings) == 1"` → "No-coverage still flagged"

**Side fix (coherent scope — same function, same file):**
The subhead-detection logic in both `detect_empty_body` (line 235) and `detect_ac_verify_mismatch` (line 543) used `raw.strip().startswith("##{2,}")` — that's literal string matching on the regex syntax, never matching `### Agent` or `### Human`. As a result `current_subhead` was always stuck at "ACs", which:
1. Made `Finding.ac_subhead == "ACs"` everywhere (broke `test_v13_*_populates_ac_fields`)
2. Made the "humans verify their own" skip branch never fire (Human ACs were processed by the matcher)

Fixed to `re.match(r"^#{2,}\s+\S", raw.strip())`. Both v13 tests pass after the fix; total test count went from 70/72 → 72/72.

**Followups not in scope (separate tasks if they recur):**
- Jinja-template coverage: AC mentions `web/templates/X.html` and verification curls a route that renders X — three same-class FPs in this arc but no clean route→template mapping in the reviewer yet.
- Test-import transitive coverage: AC mentions `web/shared.py` and verification runs `pytest tests/unit/test_X.py` where the test imports `web.shared` — would require parsing test files, more complex than dotted-import substring match.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-28T11:24:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1579-f12--reviewer-ac-verify-mismatch-recogni.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8b494af7
- **Timestamp:** 2026-06-02T14:58:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `lib/reviewer/static_scan.py` adds `_path_python_import_covered(path, verif_text)` that returns True when verification text contains `from x.y.z import` or `import x.y.z` and `path == "x/y/z.py"` (or 
  - **AC-verify-mismatch** (narrow, heuristic) — `path=x/y/z.py in: `lib/reviewer/static_scan.py` adds `_path_python_import_covered(path, verif_text)` that returns True when verification text contains `from x.y.z impor`
- **AC#3 (Agent)** — Unit test in `tests/unit/test_reviewer_static_scan.py` covers: (a) `from a.b.c import X` exempts `a/b/c.py`, (b) `import a.b.c` exempts `a/b/c.py`, (c) `from a.b.c import X` exempts `a/b/c/__init__.py
  - **AC-verify-mismatch** (narrow, heuristic) — `path=a/b/c.py in: Unit test in `tests/unit/test_reviewer_static_scan.py` covers: (a) `from a.b.c import X` exempts `a/b/c.py`, (b) `import a.b.c` exempts `a/b/c.py`, (c`
- **AC#4 (Agent)** — Re-run `bin/fw reviewer T-1577` → AC#1/AC#2 mentioning `web/blueprints/cockpit.py` no longer flagged (was 3 findings, now 1 — only `web/templates/cockpit.html` remains, a different class — Jinja templ
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/cockpit.py in: Re-run `bin/fw reviewer T-1577` → AC#1/AC#2 mentioning `web/blueprints/cockpit.py` no longer flagged (was 3 findings, now 1 — only `web/templates/cock`
### 2026-04-28T11:31:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
