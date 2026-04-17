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

## Key Questions (for phase 1 inception)

1. **Storage format**: markdown with frontmatter vs YAML-only vs SQLite?
2. **Parameterization**: just `{{var}}` or full template language? When does 
   simple substitution stop being enough?
3. **Scope**: prompts-for-other-agents only, or also prompts-for-yourself 
   (personal recipe book)?
4. **Sharing**: should prompts sync across fleet via TermLink push, or stay 
   per-project? (Cross-project learning suggests fleet-wide sync.)
5. **Lifecycle**: do prompts need review/approval like tasks do? Or just 
   capture-and-refine?
6. **UI surface**: list + detail pages, or also a composer for building new 
   ones with metadata fill-in?

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
