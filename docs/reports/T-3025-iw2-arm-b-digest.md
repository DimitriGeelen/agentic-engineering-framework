# T-3025 IW-2 — Arm B (digest-plus-reference) recovery replay

Recovering session answered the six probe questions **from `digest-0019.md` only**. No
other file read, no command run.

---

## Q1. What git branch is the work on, and is there anything unpushed?

**Answer:** Branch is `t2539-staging`, sitting **+131 / −0 vs `origin/master`**, with
**5 uncommitted changes** in the tree. So yes — there is unlanded work: 131 commits
ahead of `origin/master` plus 5 uncommitted files. The digest also flags that
**landing `t2539-staging` on master has never been approved**, so those 131 commits are
unlanded by decision, not by accident.

**Caveat the digest does not settle:** "+131 vs origin/master" does not tell me whether
the branch itself has been *pushed* to `origin/t2539-staging`. Ahead-of-master ≠ unpushed.

**Confidence:** high (branch, ahead-count, uncommitted count) / low (push state of the branch)

**source:** "**Branch:** `t2539-staging` +131 / −0 vs origin/master"; "uncommitted_changes: 5";
"landing `t2539-staging` on master has never been approved"

---

## Q2. What is the single most important thing the next session must NOT do, and why not?

**Answer:** **Do not start candidate A (binary quantization + exact rescore).** The
reason is an authorisation boundary, not a technical one: T-3022's GO rationale *names*
candidate A, but E′ and F landed minutes before the operator decided, so the GO cannot be
read as authorising A. A "remains unstarted and needs its own task and its own explicit
yes." This is the one prohibition the digest states twice — once in Decisions, once in
bold at the close of Suggested First Action.

**Runner-up, operationally sharper:** never `git add -A`, because the operator commits
into this repo concurrently via Watchtower; two near-misses this session both staged
deletions of episodic files the operator's commit had created seconds earlier. I rank
candidate A first because the digest itself marks it as the emphatic don't; I'd rank the
`git add -A` rule first if the question were "what will bite you within the hour."

**Confidence:** high

**source:** "Do **not** start candidate A (binary quantization) — see Decisions above; the GO
does not cover it."

---

## Q3. Name one decision made in the last session and the reasoning behind it.

**Answer:** **Hold `INDEX_HANDOVERS` ON by default (T-3024)** — taken *against the
author's own earlier leaning*. Reasoning: the evidence is strong on **cost** (~90 MB,
1,710 files) but **thin on consequence** — nobody has demonstrated what actually breaks
when handovers leave the index. Excluding them first would relieve the symptom and, in
doing so, remove the pressure to fix the cause (T-3025 candidate F). That is an
antifragility argument: keep the pain attached to the thing that should be redesigned.

Three other decisions are recorded: ship E′ not candidate A; file F as an inception
rather than a build (measurement settled, design question is the operator's, four options
uncosted); and declined to add `project_name` to `.framework.yaml` (not in
`FW_CONFIG_REGISTRY`; a config-parity call belonging to the operator).

**Confidence:** high

**source:** "**Hold `INDEX_HANDOVERS` ON by default** (T-3024), against my own earlier
leaning. Evidence is strong on cost (~90 MB, 1,710 files) but thin on consequence"

---

## Q4. How many observations are pending triage, and how many of those are urgent?

**Answer:** **153 pending observations, 12 of them urgent.** Three were filed in the last
session: OBS-271, OBS-272, OBS-273. OBS-273 is called out specifically — a real gate
catch-22 (`fw task update --type inception` blocked by G-020, which is the exact command
G-020's own message recommends) that "will hit the next agent that files an inception the
same way."

**Confidence:** high

**source:** "**Triage the observation inbox** (`bin/fw note triage`) — 153 pending, 12 urgent"

---

## Q5. Is task T-2977 currently in progress? If yes, what was its last recorded action?

**Answer:** T-2977 is **active** — it appears in `tasks_active`, and it also appears in
`tasks_touched`, which means the last session touched it. So: in progress, yes.

**Its last recorded action: NOT IN DOCUMENT.** The digest carries T-2977 as a bare id in
two front-matter lists and nowhere else. It is not among the four tasks named in the
"Session worked on" line (T-3025, T-3024, T-3022, T-3018), it is not in the five
Work-in-Progress entries embedded by value, it is not in Recent Commits, and it is not in
Files Changed. The digest states outright that 114 WIP entries were "not embedded" — 69,304
bytes of Work-in-Progress dropped by reference — so any per-task detail for T-2977 was
deliberately elided. I know it was touched; I cannot say what was done to it.

Command I would run:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw task show T-2977
```

**Confidence:** high (that it is active and was touched) / high (that the action is absent)

**source:** "tasks_touched: [T-2977, T-3006, …]"; "_114 more not embedded. This section was
69,304 bytes when embedded by value._"

---

## Q6. What should you do first, and what should you do second?

**Answer, in the digest's own order:**

1. **T-3025 IW-2** — replay a real post-compaction recovery against a synthetic
   digest-plus-reference handover and see whether the session reconstitutes. The digest
   argues this is *the* open question on candidate F that measurement can settle, and that
   it is cheap. (This exercise is that replay.)
2. **Triage the observation inbox** — `bin/fw note triage`; 153 pending, 12 urgent,
   including OBS-271/272/273 filed last session.

The framing behind the ordering: the vector-DB arc is **blocked on the operator across six
review items** (T-3024, T-3016, T-3017, T-3019 as partial-complete `/review/<id>`; T-3025,
T-3018 as inception `/inception/<id>`), so starting new work inside the arc would only
lengthen that queue. Both suggested actions are chosen precisely because they need no
operator decision.

**Confidence:** high

**source:** "1. **T-3025 IW-2** — replay a real post-compaction recovery … 2. **Triage the
observation inbox** (`bin/fw note triage`)"

---

## Q7. Anything I wanted to know and could not determine?

Not "nothing missing." Five items:

**1. Whether `t2539-staging` is pushed to its own remote.** The digest gives ahead-of-master
only. Since the whole point of the handover discipline is "never end a session with
unpushed commits," this is the one gap that actually mattered to Q1.
```
cd /opt/999-Agentic-Engineering-Framework && git status -sb && git log --oneline origin/t2539-staging..t2539-staging
```

**2. T-2977's last recorded action** (Q5 above).
```
cd /opt/999-Agentic-Engineering-Framework && bin/fw task show T-2977
```

**3. What the 5 uncommitted changes are.** The count is given; the paths are not. I cannot
tell whether they are mid-edit source, or governance state safe to commit — and the digest
simultaneously warns me the operator may be committing concurrently. Knowing the count
without the paths is close to useless here.
```
cd /opt/999-Agentic-Engineering-Framework && git status --porcelain
```

**4. Which 12 of the 153 observations are the urgent ones.** Only 5 observation stubs are
embedded (OBS-099, 103, 104, 105, 106), and none is flagged urgent; the three named as
newly filed (OBS-271/272/273) have no body text at all. Suggested action #2 is therefore
not executable from the digest — I'd be triaging blind.
```
cd /opt/999-Agentic-Engineering-Framework && bin/fw note triage
```

**5. The exact review URLs for the six blocked items.** The digest explicitly forbids
hand-typing them (the two decision classes route to different pages) and names the command
instead — correct discipline, but it means the handoff is not self-contained.
```
cd /opt/999-Agentic-Engineering-Framework && bin/fw task review-batch T-3024 T-3016 T-3017 T-3019 T-3025 T-3018
```

**Observation on the digest form itself (IW-2's actual question).** The reference-style
sections behaved differently by kind. The *narrative* sections — Decisions, Things Tried
That Failed, Gotchas, Suggested First Action — survived compaction intact and carried real
reasoning; I could answer Q2, Q3 and Q6 with high confidence and quote chapter and verse,
including the self-correcting `pgrep`/pre-push-audit story, which is exactly the kind of
thing a by-value dump would have buried. The *live-state* sections — WIP, review queue,
observations — degraded to counts plus five samples, and every one of my five gaps sits in
that class. That split looks like the finding: prose reconstitutes, enumerations don't, and
the digest is honest about which is which (it prints the byte cost it declined to pay).
The residual risk is that a section which *looks* answered by five samples reads as
complete — Q4 is the case in point: I got the numbers right and still cannot act on them.
