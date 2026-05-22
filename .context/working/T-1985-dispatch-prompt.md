# T-1985 build dispatch — reviewer auto-tick [REVIEWER] Agent ACs v1.0 (G-066 prong 2)

You are a TermLink-dispatched build worker. Parent session orchestrates from this framework repo. Standing autonomous directive: framework governance applies, commit incrementally, write to repo files directly (NOT /tmp/), report completion via fw bus.

## Task
T-1985. Run `bin/fw work-on T-1985` FIRST. Read `.tasks/active/T-1985-*.md` for full ACs.

## Spec
T-1950 (completed) GO'd the design. Its Decisions block via `inception_decisions:` answers the 4 implementation questions (trigger / scope / evidence-sufficiency / sovereignty-rail). Read `.tasks/completed/T-1950-*.md` BEFORE coding — especially `inception_decisions:` frontmatter and the Recommendation block.

## v1.0 Design Constraints (locked in T-1950, do NOT redesign)

| Decision | v1.0 choice |
|---|---|
| Trigger | Whenever reviewer scan runs (writeback in same pass as verdict block — single atomic write) |
| Scope | `[REVIEWER]`-prefixed Agent ACs ONLY. Human ACs NEVER ticked. Non-prefixed Agent ACs unchanged. |
| Evidence | Conjunctive 5-condition: PASS verdict + zero per-AC findings + AC unticked + no suppress override + `[REVIEWER]` prefix |
| Sovereignty rail | Digest-keyed feedback-stream entry `auto_tick:<task_id>:<ac_index>:<ac_text_digest>` — re-tick blocked if entry exists for the (task, ac_index, digest) tuple |

## Substrate (already in place — do NOT reimplement)
- `lib/reviewer/static_scan.py` v1.4 — `Finding.ac_index/ac_subhead/ac_text` per-AC granular findings shipped in v1.3
- `lib/reviewer/static_scan.py` lines 7 / 1130 — the "NEVER modifies AC checkboxes" guard to be **narrowed** (NOT lifted entirely)
- `.context/working/feedback-stream.yaml` — append-only sovereignty log already used by reviewer
- `update-task.sh` already invokes reviewer post-verification

## Deliverables (one commit per slice; tick the corresponding AC checkbox after each commit)

1. **Helper + sovereignty rail** — Add `_should_auto_tick(ac, findings, overrides, feedback_stream) -> bool` to `lib/reviewer/static_scan.py`. Encapsulates the 5-condition conjunctive check. Add `_compute_ac_text_digest(ac_text) -> str` (sha256 first 12 hex chars). Add `_feedback_stream_has_tick(task_id, ac_index, digest, fs_path) -> bool`. Unit-test each helper in `tests/unit/test_reviewer_auto_tick.py` covering the 5 negative cases + sovereignty cases.

2. **Mutation path** — Narrow the line-7 + line-1130 guard. The mutation path: after computing findings + verdict for a task, iterate over Agent ACs (NOT Human — gate on section header `### Agent` before `### Human`); for each that matches `[REVIEWER]` prefix AND passes `_should_auto_tick`, mutate `- [ ]` → `- [x]` in the in-memory content. Append feedback-stream entry. Single atomic `os.replace` writes the verdict block + mutated checkboxes together. Tests: assert the file write is atomic (use mock to confirm one rename, not two).

3. **Verdict block reporting** — When tick fires, the existing verdict block (`## Reviewer Verdict (v1.X)`) must include `Auto-ticked: <count> AC(s)` line + a sub-list of `- AC #N: <digest-prefix> [<text-excerpt>]` per ticked AC. Bump VERSION to v1.5; SCHEMA_VERSION stays 3 (additive). Pytest covers verdict block format.

4. **Sovereignty test matrix** — Tests covering: (a) tick fires on clean PASS + [REVIEWER] Agent AC; (b) no tick on FAIL verdict; (c) no tick on AC with matching `ac_index` finding; (d) no tick on already-`[x]` AC; (e) no tick when suppress override targets the AC; (f) no tick on non-[REVIEWER] Agent AC; (g) no tick on Human AC even with [REVIEWER] prefix and clean verdict (parse `### Human` boundary correctly); (h) re-scan after human-untick respects feedback-stream and does NOT re-tick (use real fs path); (i) digest of AC text changes (AC rewritten) → eligible to tick again under new digest. Target ≥9 tests. All under `tests/unit/test_reviewer_auto_tick.py`.

5. **No-regression integration** — Run `bin/fw reviewer audit` after slices 1-4. Verify: (a) `bin/fw reviewer T-1985` runs without crash; (b) Layer 3 audit completes with same FAIL count or fewer (no new FAIL class); (c) completed-task scans do NOT mutate completed-task files (mutation only on active/). Pre-existing pytest `tests/unit/test_reviewer_*.py` all green.

6. **Docs + dogfood end-to-end** — CLAUDE.md §AC Classification Guidance: add a paragraph "Reviewer auto-tick (v1.5, T-1985)" — when [REVIEWER] Agent ACs are evidence-gated and ticked automatically; the sovereignty rail; how to un-tick (manual `[x]→[ ]` is respected via digest cache). End-to-end dogfood: T-1985 carries one `[REVIEWER]` Agent AC dedicated as the dogfood probe (add it now if not present — wording: `[ ] [REVIEWER] reviewer audit completes PASS on this task — sentinel AC for v1.0 dogfood`); after final commit, run `bin/fw reviewer T-1985` and verify it ticks. Tick = success.

## Governance reminders (do not skip)
- Framework rule: nothing without active task. `bin/fw work-on T-1985` first.
- Progressive AC ticking (T-1831 C-4): tick `[ ]→[x]` IMMEDIATELY when each slice's work lands. Not after-the-fact.
- Each slice = its own commit. `bin/fw git commit -m "T-1985: <slice>"`.
- Pipefail/SIGPIPE (L-387): never use `cmd | grep -q` in Verification — use `out=$(cmd 2>&1); echo "$out" | grep -q "X"`.
- Bin/fw edits: `bash -n bin/fw` next tool call. ALWAYS (not expected on this task — pure lib/tests).
- Do NOT use --force / --no-verify. Do NOT use the banned TaskCreate/EnterPlanMode tools.
- Path isolation: never edit outside the framework repo.
- AC design rule: Agent ACs are pre-decision deliverables only. Never make "decision recorded" or "if-GO X" an Agent AC — that's the gate trap fixed in T-1950.
- Sovereignty invariant from T-1443 (decisions 36/113/213): Human ACs are NEVER ticked, regardless of prefix or evidence. Verify by parsing the `### Human` section header boundary.

## Reporting
- Commit incrementally. After EACH slice commit, post a one-line update to fw bus:
  `bin/fw bus post --task T-1985 --agent t1985-worker --summary "<slice-N landed: <one-liner>>"`
- On completion (all 6 slices), set status:
  `FW_SWITCH_FOCUS=1 bin/fw task update T-1985 --status work-completed`
- If gate refuses, that's the gate DOING ITS JOB — investigate. Real refusal = bug in a slice.
- If you hit a blocker you cannot resolve in 3 hypotheses (CLAUDE.md §Hypothesis-Driven Debugging), STOP and post:
  `bin/fw bus post --task T-1985 --agent t1985-worker --summary "BLOCKED: <what>" --result "<details>"`

## Success
- T-1985 task body: all 8 Agent ACs ticked
- 6 commits prefixed `T-1985:`
- `bin/fw audit` PASS (or only pre-existing WARNs)
- `bin/fw reviewer T-1985` returns PASS + auto-ticks the sentinel `[REVIEWER]` AC (dogfood proves the build)
- Verdict block reports `Auto-ticked: 1 AC(s)` on the final scan

Begin.
