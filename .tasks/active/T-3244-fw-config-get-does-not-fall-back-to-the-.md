---
id: T-3244
name: "fw config get does not fall back to the registry default, contradicting documented 4-tier resolution"
description: >
  `fw config get KEY` returns empty and rc=1 for any key not explicitly written into
  .framework.yaml — including long-standing registered keys like PORT and CONTEXT_WINDOW.
  CLAUDE.md documents 4-tier resolution ending in "hardcoded default"; the CLI implements
  only three, so callers must supply tier 4 themselves.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [bug, config]
components: [lib/config.sh]
related_tasks: [T-3243, T-2842]
created: 2026-09-01T10:22:51Z
last_update: 2026-09-01T10:22:51Z
date_finished: null
---

# T-3244: `fw config get` does not implement tier-4 registry fallback

## Context

Found while wiring `RESTART_WINDOW` in T-3243. CLAUDE.md §Configuration states:

> 4-tier resolution: explicit CLI flag > `FW_*` env var > `.framework.yaml` > hardcoded default.

`fw config get` implements the first three. Measured on this repo:

```
bin/fw config get PORT                    -> (empty)  rc=1
bin/fw config get CONTEXT_WINDOW          -> (empty)  rc=1
bin/fw config get MAX_RESTARTS            -> (empty)  rc=1
bin/fw config get INCEPTION_COMMIT_LIMIT  -> 15       rc=0   # set in .framework.yaml
```

All three of the rc=1 keys are present in `FW_CONFIG_REGISTRY` **with defaults**. The
registry knows the answer and the CLI does not return it.

## Why this is worth filing rather than shrugging at

The failure is quiet and the workaround is already load-bearing. CLAUDE.md's own
Watchtower-port guidance is written as:

```
bin/fw config get PORT 2>/dev/null || echo 3000
```

— i.e. the documented usage already carries an external tier-4, which reads as defensive
belt-and-braces but is in fact the only reason that line works at all. Any caller who
trusts the documented resolution and omits the `|| default` gets an empty string, and an
empty string is a plausible-looking value in shell. That is the same false-green shape as
T-3241: a lookup that cannot answer is indistinguishable from a lookup that answered
"nothing".

`fw config list` similarly shows only "Custom settings" — the keys someone set — so a
registered key with a default is invisible at both surfaces.

## Acceptance Criteria

### Agent

- [ ] `fw config get KEY` returns the registry default (rc=0) for a registered key that is
  absent from `.framework.yaml`, verified for at least `PORT`, `CONTEXT_WINDOW`,
  `MAX_RESTARTS` and `RESTART_WINDOW`.
- [ ] `fw config get KEY` still returns rc=1 for a key that is in neither
  `.framework.yaml` nor the registry — the "unknown key" case must stay distinguishable
  from the "known key, default value" case.
- [ ] `FW_<KEY>` env and `.framework.yaml` continue to outrank the default (precedence
  order unchanged), pinned by test.
- [ ] Existing `|| echo <default>` call sites keep working — the change must not alter
  behaviour for keys that ARE set.
- [ ] Decide and record whether `fw config list` should show registered-but-unset keys
  with their defaults, or keep the "Custom settings" framing. Either is defensible; the
  point is that it is chosen rather than inherited.

## Verification

bash -n lib/config.sh
# Remaining verification commands to be written with the fix.

## RCA

**Symptom.** `fw config get PORT` returns nothing with rc=1 despite `PORT|3000|…` being in
`FW_CONFIG_REGISTRY`, contradicting the 4-tier resolution CLAUDE.md documents.

**Root cause.** To be confirmed at fix time — `_fw_registry_default` exists in
`lib/config.sh:56`, so the lookup path is present but is evidently not consulted by the
`get` subcommand's miss branch.

**Why structurally allowed.** The workaround (`|| echo <default>`) is idiomatic enough
that every call site carries it, so the missing tier never produced a visible failure.
A defect whose workaround is indistinguishable from good defensive style generates no
pressure to fix it.

**Prevention.** A test asserting tier-4 for a key deliberately absent from
`.framework.yaml`, which is the only configuration in which the defect is observable.
