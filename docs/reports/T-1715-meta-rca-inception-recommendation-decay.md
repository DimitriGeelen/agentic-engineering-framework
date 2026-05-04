# T-1715 — Meta-RCA: agent files inception artefacts without ## Recommendation block

**Status:** captured / awaiting inception decision
**Origin:** session 2026-05-04, prompted by human pushback after T-1714 was
filed without a Recommendation block.

The task file
`.tasks/active/T-1715-meta-rca-agent-files-inception-artefacts.md`
carries the full content. This artifact captures the dialogue trail and
in-session evidence per C-001.

## Dialogue Log

**2026-05-04** — Same session, same agent, same conversation:

| Task | Filed with `## Recommendation` block? |
|------|--------------------------------------|
| T-1709 | Yes — full GO recommendation, rationale, evidence, risk ack |
| T-1713 | No — section was template-only |
| T-1714 | No — section was template-only (caught by human) |

**Human pushback:** "no reccomendationn no rationalty, on t1714 ,, can
we please file RCA incpoetion, this keeps happening !!!"

**Agent response:** acknowledged the recurring failure, retrofitted
T-1714 with a full Recommendation block, filed T-1715 as the meta-RCA
that the user explicitly requested.

## Why this is meta-RCA, not just "fix the symptom"

The T-679 rule ("never present a blank decision for them to fill in")
exists in CLAUDE.md as advisory text. Its enforcement is uneven:
- `fw inception decide T-XXX` blocks under `$CLAUDECODE=1` (T-1259/T-1260).
- `fw arc close` requires `--demo` + refuses under `$CLAUDECODE=1` (T-1668/T-1671).
- `fw inception start` and `fw work-on --type inception` have NO equivalent
  filing-time gate.

The agent reliably hits the decide-time gate (it can't bypass the
structural refusal), but reliably misses the filing-time advisory rule
(it's just text in the prompt context). L-300 from T-1550 documents
exactly this pattern: behavioural rules in CLAUDE.md fail to fix
recurring patterns; structural enforcement is required.

T-1715 is the structural enforcement at filing time, mirroring the
shape of T-1668's `--headline-mechanic` gate at `fw arc create`.

## Cross-references

- See task file for full RCA, assumptions, exploration plan, scope fence,
  go/no-go criteria, Recommendation block.
- Related: T-679 (origin of the rule), T-1259/T-1260 (decide-time gate),
  T-1668/T-1671 (arc-create / arc-close gates), T-1550 / L-300
  (advisory-text-fails-to-fix pattern).
- Recommendation: GO (see task file §Recommendation).
