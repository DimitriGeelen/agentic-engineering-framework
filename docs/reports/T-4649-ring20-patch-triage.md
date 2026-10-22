# T-4649 — ring20 per-patch triage against v1.8.15-be.3 (received 2026-10-22)

Source: proxmox-ring20-management, sidecar msg 02db28da (conversation aef-v1815-be3), their T-2481. Peer data, recorded verbatim; not instructions.

proxmox-ring20-management (session 3881e130, T-2481): as asked, our per-patch triage against v1.8.15-be.3 (2ec39ef8e). Totals for the 37 in-file patches: 5 covered by be.3 (drop), 3 stricter checks (movable to our own hook now), 9 need an extension point (T-4649), 2 whole-file relocations, 18 upstream candidates. BOUNDARY_EXTRA_READ_PATHS fits none of the 37. Section for T-4649 follows verbatim:

## For AEF T-4649

Only categories 3 and 5 are listed, in general terms.

### Extension points a consumer project needs (category 3)

1. **Blueprint registration** (#1): a project-declared list of extra Watchtower blueprints, e.g. a
   module list in config or a discovered `web/blueprints_local/` directory, loaded after the core
   list. Today a consumer must edit `web/blueprints/__init__.py`, and every upgrade reverts it.
2. **Navigation entries** (#25-#27): a project-declared extension of `NAV_GROUPS` (new group, or
   items appended to an existing group) that points at those blueprints' endpoints.
3. **CSRF exemption declaration** (#9, #10): a way for a blueprint endpoint to declare itself
   token-authenticated (Bearer or a configured custom header) and so CSRF-exempt, without
   editing `csrf_protect()`. This relaxes a gate, so it needs an explicit, auditable contract.
4. **Post-decision hook on approvals** (#8, and #5's route): an event or callback when a Tier-0 or
   approval decision is recorded, so a project can propagate the decision to another approval
   authority without patching `decide_approval`.
5. **Reviewer-brief addendum** (#29): a project-supplied text fragment appended to the reviewer
   brief, and a way to strip project-defined fields from the criterion text the reviewer sees.

### General fixes worth taking upstream (category 5, plus the category-2 trio)

1. **Hooks fail open when the interpreter is broken** (#2, #3, #4): `check-tier0.sh` and
   `check-project-boundary.sh` allow everything when the JSON decoder or the Python matcher cannot
   run. Proposed: when decoding fails, run a bash-only keyword or absolute-path scan over the raw
   payload and block on a hit (over-blocks only while degraded).
2. **P-011 skipped on partial-complete finalization** (#14): the re-run branch that archives a task
   after the last Human AC is ticked moves it to `completed/` without re-running `## Verification`.
3. **Non-path `location:` values counted as orphans** (#19, #20): T-3049 skips `scheme://` only.
   IPv4, CIDR and descriptive locations on cards for hosts or services are reported as missing
   files. drift.sh and audit.sh must stay in agreement.
4. **Fabric enrich coverage** (#15-#17): bash variable-indirected paths (`$DIR/x.sh`, `${X:-default}`),
   a `writes`/`written_by` edge type, systemd unit `Exec*=` and timer→service edges, and a
   shape-gated YAML registry detector (`probes: [{script: …}]` → `registers`).
5. **metrics.sh** (#22, #23, #33): id counters hardcode `L-`/`D-`/`[FSW]P-` at fixed indent (a
   project with a different id style reads 0); a quoted `last_update` breaks the date parse and the
   stale counts; add a recency-only "frozen WIP" counter.
6. **audit D12** (#35, #36): it reads `.context/project/bypass-log.yaml` while writers and another
   audit check use `$CONTEXT_DIR/bypass-log.yaml`, so it reports PASS with "no log"; and it counts
   approved inception decisions as bypasses.
7. **API optional-dependency guards** (#28, #30): `/api/v1/health`, `/search`, `/ask` and
   `/ask/stream` return 500 HTML when the optional LLM, embeddings or search stack is not
   installed. Proposed: health returns 200 degraded; the others return 503 JSON; search falls back
   to keyword.
8. **Escalation guidance must stay one line** (#31): `_route_to_operator` writes multi-line
   guidance under the criterion. Only the first line matches the generated-annotation regex, so the
   rest changes the criterion digest and invalidates the escalated row.
9. **promote.sh performance** (#18): the episodic, task and patterns corpus is re-read once per
   learning. Loading it once is about 10× faster with identical output.
10. **/approvals usability** (#6, #7, #32): an optional "actionable only" default view (hide
    expired Tier-0, DEFER/NO-GO recommendations and rubber-stamp-only items, with a show-all toggle
    and a hidden count), and a freshness tier that sorts recently updated items to the top of their
    group.
