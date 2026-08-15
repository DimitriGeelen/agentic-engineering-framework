# T-3025 IW-2 — Arm A (full handover) cold-recovery probe

Source document (sole input): `scratchpad/full-0019.md` — handover `S-2026-0816-0019`.
No other file read; no `git`/`fw`/`ls` run.

---

## Q1. Branch, and anything unpushed?

**Answer:** The work is on branch **`t2539-staging`**, which is **131 commits ahead of
`origin/master`** (`+131 / −0`). There are **5 uncommitted changes** in the working tree.

Whether the *branch itself* has commits unpushed to its own remote is **NOT IN DOCUMENT** —
the document only gives the delta against `origin/master`, and separately notes that
"landing `t2539-staging` on master has never been approved". The document does record that
pushes were failing for most of the session (the pre-push audit was RED on 2 of 57
structural invariants), but does not state the final push state.

- Confidence: **high** for branch and ahead-count; **medium** for uncommitted; **low/absent**
  for unpushed-to-origin.
- source: `**Branch:** \`t2539-staging\` +131 / −0 vs origin/master`; `uncommitted_changes: 5`;
  `landing \`t2539-staging\` on master has never been approved`
- Command to resolve the gap: `cd /opt/999-Agentic-Engineering-Framework && git status -sb && git log --oneline origin/t2539-staging..HEAD`

---

## Q2. The single most important thing the next session must NOT do

**Answer:** **Do not start candidate A (binary quantization + exact rescore).** The reason is
a scope-of-consent boundary: T-3022's GO rationale *names* candidate A, but candidates E′ and
F landed minutes before the operator decided, so the GO **cannot be read as authorising A**.
A is unstarted and needs its own task and its own explicit yes from the operator.

A close second, and operationally more likely to bite: **never run `git add -A`** — the
operator commits into this repo concurrently via Watchtower, and broad staging twice picked
up deletions of `.context/episodic/T-30{22,18}.yaml` that the operator's commit had created
seconds earlier. Read `git status` immediately before every commit.

- Confidence: **high**
- source: `Do **not** start candidate A (binary quantization) — see Decisions above; the GO does not cover it.`;
  `**The operator commits into this repo concurrently, via Watchtower.** Read \`git status\` immediately before every commit, and never \`git add -A\`.`

---

## Q3. One decision made last session, and the reasoning

**Answer:** **Hold `INDEX_HANDOVERS` ON by default** (T-3024) — taken *against the agent's own
earlier leaning*. Reasoning: the evidence is strong on **cost** (~90 MB, 1,710 files) but
**thin on consequence** — nobody has shown what actually breaks when handovers leave the
index. Excluding them first would relieve the symptom and thereby remove the pressure to fix
the underlying cause (T-3025 candidate F, handover state-by-value).

Three other decisions are recorded: ship E′ (inclusion set as a content-class rule) rather
than A; file candidate F as an **inception**, not a build, because the measurement is settled
but the design question ("what is a handover for?") belongs to the operator and its four
options (embed / reference / digest+reference / delta-only) are not costed; and declined to
add `project_name` to `.framework.yaml` because it is not in `FW_CONFIG_REGISTRY` and the
config-parity call is the operator's.

- Confidence: **high**
- source: `**Hold \`INDEX_HANDOVERS\` ON by default** (T-3024), against my own earlier leaning. Evidence is strong on cost (~90 MB, 1,710 files) but thin on consequence`

---

## Q4. Observations pending triage, and how many urgent

**Answer:** **153 pending observations, 12 of them urgent.** The document recommends running
`fw note triage` before starting new work, and flags OBS-271/272/273 as filed this session —
OBS-273 being a real gate catch-22 that will hit the next agent filing an inception the same
way.

- Confidence: **high**
- source: `**153 pending observations (12 urgent)** — run \`fw note triage\` before starting new work.`
  (repeated in Open Questions: `153 pending observations (12 urgent)`)

---

## Q5. Is T-2977 in progress? Last recorded action?

**Answer:** **No.** T-2977 — *"designer inspector shows no per-node note — blocked on 832
release"* — is **`captured`**, horizon **`later`**, blockers "None". `captured` is not
started-work, so it is not in progress; the `later` horizon also excludes it from Suggested
First Action. It does appear in the session's `tasks_touched` list, so it was touched, but no
narrative describes what was done.

Its last recorded action is **NOT IN DOCUMENT** — the handover's "Last action" field for
T-2977 is the placeholder string `See git log`, i.e. the generator had nothing to report.

- Confidence: **high** (not in progress); **high** (last action genuinely absent)
- source: `### T-2977: "designer inspector shows no per-node note — blocked on 832 release"` /
  `- **Status:** captured (horizon: later)` / `- **Last action:** See git log`
- Command to resolve: `cd /opt/999-Agentic-Engineering-Framework && git log --oneline --all --grep="T-2977"`

---

## Q6. First thing to do, second thing to do

The document is explicit that the vector-DB arc is **blocked on the operator across six
review items** (T-3024, T-3016, T-3017, T-3019 as partial-complete `/review/<id>`; T-3025,
T-3018 as inception `/inception/<id>`), so starting new work in that arc only lengthens the
queue. Two things are actionable without a decision:

1. **T-3025 IW-2** — replay a real post-compaction recovery against a synthetic
   *digest-plus-reference* handover and see whether the session reconstitutes. It is the one
   open question on candidate F that measurement can settle, and it is cheap.
2. **Triage the observation inbox** — `bin/fw note triage`; 153 pending, 12 urgent, including
   OBS-271/272/273 filed this session.

If the six review URLs are needed, get them from `bin/fw task review-batch …` rather than
hand-typing — the two decision classes route to different pages.

- Confidence: **high**
- source: `1. **T-3025 IW-2** — replay a real post-compaction recovery against a synthetic digest-plus-reference handover`;
  `2. **Triage the observation inbox** (\`bin/fw note triage\`) — 153 pending, 12 urgent`

---

## Q7. What I wanted to know and could not determine

Not "nothing missing". Four gaps, all of which the document either placeholder-stubs or
never addresses:

1. **Actual push state of `t2539-staging` against its own remote.** The document gives only
   the delta vs `origin/master` and a mid-session narrative of failing pushes; it never says
   whether the final three commits landed on origin.
   → `cd /opt/999-Agentic-Engineering-Framework && git status -sb && git log --oneline origin/t2539-staging..HEAD`

2. **What the 5 uncommitted changes are.** The frontmatter gives a count only. Given the
   standing "operator commits concurrently, never `git add -A`" warning, knowing *which*
   files are dirty is a precondition for safely committing anything.
   → `cd /opt/999-Agentic-Engineering-Framework && git status --short`

3. **T-2977's real last action and next step.** Both fields are placeholders (`See git log`,
   `See task file`). The title says "blocked on 832 release" but Blockers reads "None" — a
   contradiction the document cannot settle.
   → `cd /opt/999-Agentic-Engineering-Framework && bin/fw task show T-2977`

4. **The 2 RED structural invariants that were blocking the pre-push audit.** One is named
   (`INDEX_HANDOVERS` registered in `lib/config.sh` but not in `web/blueprints/config.py`);
   the second is not, and the document does not say whether either was fixed before the
   session ended.
   → `cd /opt/999-Agentic-Engineering-Framework && bin/fw audit --section structure`

Minor: the "Last action" line for most in-progress tasks quotes a commit subject from a
*different* task (e.g. T-1274's last action is a T-2055 commit), which makes that field
unreliable as a per-task signal across the whole Work-in-Progress section — worth knowing
before trusting it.
