# T-4965 — scoped, operator-owned access grants outside the project

**Status:** inception, recommendation DEFER until a design draft and an independent review exist.
**Requested by:** 050-email-archive (Pen, their T-2500; msgs d7a70b98, 447fb7f8), on behalf of their operator.
**Their design doc:** Pen `docs/reports/T-2500-nas-access-grants.md` (in 050; not read from here, by rule).

## Requirements (050's operator, 2026-11-01, as relayed)

- Grants are per directory and recursive. Three levels:
  1. **read:** list and read.
  2. **create:** read; create files and folders; modify or rename **only what the agent itself created**. Never touch operator files.
  3. **create-project:** create new directories under a given parent; each new directory gets level 2.
- **Delete is never standing.** Every delete is a Tier 0 approval, per action.
- The grant file is the **operator's**; the agent can never edit its own grants (the gate refuses).
- A **created-by-agent ledger** and a **write audit log**.
- Grants are visible in `fw doctor` and Watchtower.
- A **general framework pattern**, not NAS-only: shares, other projects, tool directories.

Today `check-project-boundary.sh` offers only `BOUNDARY_EXTRA_READ_PATHS` (a whole path, read-only). Level 1 works through it already.

## Mount facts (050, measured 2026-11-01, read-only)

- The share is an sshfs (FUSE) mount of a Synology NAS. It is mounted with the NAS admin account, options `rw,nosuid,nodev,relatime,user_id=0,group_id=0,allow_other`.
- **No id mapping:** every file and directory shows `root:root`, uid 0, mode 777, whoever created it. File ownership cannot tell that the agent created a file, so level 2 needs the created-by-agent ledger. A dedicated NAS account per agent (ring20 T-2486) would only help if the mount mapped ids.
- Every write through the mount carries NAS-admin rights, so **the boundary hook is the only fence today.**
- Rename and mtime behaviour: **not measured**. 050 offers an operator-run probe (create, rename, `touch -d`, check mtime, delete one temp file in a scratch directory).

## Tests offered by 050

None exist yet. 050 would contribute cases:
- a write outside the grant is blocked;
- modifying an operator file under a level-2 grant is blocked;
- `rm` is blocked without Tier 0;
- the agent cannot edit the grant file.

## Known limits to carry into the design (from Tier 0 / Tier 1, CLAUDE.md)

- The hooks see only the typed command or the Write/Edit target. A script, `make` or `python3 x.py` writes wherever it wants. So a grant fences **typed** writes, the same scope boundary as Tier 0 (T-2742). The design must say this plainly rather than imply a sandbox.
- Every agent runs as the same OS user as the operator. A grant file that "only the operator may edit" is protected by the hook against typed edits, not against a script, which is the same residual as T-3581.
- On this share the ledger is the only proof of "created by the agent". If the ledger is wrong or lost, level 2 must fail closed: unknown files are treated as the operator's.

## Next

1. Design read: `check-project-boundary.sh`, the Tier 1 write scanner (`check-active-task.sh` write patterns), and how Tier 0 approves a delete on an outside path.
2. Draft the design here. Ask whether 050's rename/mtime probe is needed for the ledger design (a rename moves a ledger entry; mtime is not trusted for anything).
3. Independent review by two seats. Host names and addresses are left out of the brief.
4. Operator GO/NO-GO; then build slices as separate tasks, with 050's test cases as acceptance tests.
