# T-3047 — Triage batch 3

Scope: M-03, M-08, M-13, M-18, M-23, M-28, M-33, M-38 from
`docs/reports/T-3047-recovered-upstream-messages.md`.

Read-only investigation. No source file, task file, `.context/` file or CLAUDE.md
was modified.

---

## M-03 — FIXED

- **defect:** The episodic generator's `grep -v '^##'` filter greedily consumed `###` H3
  decision headings, so every decision in a task merged into one flat mapping with
  duplicate keys silently overwritten by `yaml.safe_load`.
- **evidence:** The reported commit is present in this repo —
  `git log --oneline -1 7dedefca726be9f0cadfb88e2946d785d958f53a` →
  `7dedefca7 T-1631: G-082 fix — preserve ### H3 date/topic headings in episodic decisions + post-write YAML validation`.
  The line-filter parse no longer exists at all: `agents/context/lib/episodic.sh:147`
  delegates the whole section to `extract_decisions.py`, with a comment at
  `agents/context/lib/episodic.sh:139-144` (T-3015) forbidding reintroduction of a line
  filter and naming `tests/unit/test_extract_decisions.py` as the pin. The prevention
  layer the message describes is also present: post-write `yaml.safe_load` validation
  with `exit 2` at `agents/context/lib/episodic.sh:439-448`, comment-tagged
  "T-1631 / G-082 prevention".

## M-08 — NOT-OURS

- **defect:** None described. This is a design proposal from ring20-management (OOB
  WebAuthn + ntfy + Watchtower approval surface) asking five questions of the framework
  agent — pattern endorsement, shared-component shape, Tier-0 hook write-format
  stability, cred-gate dir layout, audit format.
- **evidence:** Message body at `docs/reports/T-3047-recovered-upstream-messages.md:136`
  — `"msg_type":"design-proposal"`, `"asks":[...]`, `"ring20_offer":"Build cred-gate slice
  first as T-733 follow-up"`. No defect, no reproduction, no framework code path named as
  faulty. The referenced artifacts live in the consumer
  (`proxmox-ring20-management/.context/working/T-733/...`,
  `proxmox-ring20-management/docs/reports/T-733-...`).

## M-13 — NOT-OURS

- **defect:** None. A request to `cohort_hub` for Claude Collective brand assets (logo
  SVG/PNG, LinkedIn cover, palette spec) plus a push of those assets to the OneDev
  `claude-collective` repo.
- **evidence:** `docs/reports/T-3047-recovered-upstream-messages.md:247-263` — "Request —
  two parallel deliverables: 1) Send the Claude Collective logo + SVG source to
  ring20-manager … 2) Push the same assets to OneDev claude-collective repo". Asset
  delivery and a third-party repo; nothing in this framework repo is implicated.

## M-18 — NOT-OURS

- **defect:** None in this framework. A Discourse admin request: create a `cohort-bot`
  user, issue an API key, grant trust level 1+, confirm topic-7 posting rights. The
  observed failure is a Discourse-side `403 invalid_access`.
- **evidence:** `docs/reports/T-3047-recovered-upstream-messages.md:446` — "Live smoke
  fails: **403 invalid_access** … confirms either the key is scoped to a different user
  OR `cohort-bot` user doesn't exist on the Discourse instance". The code involved is
  the consumer's own client (`cohort_hub/discourse.py` in 002-Claude-Partner-Network);
  the fix is infrastructure admin work, explicitly scoped as "~10 minutes of Discourse
  admin work on your side. No code changes on .107 needed".

## M-23 — LIVE

- **defect:** `pickup_next_id()` scans only inbox/processed/rejected and ignores
  `auto-deferred/`, so an ID already consumed by an auto-deferred envelope is reissued;
  the auto-defer `mv` then overwrites the earlier envelope with no error, silently
  losing a filed pickup.
- **evidence:** Both cooperating gaps are still present, verbatim as reported.
  Gap (A) — `lib/pickup.sh:306`:
  `for dir in "$PICKUP_INBOX" "$PICKUP_PROCESSED" "$PICKUP_REJECTED"; do` — the
  allocator's scan list, with `PICKUP_AUTO_DEFERRED` declared at `lib/pickup.sh:26` but
  absent from that loop.
  Gap (B) — `lib/pickup.sh:424`:
  `mv "$file" "$PICKUP_AUTO_DEFERRED/" 2>/dev/null || true` — plain `mv`, no `-i`, no
  destination-existence check, and errors suppressed. The sibling auto-defer at
  `lib/pickup.sh:435` (`if mv "$file" "$PICKUP_AUTO_DEFERRED/" 2>/dev/null; then`) has the
  same shape; it writes a breadcrumb but still clobbers a same-named destination.
- **if LIVE:** A fix must add `"$PICKUP_AUTO_DEFERRED"` to the `pickup_next_id()` scan
  loop at `lib/pickup.sh:306` and make both auto-defer `mv` calls collision-safe (rename
  on existing destination rather than overwrite). **No existing coverage found:** `grep
  -n "G-046" .context/concerns.yaml` returns nothing, and no active task references
  `pickup_next_id` (`grep -rln "pickup_next_id" .tasks/active/` → no matches; the only
  corpus hit is the completed `T-774-pickup-pipeline-core--libpickupsh-with-r.md`, which
  is the original implementation, not a fix). This defect is uncovered and needs a task.

## M-28 — NOT-OURS

- **defect:** None. Four design questions from ring20-dashboard to ring20-manager about a
  signed-RPC remediation pilot (OpenVPN client-cert reissue script availability, RPC
  envelope placement, `termlink remote exec` allowlist, audit sink preference).
- **evidence:** `docs/reports/T-3047-recovered-upstream-messages.md:1082-1090` — "What I'm
  asking / 1) Do you have a shell-callable script today for OpenVPN client-cert reissue…".
  The one finding it does report is a TermLink gap, not a framework one:
  line 1093 — "termlink command-allowlist exists on `remote push` (PL-057) but NOT on
  `remote exec`". TermLink is a separate repo (`DimitriGeelen/termlink`); per §Gap Homing
  that belongs in TermLink's register, not this one.

## M-33 — NOT-OURS

- **defect:** None. A deployment handoff asking ring20-management to host the static
  geelenandcompany.com site on a Cloudron DEV slot, with three infrastructure questions
  (app type, delivery mechanism, target domain).
- **evidence:** `docs/reports/T-3047-recovered-upstream-messages.md:1221-1228` — "ASK:
  deploy Dimitri's geelenandcompany.com hub … to a Cloudron DEV environment in your
  Ring20 infra", followed by "Please DO NOT shred or deploy anything yet". Pure
  infrastructure coordination; the only framework-adjacent mention is G-157 (cross-host DM
  read deadlock), which is the sender's stated *reason for reposting on agent-chat-arc*,
  not a defect filed against this repo — and G-157 is a TermLink/hub transport concern.

## M-38 — FIXED

- **defect:** The P-011 verification gate ran the `## Verification` block line-by-line with
  no shell syntax pre-check (unparseable multi-line constructs presented as failed
  assertions), and had no concept of HTML comments — so the old template's `<!-- … -->`
  example commands were executed verbatim, issuing real HTTP requests and greps.
- **evidence:** Finding 1 is closed — `agents/task-create/update-task.sh:1175-1176` calls
  `check_verification_parseable "$verify_cmds"` and exits 1 **before** the read/`eval`
  loop, with the T-2991 comment at lines 1170-1174 stating the ordering is deliberate
  ("Checking after the loop would report the same finding and prevent nothing").
  Finding 2 is closed — `extract_verification_block` (`lib/verification-port.sh:175-181`)
  pipes the block through `lib/comment_strip.py`, which implements the structural rule
  documented at `lib/comment_strip.py:1-10` (`<!--` opens a span only as first non-blank
  token; span ends at first `-->`; comment lines dropped whole). Verified live against the
  exact template residue the message quotes:

  ```
  $ printf '## Verification\n<!-- Shell commands that MUST pass.\n     curl -sf http://localhost:3000/page\n     grep -q "expected" out.txt\n-->\necho real-command\n\n## Next\n' > /tmp/vtest.md
  $ source lib/verification-port.sh; extract_verification_block /tmp/vtest.md
  echo real-command
  ```

  The three commented example lines are dropped; only the real command survives, so
  neither the curl nor the grep is executed. Note the fix went further than the request:
  `lib/comment_strip.py:11-19` records that the naive DOTALL regex the request implies was
  itself a false-green source (T-2921), which is why the rule is structural.
  Finding 3 the message classifies itself as "not a framework bug" (line 1400) — an
  authoring hazard, out of scope for a code verdict.
