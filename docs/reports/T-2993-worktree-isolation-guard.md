# T-2993 — The worktree isolation guard, and the map that isn't there

**Status:** exploration complete
**Filed:** 2026-08-14
**Trigger:** operator paste of a blocked trace from 005-Yellowtwig, asking
whether the process can be streamlined and whether to start from a workflow
design.

---

## The trace

A session isolated in `.claude/worktrees/T-021-hygiene` was deciding whether
three sibling worktrees could be pruned. It tried the obvious thing:

```
git -C …/.claude/worktrees/T-020-audit-remediation status --short
→ This session is isolated in the worktree …/T-021-hygiene, but this command
  redirects git to the shared checkout via -C. Refusing to run it — a
  worktree-isolated session's git operations must target its own worktree.
```

It then concluded *"cross-worktree git is (correctly) blocked from here —
pruning happens after I exit"* and deferred the work.

## Spike 1 — whose guard is it? (IW-1)

**Not ours.** Three independent lines agree:

1. **Absent from all source.** No fragment of the message (`Refusing to run
   it`, `via -C`, `isolated in the worktree`, `must target its own worktree`)
   exists in this repo's `lib/`, `agents/`, `bin/`, or in the consumer's
   vendored `.agentic-framework/` (v1.6.212), or anywhere under the consumer
   project at all.
2. **Wrong error shape.** Every framework hook refusal is prefixed
   `PreToolUse:<Tool> hook error: [… fw hook <name>]` and suffixed
   `Policy: P-XXX`. Four such refusals were produced in this very session while
   investigating. The Yellowtwig refusal is a bare `Error:` with neither.
3. **The harness owns worktree isolation.** `EnterWorktree` / `ExitWorktree`
   are Claude Code built-ins. Their contract explicitly governs which worktree
   a session may write to, including *"after a further switch, previously-visited
   worktrees are no longer writable"*. Enforcing that a session's git operations
   target its own worktree is that same mechanism.

The consumer's entire hook wiring was enumerated (25 hooks, all
`fw hook <name>`) to rule out a project-local guard. There is none.

**Consequence, and it reshapes the whole task:** we cannot narrow this guard.
Every remedy has to live on our side of the line.

## Spike 2 — is the guard wrong? (IW-2)

Partly, and it matters less than it first appeared.

The message is **factually wrong about its own target**: the `-C` path was a
sibling worktree, not the shared checkout. So the predicate is evidently
"`-C` points somewhere other than here", with the "shared checkout" wording
hard-coded rather than derived. And it **blocks read-only verbs** — both
refusals were `status --short`.

But the second-order observation is the one that changes the recommendation:

> **`git status --short` was the wrong check anyway.**

It reports *uncommitted* files. The thing that actually strands work in a
worktree is *committed but unpushed* commits — the T-2428 class (6 commits
stranded 5 weeks), which is why CLAUDE.md §Copy-Pasteable Commands rule 6
exists at all. A clean `git status --short` on a worktree holding unpushed
commits reads as "safe to remove". The guard blocked a check that would have
produced a **false green**.

So the session was not prevented from doing something necessary. It was
prevented from doing something *weaker than what the framework already ships*.

## Spike 3 — do we already have the verb? (IW-3, IW-4)

Yes. `fw worktree gc`, run in this repo during the spike:

```
  ✗ KEEP  worktree-rca-worktree-push-strand  (unlanded:14/53)  [no remote — push before any prune]
  ✓ RECLAIM worktree  t100199-close  (no-deliverables)
  ✗ KEEP  t100196-vendor-fix  (unlanded:1440/1442)  [no remote — push before any prune]
Summary: 4 reclaimable, 8 to keep (unlanded work — push-then-triage).
```

Content-verified, per-worktree, dry-run by default, branch deletes held at
Tier-0, and it reports precisely the unlanded-commit state that `status
--short` cannot see. `fw worktree remove` additionally refuses when the branch
is unpushed to every remote. `fw worktree status` gives the read-only topology.

**Why these are not blocked by the harness guard:** the guard matches the
command string the agent types. `bin/fw worktree gc` contains no `-C`. The
`git -C "$wt_path" status --porcelain` at `lib/worktree.sh:398` is *inside a
script*, and a guard that inspects command text cannot see into an interpreted
file — the identical scope boundary CLAUDE.md §Enforcement Tiers documents for
our own Tier 0 ("Tier 0 sees the command string, and nothing else").

**Confidence and its limit.** This is a strong structural inference, not a
measurement: it was not executed from inside an isolated worktree session,
because this session is in the main checkout and cannot reproduce the guard.
Stated as an inference rather than a result on purpose — it is the one claim
here that a build task should verify before depending on it.

## The actual gap

Not the guard. Three things, in order of how much they cost:

**1. The refusal is a dead end.** It names no alternative, because the harness
has no idea `fw worktree gc` exists. A capable session hit it, believed it,
and deferred real work out of the session that had the context to do it. That
is the streamlining loss the operator is asking about, and it is entirely
recoverable on our side by making the sanctioned verb reflexive.

**2. Teardown-from-inside is a recurring class, and we only ever patched
instances of it.** The same shape is already documented twice, each time as a
local rule rather than a principle:

| where | the rule | the class |
|---|---|---|
| §Trunk-Based Session Flow | run `fw integrate` from the main checkout, "never from inside the worktree it will remove (that self-removal hangs)" | teardown from inside the thing torn down |
| §Copy-Pasteable Commands r6 (T-2825/G-075) | don't hand off a `cd …/worktrees/<name>` command that outlives the session | the worktree is ephemeral, the branch is not |
| this incident | a worktree-isolated session cannot inspect its siblings | same |

Three instances, three separate paragraphs, no shared statement. The general
form is one sentence: **operations on the set of worktrees belong to the main
checkout; operations within one worktree belong to that worktree.** Every
incident above is a violation of that single line.

**3. The corpus has no worktree map — and this is the load-bearing finding.**

```
aef-audit-cron          aef-inception-flow      aef-task-lifecycle
aef-dispatch-loop       aef-session-lifecycle   aef-tier0-escalation
aef-existing-project-onboarding                 aef-greenfield-onboarding
```

Eight canonical maps. Occurrences of "worktree" across all of them: **zero**.

Yet §Trunk-Based Session Flow makes the worktree the *mandatory* path for all
real code ("real code lands on origin/master via worktree + `fw integrate` —
never from the session directly"). The one lifecycle every code change must
traverse is the one lifecycle the corpus does not model — while the task,
session, inception, dispatch, audit and tier-0 lifecycles all are.

That is a direct answer to the operator's *"maybe we should start with a
workflow design?"*: **yes** — and not as a nicety. A map is what makes
"which checkout owns this operation" answerable by looking rather than by
remembering, and the evidence that remembering has failed is four incidents
(T-2428, T-2825, T-100194/T-100199, this one) across three separate rules.

## Open questions — disposition

| id | disposition | evidence |
|----|---|---|
| IW-1 | answered (3) | absent from all source; wrong error shape; harness owns EnterWorktree/ExitWorktree |
| IW-2 | answered (3) | message misnames its target; blocks read-only verbs; but the blocked check was itself a false-green |
| IW-3 | answered (3) | `lib/worktree.sh:398` uses the shape, inside a script; `fw worktree gc` ran clean here |
| IW-4 | answered (2) | not "narrow the guard" (can't — not ours) and not "new verb" (already have it); it's routing + a missing map |

**A1 refuted** — the guard is not ours. **A2 holds** — predicate does not
distinguish sibling from shared checkout. **A3 holds** — read-only verbs are
blocked. **A4 holds with a twist** — our tooling uses the shape but survives,
because it is script-internal.

## Dialogue Log

### 2026-08-14 — operator, mid-turn

> "can we anlyse this and investigate / nevluate if / how we can streamlikne
> this process maybe we shoudl start wioth a workflow design ?"

Read as three questions: is the refusal correct, can the flow be streamlined,
and is a designer map the right starting artefact. Answers: partly / yes / yes.

### 2026-08-14 — the framing I started with was wrong

I opened this expecting to find an over-broad framework guard and narrow it.
The filed DEFER rationale says so explicitly, and leads with "the message is
factually wrong about its own target". That observation is true and turned out
to be nearly irrelevant: the guard is the harness's, we cannot change it, and
the command it blocked was a check that would have produced a false green.

Recorded rather than smoothed over, because the wrong frame survived two
spikes before the corpus grep displaced it — and because a build task
inheriting "fix the guard" from my filing would have chased something it could
not reach.

### 2026-08-14 — why the recommendation is not "document it harder"

The obvious remedy is a CLAUDE.md paragraph saying "use `fw worktree gc`".
That is what was done for the two prior instances of this class, and this is
the third. The T-2990 precedent is fresh and pointed: a rule documented from
T-1376 onward was violated 371 times across 277 tasks before it was made
structural. Prose is the remedy that was already tried twice here.
