# T-1544 — Inception spike: review-first decide-step doc update

**Source:** Pickup envelope `P-042-feature-proposal-from-ntb-atc.yaml` (003-NTB-ATC-Plugin T-202)
**Type:** inception
**Status:** spike → recommendation pending

## Findings

### A1: `agents/inception/AGENT.md` (the proposed target path) does not exist

`agents/inception/` is not a directory in this framework. The inception-discipline
guidance ships in two places:

- `CLAUDE.md` — sections §Inception Discipline (lines 553–569), §Copy-Pasteable
  Commands (lines 514–550), §Presenting Work for Human Review (lines 657–672),
  §Quick Reference (line 788)
- `.tasks/templates/inception.md` line 111 (the Decision-section footer comment)
- `.tasks/templates/path-c-deep-dive.md` line 141 (same footer)

The pickup envelope acknowledges this ambiguity ("agents/inception/AGENT.md or
equivalent"). Effective target = CLAUDE.md + the two templates.

### A2: CLI examples in CLAUDE.md still emit the legacy `--rationale` shape

Three concrete sites in CLAUDE.md §Copy-Pasteable Commands:

```
528: cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve && bin/fw inception decide T-608 go --rationale "approved"
533: cd /003-NTB-ATC-Plugin && .agentic-framework/bin/fw inception decide T-006 go --rationale "approved"
545: fw inception decide T-608 go --rationale "approved"
```

CLAUDE.md §Presenting Work for Human Review (lines 657–672) already says
"NEVER give raw CLI commands (`fw inception decide`...) for human approvals"
and structural enforcement (T-1259/T-1260) refuses the CLI when CLAUDECODE=1.
The `--rationale` examples on 528/533/545 are illustrative for the
"format your bash one-liner this way" rule (T-609, T-1257) — they are not
guidance to use `inception decide` over Watchtower. But they read that way
to a fresh agent who hits 528/533/545 before reaching 657–672.

**Net:** the doc currently teaches both patterns and leaves the agent to infer
precedence. The pickup is asking us to flip the lead so the Watchtower path is
unmissable.

### A3: `--rationale` is REQUIRED at the CLI level (`lib/inception.sh:266,292-293`)

```
266:        echo -e "${RED}Usage: fw inception decide T-XXX go --rationale 'reason'${NC}"
292:    if [ -z "$rationale" ]; then
293:        echo -e "${RED}Rationale required: --rationale 'explanation'${NC}"
```

Implication: the pickup's AC1 ("no --rationale in any decide-step copy-paste
block") cannot be satisfied verbatim — dropping `--rationale` from the CLI
fallback would emit a command that errors-out for the human.

The achievable interpretation: **the lead path is `fw task review` (which uses
Watchtower's form for rationale capture); the CLI fallback retains
`--rationale`** because the CLI surface itself still requires it. Loosening
that surface (interactive prompt, accept empty rationale, etc.) is a separate
inception (CLI-semantics change), not bundled here.

### A4: The Watchtower URL discoverability infrastructure already exists

`bin/fw watchtower url` resolves the project URL via the triple-file
(`.context/working/watchtower.url`) → `fw config get PORT` → `:3000` fallback.
CLAUDE.md §Watchtower Port (lines 92–115) documents the resolution. Agents can
already `bin/fw watchtower url` and prepend the result to any cross-project
copy-pasteable. So pickup AC3 ("read the triple-file") is *already done in
infrastructure*; what's missing is a one-liner reference from the inception-
guidance section that points the agent at `fw watchtower url`.

### A5: Templates carry a `--rationale` footer comment

`.tasks/templates/inception.md:111`:

```
<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->
```

Same string in `.tasks/templates/path-c-deep-dive.md:141`. These propagate to
every inception task created from the template (every T-1538/T-1544/T-1546
right now carries it). The comment is non-functional (it's an HTML comment, not
executed) but it teaches the legacy shape every time an agent reads a task body.

## Achievable delta

**1. CLAUDE.md edits (~6 lines changed)**

- §Copy-Pasteable Commands (lines 528–533, 545): rework the three illustrative
  examples to lead with `fw task review T-XXX`, present the CLI as a labeled
  fallback. Keep the cd-prefix rule and the bin/fw vs .agentic-framework/bin/fw
  distinction (those are the actual lessons of T-609/T-1257).
- §Inception Discipline (around line 568): add one line referencing
  `bin/fw watchtower url` for cross-project decide URLs.

**2. Template footer rewrite (`inception.md`, `path-c-deep-dive.md`)**

Replace the `--rationale` HTML-comment with a review-first equivalent:

```
<!-- Filled at completion via Watchtower review form (fw task review T-XXX),
     or CLI fallback: fw inception decide T-XXX go|no-go --rationale "..." -->
```

The CLI line stays (--rationale is required at the CLI surface), but it's
labeled "fallback" and the Watchtower path leads.

**3. No code changes required.**

`bin/fw watchtower url` already does the right thing. The `--rationale`
requirement on the CLI surface is intentional (T-1259/T-1260 structural
enforcement points agents at Watchtower precisely so they don't have to ship
rationale text in copy-paste). Loosening the CLI is a separate inception.

## Risk surface

- Doc-only change. Reversible by `git revert`. No runtime impact.
- Template edit affects every NEW inception task; existing active tasks
  (T-1538, T-1544, T-1546) keep their existing footer (no rewrite of historical
  bodies needed; that footer is non-functional).
- CLAUDE.md is auto-loaded into every Claude Code session. Edits propagate to
  the next agent invocation (no consumer sync needed).

## Recommendation

**GO** with scope reduced to docs + templates only:
- Update CLAUDE.md §Copy-Pasteable Commands examples (lead with `fw task review`)
- Update CLAUDE.md §Inception Discipline (one line referencing `bin/fw watchtower url`)
- Update the two template footers (Watchtower-first, CLI fallback labeled)

Defer to follow-up inception:
- CLI-semantics change (loosen `--rationale` requirement) — not bundled.
- Pickup AC1 verbatim ("no `--rationale` in any decide-step copy-paste block")
  is unachievable without the CLI change; the modified scope is the right
  interpretation given current CLI surface.

Estimated build effort: 30 min text edits + 5 min smoke (rendered docs review).

## Open question for human (non-blocker)

Should the framework also propose an inception for the CLI-semantics change
(accept missing `--rationale` interactively or via Watchtower-form-only path)?
That would let pickup AC1 land verbatim — but it's a structural change to
`lib/inception.sh do_inception_decide` argument parsing, not a doc tweak.
Recommendation: capture as separate inception, not blocked by this one.
