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

## Model change (050's operator, 2026-11-01, msg ea6861ca)

The main fence moves to the NAS. The framework's grants become the **second layer**.

- **One NAS account per access profile:** `pen-read`, `pen-create` (create, plus modify its own through the NAS's CREATOR OWNER), `pen-write`, `pen-delete`.
- **Three standing mounts on the host:** read, create and write. `pen-delete` has **no mount**: its credential sits in the secrets store and is fetched per action, only after a Tier 0 approval.
- For each directory the agent uses the account that matches its grant. The NAS then enforces least privilege, **also against scripts and make**, which closes limit (1) above for those mounts.
- "Created by the agent" becomes the NAS-side owner (`pen-create`). The ledger becomes an audit aid instead of the only proof. Fail-closed still applies.
- The accounts and mounts are requested from Ring20 Manager (their T-2486).

**Unchanged, and it limits the model:** the operator's admin mount stays; it is his own access. The agent runs as root on the same host, so for that path **the hook remains the only fence**. The design must say so plainly.

**What 050 asks of the design now:**
1. The grant file maps directory → profile, and the profile → mount.
2. The hook blocks typed writes to the admin mount and steers each write to the matching profile mount.
3. The Tier 0 flow releases the delete credential for exactly one action.
4. The audit log.

Item 3 is the most sensitive point: a credential handed to an agent process for one action. It needs the closest look in the external review.

**050's preference on ask 3 (msg 24b47da4):** the **runtime runs the approved delete itself**. The agent never holds the delete credential, and the approval binds to exactly one path. That still meets their operator's rule (every delete is Tier 0) and closes the credential-lifetime gap. Their operator has the final word after the design and the review. No further asks until the draft.

**Refined model (050's operator via Ring20 Manager T-2581; msgs 95d746a2, c040f1e9):**
- **Three accounts:**
  - `pen-read`: list and read.
  - `pen-create`: read, create, and modify or rename only its own files (CREATOR OWNER); no delete.
  - `pen-delete`: deletes only what the agent made, per action with the operator's permission.
  - `pen-write` is **dropped**; the agent never changes operator files.
- **Two standing mounts:** read and create, both SMB/cifs. `pen-delete` has no mount.
- The `pen-delete` credential goes into a **separate secrets project** the agent's identity has no role on, so the agent cannot read it. How one approved delete gets it is ours to design: **the runtime acts, not the agent**.
- For the grant file: **two standing levels (read, create)** plus the Tier 0 delete flow; there is no write level.
- Nothing exists yet; account creation waits for their operator. Their T-2500 is GO; follow-up is their T-2502.

**Operator decisions relayed by 050 (msgs dea9b6b7, e15d95fa):**
- **Rename is not delete.** The create level may rename and move the agent's OWN files and folders. Only a real delete needs Tier 0, so the design's grammar must not classify `mv` or a rename of own files as a delete. Ring20 is testing whether the NAS allows rename without a delete right.
- **One exception to "every delete is Tier 0": temporary items.** A file or directory the agent declares temporary AT CREATION, named `PEN-TMP_<YYYYMMDD>_<name>`, may be deleted by the agent without approval (a directory with its contents). The framework layer must enforce:
  1. the ledger records the item as created by the agent with `temp=true` at creation (the prefix alone is never enough);
  2. renaming INTO the prefix is refused;
  3. renaming OUT of the prefix is refused (keep content by copying under a normal name);
  4. every temporary delete is audit-logged.
- On the NAS the create account has no delete right, so the runtime performs a temporary delete through the delete route, as for an approved delete, with the ledger check standing in for the operator's approval. 050 suggests a configurable prefix per project as the general pattern.

**Rename probe:** on hold; 050 will run it against the `pen-create` mount once that exists.

## Design read (2026-11-01)

What exists today, read from the code and probed with the hook itself (a scratch project with `BOUNDARY_EXTRA_READ_PATHS: /srv/nas-share`):

| Command | Result today |
|---|---|
| `cat /srv/nas-share/a.txt` | allowed (extra read path) |
| `rm /srv/nas-share/a.txt`, `rm -f …` | refused |
| `mv /srv/nas-share/a /srv/nas-share/b` | refused |
| `cp x /srv/nas-share/b` | refused |
| `rm /srv/other/a.txt` | refused |

- **Write/Edit tool** (`check-project-boundary.sh`, Write/Edit gate): allowed only under the project, `/tmp`, the account's `~/.claude`, and sibling worktrees. Everything else is refused.
- **Bash** has three write passes. Pass 1 (`write_ops`, `_tee_targets`, `_write_verb_targets`) covers redirects, tee, cp/mv/install/ln/rsync/dd, sed/perl -i, chmod/touch/mkdir. Pass 4 refuses outside paths that are not on the read allowlist; the extra read paths are exempt from that pass only. Pass 5 (`lib/shell_write_scan.py`) tokenises the command the way bash reads it and collects every write target. This is why `rm` on an extra read path is refused, even though pass 1 has no `rm`.
- **What is missing for grants:** every pass answers "is this a write?", none says "which kind". The scanner returns targets, not operations. Level 2 needs each target classified as **create** (the path does not exist), **modify** (it exists), **rename** (source and destination), **delete** or **metadata** (chmod/touch). That classification is the core new code.
- **Scope limit (unchanged, CLAUDE.md §Tier 0):** all of this sees only the typed command or the Write/Edit target. A script, `make` or `python3 x.py` writes wherever it likes. On the profile mounts the NAS enforces the limits even against scripts (the reason for 050's model change). On the operator's admin mount, the hook is the only fence.

## Design draft (2026-11-01, for review)

### 1. The grant file

- **Location:** `policy/access-grants.yaml`, committed, operator-owned.
- **Guard:** the same two layers as Human-AC ticks (T-1731, T-3695). (1) A PreToolUse rule refuses Write/Edit, and any Bash command whose write targets include the file, under agent control. (2) An audit check FAILs on any commit that changed the file without operator provenance (`--i-am-human` CLI or Watchtower). The first layer stops accidents; the second makes a script edit visible. Neither stops a determined same-user process (the T-3581 residual), and the report says so.
- **Shape:**
  ```yaml
  grants:
    - path: /mnt/pen-create/Projects/Archive   # recursive
      level: create          # read | create | create-project
      via: /mnt/pen-create   # the profile mount writes must go through
  temp_prefix: PEN-TMP_      # per project; with the date it forms PEN-TMP_<YYYYMMDD>_<name>
  never_write: [/mnt/nas-admin]   # the operator's own mount: no typed agent write, ever
  ```
- **Validation:** paths absolute, no `..`, no symlink in the path, each `path` under its `via`. Grants may not overlap with different levels. `never_write` wins over any grant.
- `BOUNDARY_EXTRA_READ_PATHS` stays as it is. A `read` grant is the same thing kept in the operator-owned file, and doctor shows both.

### 2. What each level allows (typed actions)

| Action on a path under the grant | read | create | create-project |
|---|---|---|---|
| list, read | yes | yes | yes |
| create a file or directory (target does not exist) | no | yes, recorded in the ledger | yes, under the parent only; the new directory then counts as a `create` grant |
| modify an existing file | no | only if the ledger says the agent created it | same as create, inside the new directory |
| rename or move own item, within the grant | no | yes, if the source is in the ledger, the destination is inside a create-level grant, and the move neither adds nor removes the temp prefix | same |
| delete | no | **never standing**: through the delete route (§4) | same |
| chmod, chown, touch -d | no | no | no |
| anything the scanner cannot resolve (`$VAR`, a glob with no match, inline code mentioning the path) | refused | refused | refused |

The fail direction is refusal, everywhere. When the ledger has no entry for a path, the file belongs to the operator.

### 3. The created-by-agent ledger

- **File:** `.context/grants/created.jsonl`, append-only (one line per create, rename or delete, each with path, kind, task, time and `temp: true|false`).
- **Who writes it:** the gate cannot write after the fact, so it is split in two. The PreToolUse gate writes a *pending* line for each create target it allowed. A PostToolUse hook confirms the lines whose paths now exist and drops the others. A rename moves the entry (old path closed, new path opened). This is where 050's rename probe matters: if the NAS reports a rename as delete plus create, nothing changes on our side, because the ledger keys on the path as typed.
- **On 050's mounts** the NAS (CREATOR OWNER on `pen-create`) is what actually enforces "modify only own" against scripts. There the ledger is an audit aid plus the source for temp items and delete scope. On a mount without such accounts, the ledger is the only proof, so a lost or torn ledger means nothing counts as the agent's (fail closed).
- **mtime is used for nothing.**

### 4. Deletes

**4a. Approved deletes (every non-temporary delete).**
1. The agent runs `fw grants delete <path>`. The command checks that the path is in the ledger as agent-created and still under a grant, then records a request.
2. The request becomes a Tier 0 action `grant-delete {path}`, keyed exactly as typed, like `recursive-delete` (T-3593). One approval covers one path.
3. After approval, the **runtime** deletes; the agent never holds the delete credential (050's preference, msg 24b47da4).

**4b. Temporary items.**
- Created through `fw grants mktemp <dir> <name>`, which builds `PEN-TMP_<YYYYMMDD>_<name>` and writes the ledger line with `temp: true` at creation. A file that merely carries the prefix is not temporary.
- Renaming into or out of the prefix is refused.
- `fw grants delete` on a ledger-temp item runs without approval, through the same runtime route, and is logged.

**4c. The hard part, stated plainly.** On 050's host the agent runs as root. Any credential a *local* runtime can read, the agent can read too. The same holds for any approval record it can sign, which is the T-3581 residual. So a local runtime cannot give real separation for the `pen-delete` credential. Two honest options:

- **(a) Off-host executor (recommended).** The framework only produces the approved, single-path request. Something the agent cannot act as performs the delete, using a `pen-delete` credential that only it can read: Ring20 Manager (their T-2486/T-2581) or a NAS-side task. The executor should also confirm the operator's approval itself (its own UI, or a signed operator action), not trust our approval file.
- **(b) Local runtime.** It holds the credential in a store the agent's identity has no role on. That protects against typed misuse and makes every use visible in the audit log. It does not protect against a root process on the same host, and must be documented as such.

### 5. Visibility

- `fw doctor` lists each grant, its level and its `via` mount, and WARNs when a `via` mount is absent or a `never_write` root is writable.
- Watchtower `/config` (or a small `/grants` page) shows the same plus the last ledger lines. Read-only; changes go through the operator's door.
- Audit log: `.context/grants/audit.jsonl` holds every allowed write, refused write and delete request, with its outcome.

### 6. Acceptance tests (050's four plus ours)

1. A write outside every grant is refused.
2. Modifying an operator file under a create grant is refused (no ledger entry).
3. `rm` under a grant is refused without the delete route; `fw grants delete` on a non-ledger path is refused.
4. The agent cannot edit `policy/access-grants.yaml`: Write/Edit and Bash are refused, and audit FAILs a commit without operator provenance.
5. A create is recorded, and a modify of that file is then allowed; after a rename, the old path is refused and the new one allowed.
6. Renaming into or out of the temp prefix is refused; a file named with the prefix but not created through mktemp is not deletable as temp.
7. An unresolvable target (`> "$X"`, `cp * /mnt/…`) under a grant is refused.
8. Any typed write to a `never_write` root is refused, even when a grant covers a path below it.

### 7. Build slices (after GO)

1. **Operation classification** in `lib/shell_write_scan.py`: kinds for each target (create / modify / rename / delete / metadata), with tests. This is useful on its own and changes no gate.
2. **Grant file, validation and guard** (the PreToolUse rule plus the provenance audit) and the read level. Doctor visibility.
3. **Create level and ledger:** pending line in PreToolUse, confirm in PostToolUse, the rename move, modify-own. Tests 1, 2, 5, 7, 8.
4. **Delete route and temp items:** `fw grants delete|mktemp`, the Tier 0 action `grant-delete`, and the hand-off to the executor chosen in §4c. Tests 3 and 6.
5. **create-project level and the Watchtower view.**

### 8. Open questions for the operator (050's)

1. §4c: off-host executor (a) or local runtime (b)? The design recommends (a), and it needs Ring20 Manager's agreement.
2. Does the grant file live in the project (`policy/`, committed, so it shows in git history), or outside it in an operator-only path the agent cannot write at all? Outside is stronger, but the boundary hook would then need to read a file outside the project.
3. Is `chmod`/`touch -d` on own files needed? The draft refuses metadata changes.
4. The rename probe: still useful to confirm the NAS allows a rename without a delete right, but the ledger design does not depend on its answer.

## Review, seat 1 (opencode, 2026-11-01): sound with fixes

The full text is in `docs/reports/T-4965-review-opencode.md`. Seat 2 (codex) could not run (usage limit until 22:02) and will be added. The reviewer confirmed the layering, the off-host executor and the fail-closed ledger, and found the delete route as drafted unsound. Findings, and what changes:

1. **The share is reachable by paths the draft never names.** Examples: a new `mount` under `/tmp`, `smbclient`, or `ssh` to the NAS. **Accepted.** Under any grant, the scanner treats `mount`, `umount` and `fusermount` as writes. Typed network clients aimed at the NAS are refused (they are named in the scope limits). `fw doctor` compares `/proc/mounts` with the grant `via` list and alarms on any other mount of the same source.
2. **The ledger and audit log are themselves editable.** An agent could append a temp entry for an operator file. **Accepted. This changes the design's core:**
   - `created.jsonl` and `audit.jsonl` join the guarded set (the T-3695 leg);
   - the delete authority is never the local ledger. It is the NAS-side owner, which the executor checks itself;
   - the temp-item route exists only on mounts with NAS-side ownership.
3. **The ledger's soundness.** **Accepted:**
   - pending lines are bound to the tool call's `tool_use_id`;
   - entries are confirmed by NAS owner (or content hash), not by existence;
   - entries are keyed on the resolved path, case-folded on cifs;
   - an entry closes as soon as its path is seen missing;
   - ownership is re-checked at every decision.
4. **Archive extractors and script-created files skip the ledger.** `tar -x` under a grant creates members the ledger never sees, and `../` members can land outside the grant. **Accepted:**
   - extractors are refused under grants (stage the archive in the project, then copy);
   - a Tier 0 approval may delete a path that is not in the ledger (the operator, not the ledger, is the authority).
5. **A hard link can make an operator file look agent-created.** **Accepted:** `ln` sources are classified; a hard link is refused unless its source is in the ledger as agent-created.
6. **§4c is right, but the executor's spec was incomplete.** The executor must check all of the following itself:
   - the operator's approval, over its own channel;
   - NAS-side ownership of the exact path;
   - every check again at execution time (rename TOCTOU);
   - symlinks resolved on the server;
   - a single-use request bound to a nonce.

   **Accepted, written into §4c(a).** Option (b), a local runtime, is withdrawn: a root agent can also watch the local process using the credential.
7. **The grant file's guard has gaps.**
   - It checked only commits.
   - It missed `git checkout/restore/stash/apply` on the file.
   - `fw config set BOUNDARY_EXTRA_READ_PATHS` stays a way for the agent to widen its own read access.

   **Accepted:**
   - every hook fire checks the file's digest against HEAD (an uncommitted change means no grants apply);
   - the guarded verb set is extended;
   - read grants move into the operator-owned file, and `BOUNDARY_EXTRA_READ_PATHS` becomes operator-only, which is a separate change that needs the operator's yes.
8. **Slice gaps.** **Accepted:**
   - `never_write` and the steering go into slice 2;
   - the audit log goes into slice 3;
   - mount hygiene (finding 1) goes into slice 2, before the create level;
   - steering refuses with a message; it never rewrites paths.

**Net effect:** the framework's role in deletes shrinks to recording the request and getting the approval. An off-host executor that checks NAS ownership itself does the delete. On a mount without NAS-side ownership, only the read and create levels are offered.

## Review, seat 2 (codex, 2026-11-01): unsound as drafted

Full text: `docs/reports/T-4965-review-codex.md`. Codex agrees with opencode on the ledger, links, the grant-file guard and the executor, and goes further. New points:

- **C1. A temp directory can swallow permanent content.** Move an own permanent file into `PEN-TMP_…/`, or let the operator drop a file there, then delete the temp directory. **Accepted:** temp status is checked for every descendant; moves across a temp boundary are refused; a temp delete refuses if any descendant lacks a trusted temp record.
- **C2. Temp provenance and delete authority cannot come from the root agent's host at all.** A forged local row can still steer a remote delete. A path-keyed approval can be swapped to other data before execution (`tier0_action.py` keys `recursive-delete` on spelling, not object identity). **Accepted:**
  - temp status is recorded by the executor at creation (an executor-side mktemp), not by our ledger;
  - the executor authenticates approval, share, grant, ownership, object identity and recursive scope itself, with expiry and single use.
- **C3. Pending-then-exists cannot prove authorship.** **Accepted:** create-level authorship can only be trusted where the NAS records the creating account. Our ledger is an audit aid and is never authority. Script-created objects without such provenance count as the operator's.
- **C4. The scanner already misses things the draft promises to refuse.** Codex probed it read-only:
  - `p=…; echo x >> "$p"` yields no checked target;
  - so do `tar -x … -C` and `unzip -d`;
  - boundary mode rejects an unresolved target only when `ctx.mentions` holds;
  - a bare relative command in a grant cwd can skip the prefilter.

  **Accepted as a defect class of its own:** in boundary mode, an unresolved write target must be refused outright. That gap exists today whether or not grants are built, so it is filed as a separate task, not folded in here.
- **C5. Copy and rename have effects beyond their operands.** `cp -r` into an owned directory can overwrite operator descendants; `mv own operator-file` replaces it; a cross-mount move is a copy plus an unlink. **Accepted:** under a grant, recursive copies are refused, a move or copy onto an existing path is refused unless the target is the agent's own, and cross-filesystem moves are refused.
- **C6. Links created after validation.** **Accepted (as opencode 5):** `ln` and `ln -s` are refused under a grant; mount identity is checked, not only the mountpoint.
- **C7. The grant file can be replaced through its directory, git, or by turning off the hook.** **Accepted:** the guard covers the file's ancestors and git-mediated replacement. The effective policy is checked against a version the operator committed. Disabling hooks is outside what any hook can stop: the same residual as T-3581, named.
- **C8. Isolation comes first.** While the root agent keeps the admin mount, a script bypasses every profile ACL. **Accepted:** the honest prerequisite for real enforcement is that the agent cannot reach the admin mount (a separate account or VM, outside this framework). The NAS tests (ACLs, rename vs delete, mount identity) move before slice 3. create-project is corrected to directories only.

**Where this leaves the design.** The framework layer can honestly offer:
- fencing of typed commands;
- steering to profile mounts;
- refusal of opaque forms;
- visibility.

Authority over deletes, temporary items and "created by the agent" must live off the host (the NAS and an executor), because nothing the root agent's host records can be trusted. Real protection of operator data also needs the agent kept away from the admin mount, which is 050's host decision. Recommendation for the inception: **GO for the reduced framework layer (read and create levels, typed fencing, steering, visibility); NO-GO for any framework-side delete or temp authority**, which instead becomes a request to the executor's owner (Ring20 Manager).

## 050's operator answers and scope change (msg 34998006, 2026-11-01)

- **(a) Executor:** Ring20 Manager. **(c) chmod/touch on own files:** not needed; it stays refused. **(b) Removing the agent's admin-mount access:** still open; the admin mount stays for now.
- **Scope change, decided by their operator after Ring20 (their T-2581) went live:**
  - `pen-create` may rename AND delete its OWN files without per-action approval. This is safe because the NAS pushes a phone notice to the operator for every delete or rename by `pen-create`, and the share has btrfs snapshots (hourly for 48 h, daily for 14 days).
  - There is **no** `pen-delete` account, **no** Tier 0 delete flow and **no** temp-prefix rule. The NAS is the authority for ownership and deletes (review finding 2 of both seats).
- **Live mounts:** a read-only mount of the whole share, and a create mount over two project directories, both proven over SMB by Ring20.
- **What remains for AEF** is exactly the reduced layer:
  1. an operator-owned grant file. Typed reads go through the read mount; typed writes, renames and deletes go through the create mount, and the NAS judges ownership;
  2. refusal of typed writes to the admin mount;
  3. doctor and Watchtower visibility.
- **Consequence for the design:** §3 (our ledger), §4 (delete route, temp items, executor) and slice 4 are dropped. On the create mount the hook allows typed create, modify, rename and delete, because the NAS enforces ownership against both typed commands and scripts. The opaque-form refusals stay (variables, links, extractors, recursive copies across the boundary), as do the `never_write` admin root and the grant-file guard. Today their boundary hook blocks even `ls` on the read mount; the operator can bridge reads with `BOUNDARY_EXTRA_READ_PATHS`, and writes have no sanctioned path until the layer lands.

## Next

1. ~~Design read~~ and ~~draft~~: done above (2026-11-01).
2. Independent review by two seats. Host names and addresses are left out of the brief.
3. Send 050 the draft (§4c and §8 first) and record their operator's answers here.
4. Operator GO/NO-GO; then build slices as separate tasks, with 050's test cases as acceptance tests.
