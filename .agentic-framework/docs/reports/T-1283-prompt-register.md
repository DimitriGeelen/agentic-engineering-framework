# T-1283: Prompt Register in Watchtower — Research Artifact

## Problem Statement

Reusable agent prompts (like cross-machine upgrade+test+fix-report, audit 
dispatch, fleet reauth guidance) are currently crafted ad-hoc in chat and 
lost when sessions end. There is no place to store, version, and copy 
canonical prompts for recurring operations.

## Origin

While reauthenticating with ring20-dashboard (.121) after a hub secret 
rotation, we composed a detailed prompt instructing the remote agent to 
upgrade framework + TermLink, run all tests, fix issues, and report back. 
The user asked to save this prompt for reuse — triggering this inception.

## Seed Prompt (the one that triggered the idea)

```
Task for ring20-dashboard agent (on .121):

Please upgrade both the Agentic Engineering Framework and TermLink on this 
machine, run the full test suite for each, fix any issues you find, and 
report back to 107-framework via TermLink.

STEP 1 — Upgrade framework:
  cd <your-consumer-project-root> && .agentic-framework/bin/fw upgrade
  (or if this IS the framework repo: cd /opt/999-Agentic-Engineering-Framework && git pull && bin/fw doctor)

STEP 2 — Upgrade TermLink:
  cd /opt/termlink && git pull && cargo install --path crates/termlink-cli --locked
  termlink --version

STEP 3 — Run framework tests:
  cd <framework-or-consumer> && bin/fw test all

STEP 4 — Run termlink tests:
  cd /opt/termlink && cargo test --all

STEP 5 — Fix all issues you hit. If they are:
  • Framework bugs -> create a task, fix, commit, push upstream via termlink remote push
  • TermLink bugs -> same pattern, push to termlink project on .107
  • Environmental -> document in a local task

STEP 6 — Report summary back:
  - Versions before/after
  - Tests pass/fail per suite
  - Issues + fixes
  - Learnings worth capturing
  Push via termlink remote push OR inject.

Proceed autonomously. Ask only on sovereignty gates or destructive actions.
```

## Proposal

A **Prompt Register** surface in Watchtower:

- Storage: `.context/prompts/*.md` (versioned, git-tracked) with YAML frontmatter 
  (name, tags, target-role, last-used, parameters)
- Watchtower page `/prompts`: list, view, copy-to-clipboard, edit
- CLI: `fw prompt list | show <id> | copy <id>` (copy emits to stdout for piping)
- Parameters: simple `{{placeholder}}` substitution when copying
- Provenance: link prompts to tasks where they were first used (episodic trace)

## Key Questions — Decisions (2026-04-17)

### Q1 — Storage format: markdown + YAML frontmatter
**Decision:** markdown file per prompt, YAML frontmatter for metadata.
Matches tasks/, handovers/, reports/. Human-readable, git-diffable, 
multi-line bodies stay clean.

### Q2 — Parameterization: `{{var}}` simple substitution
**Decision:** simple `{{var}}` only. Scored against the four directives:
- **Antifragility**: fewer failure surfaces (no sandbox escapes, no version
  quirks, no template-engine bugs)
- **Reliability**: deterministic regex substitution; predictable behavior
- **Usability**: 95% of prompt use cases are static text + a few placeholders;
  loops/conditionals would be overkill and add learning cost
- **Portability**: `{{var}}` is ~5 lines in any language. Jinja is Python-only,
  Handlebars is JS-only — engine choice locks the framework to a runtime.

Escalate to a template engine only if and when concrete need appears 
(inception: "add conditionals to prompts").

### Q3 — Scope: unified store with tags
**Decision:** one store, both agent-dispatch and personal-recipe use cases.
Differentiate by `kind:` frontmatter field (e.g. `kind: agent-dispatch`, 
`kind: recipe`, `kind: response-template`). Tags for further classification.

### Q4 — Sharing: fleet-wide from day 1 via TermLink sync
**Decision:** fleet-wide. Prompts are useful precisely because they're shared 
refinement across agents. Per-project would silo the value.

Implications:
- Sync protocol: `fw prompt push <hub>` / `fw prompt pull <hub>` / 
  `fw prompt sync` (bidirectional delta).
- Discovery: `fw prompt list --fleet` shows prompts from all known hubs.
- Conflict resolution: last-write-wins per prompt id (with git history as 
  audit trail); contentious edits surface as review items.
- Offline-first: all prompts still work when fleet is unreachable.

### Q5 — Lifecycle: capture-and-refine + unique IDs for cross-agent exchange
**Decision:** no approval gate (prompts are drafts, not decisions), BUT every 
prompt gets a stable unique ID for cross-agent referencing and refinement.

ID scheme: `<agent-id>/P-NNN` (e.g. `107/P-042`, `121/P-007`).
- `<agent-id>` = host-id from TermLink tagging (`host=107` → `107`)
- `P-NNN` = sequential within that agent
- Avoids collisions across fleet, human-readable, matches existing 
  host-tagging convention

Versioning: git commit SHA on the prompt file is the version. "Iterations" 
are git commits. Agents reference `107/P-042@abc123` for pinned version, 
`107/P-042` for latest.

Exchange flow:
1. Agent on .107 creates `107/P-042`
2. Syncs to fleet via TermLink
3. Agent on .121 pulls `107/P-042`, proposes refinement → creates 
   `121/P-042-fork` or edits in place
4. Edits propagate back via sync; git history captures who changed what

### Q6 — UI surface: list + detail + composer
**Decision:** full composer form in Watchtower phase 1.
- List page: filter by tag, kind, agent, last-used
- Detail page: rendered prompt + copy-to-clipboard + copy-with-params
- Composer form: fields for name, kind, tags, parameters, body. 
  Save → writes file, commits, syncs.
- Edit on detail page reuses composer.

## Scope Impact

Fleet-sync + cross-agent IDs + composer together make this a **larger** 
inception than the initial "save a prompt" framing:

Build units (rough decomposition for post-GO):
1. **B1** — Prompt file schema + `fw prompt create/list/show/copy` CLI 
   (local only, foundational)
2. **B2** — ID allocation + namespacing (`<agent-id>/P-NNN`)
3. **B3** — Watchtower list + detail + copy UI
4. **B4** — Watchtower composer form (create/edit)
5. **B5** — TermLink sync: `fw prompt push/pull/sync` + fleet discovery
6. **B6** — Conflict-resolution policy + review surface

Phased release: B1-B3 = usable MVP (single-agent). B4 = composer polish. 
B5-B6 = fleet sync. Can GO on the whole thing or GO on B1-B3 first.

## Success Criteria

- Can save a prompt in one `fw` command after drafting it in chat
- Can retrieve and copy a prompt in one `fw` command
- Watchtower shows the prompts with filter/search
- Prompts are cross-session durable (survive compaction, session end)
- Git-tracked (shareable, diffable, reviewable)

## Out of Scope (for this inception)

- Automatic prompt generation from conversation history (separate question)
- Cross-fleet sync (separate inception if wanted after MVP)
- Prompt execution runner (prompts stay text; execution is the agent's job)

## Dialogue Log

### Session 2026-04-17
- User: asked for a upgrade+test+fix prompt to send to .121 agent
- Assistant: drafted the prompt (see Seed Prompt above)
- User: "greta can we save this prompt somewhere ? --> incept have prompt 
  register on teh watchtower"
- Assistant: created this inception (T-1283) and captured the seed prompt 
  as the artifact that motivated it
