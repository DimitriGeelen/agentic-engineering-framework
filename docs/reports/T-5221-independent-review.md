# T-5221 — independent code review

Reviewer: independent agent (`t5221-review`); I did not write this code.
Scope: commits `7ef993ddc..56b7a6e60` (`git log --grep '^T-5221'`). I looked only for correctness bugs.
Files: `lib/render_task.py`, `agents/task-create/create-task.sh`, `agents/task-create/create-batch.sh`,
`lib/task-create-rules.sh`, `lib/idalloc.sh`, `lib/arc.sh` (instantiate), `lib/arc_instantiate.py`, `bin/fw`.

**Overall: AMBER.** No RED findings. Create-task's output is unchanged for ordinary input: the goldens pass, and
validation messages and exit codes are the same (`error`+`return 1` and `|| exit 1` reproduce `die`).
`bats tests/unit/t5221_create_batch.bats` passes 13/13 (arc + 13 tasks, 25 views: 992 ms).
Counts: RED 0, AMBER 4, NOTE 8.

Method note: the framework's text gates (Tier 0 `git commit` pattern, the Human-AC tick guard on `cp … .tasks/`)
refused my shell setup of tmp repos. So I probed `render_task` / `arc_instantiate` directly from Python, using
neutral directory names, and relied on the bats suite for end-to-end runs.

## Findings

### 1. AMBER — `lib/render_task.py:264-275` — create-task now needs hard-link support
`write_exclusive` always goes through `os.link(tmp, path)`. Before this change, create-task wrote the file with
`open(path, 'w')`. On a filesystem without hard links, every `fw task create` / `fw work-on` now fails with
`render_task: write failed: [Errno 1/95]`, and the id is burned. Examples of such filesystems: vboxsf, FAT/exFAT,
some CIFS mounts, some FUSE/sync folders, and older Docker-Desktop bind mounts. The same failure (EXDEV) happens when
`.tasks/active` is a symlink to another filesystem, because `.writing/` is under `.tasks/`. This affects consumer
projects, not only this repo.
**Fix:** on `EPERM/EOPNOTSUPP/ENOTSUP/EXDEV/EMLINK` from `os.link`, fall back to
`os.open(path, O_WRONLY|O_CREAT|O_EXCL)` + write + fsync. This keeps exclusivity and loses only atomicity. Add a
test that monkeypatches `os.link` to raise EPERM.

### 2. AMBER — `lib/arc_instantiate.py:149-165` + `lib/render_task.py:63-74` — parameter values break the tags frontmatter
Placeholders are substituted into `tags`/`related` items with no check. The items are then comma-joined
(`parse_spec`), re-split, and written raw into a YAML flow sequence. Probed with the fixture's own pattern
`tags: [scan, "{region}"]`:
- `--param region='west]'`, `"'x"` or `'x # y'` → the task frontmatter does not parse (`yaml.ParserError`).
  create-batch and instantiate report success, and every created task file is corrupt.
- `region='k: v'` → the tag becomes the mapping `{k: v}`.
- `region='a, b'` → the tag silently becomes two tags.

`fw task create --tags` has the same weakness, but there the operator types the value. Here a parameter flows into
13 files at once, and create-batch claims to validate every entry first.
**Fix:** in `parse_spec` (so both create-batch and instantiate get it), refuse tag and related items that contain
`,[]{}#:'"`, a newline, or a leading `-`/`&`/`*`/`!`/`|`/`>`/`%`/`@`. Alternatively, emit each item json-quoted (that
changes create-task's bytes, so only for the batch path). Also check `related` items against `^T-\d+$`.

### 3. AMBER — `lib/render_task.py:293-296` (with `:266`) — the `rmdir` of `.writing/` races a concurrent writer
`write_entries` ends with `os.rmdir(tmpdir)`. `write_exclusive` does `os.makedirs(tmpdir)` and then `open(tmp,'x')`.
create-batch writes without the `task-id-allocation` lock: `fw_id_allocate` takes the lock and releases it again. So
these can interleave: writer B runs `makedirs` → writer A runs `rmdir` (the directory is empty at that instant) →
B's `open` raises `FileNotFoundError`. The result is `render_task: write failed` and a burned id. Possible pairs: a
create-task beside a batch, or two batches (parallel workers). The window is microseconds, but this is the path every
task creation takes.
**Fix:** drop the `rmdir`, keeping `.writing/` permanently (see 7), or retry `makedirs`+`open` once on
`FileNotFoundError`.

### 4. AMBER — `lib/arc.sh:2709-2710` — `sed -i` is GNU-only, and the anchor is reported even when it was not set
`sed -i "s/^anchor_task:.*/…/" file` fails on macOS/BSD sed, which takes the next argument as the backup suffix. The
return code is not checked, so line 2710 still prints `anchor_task: T-…` and instantiate returns 0 while
`anchor_task:` is still empty. The repo already has a portable `_sed_i` (`lib/compat.sh:31`, `lib/paths.sh:494`).
**Fix:** use `_sed_i` (or a small python edit), check the result, and print the line only on success.

### 5. NOTE — `lib/render_task.py:63-74` — `format_yaml_array` is not byte-identical to the old bash version
The old version piped each item through `xargs` and read only the first line (`read -ra` with no `-d`). Compared
directly:
- `it's,x`: old `[x]` (xargs error dropped the item), new `[it's, x]`
- `"q",y`: old `[q, y]`, new `["q", y]`
- `a\b`: old `[ab]`, new `[a\b]`
- `-n,z`: old `[z]`, new `[-n, z]`
- `"a\nb,c"`: old `[a]`, new `[a b, c]`

Most of these are improvements. But a tag that starts with a quote (`--tags "'foo"`) used to be dropped and now
produces unparseable frontmatter (`['foo]`). The claim "unchanged in output" holds only for plain tags. Covered by the
fix in 2 if it is applied to `write-one` as well.

### 6. NOTE — `lib/render_task.py:116,134` — newlines in names inject body content (pre-existing, new surface)
A name containing a newline goes verbatim into the body heading `# T-N: <name>`. Probe:
`--param m=$'oslo\n## Acceptance Criteria\n- [x] done'` used only in a task name yields a pre-ticked criterion
section. create-task already allowed this, but instantiate parameters and spec names now reach it in bulk.
`task_rule_name` could refuse control characters.

### 7. NOTE — `.tasks/.writing/` is not gitignored
`git check-ignore .tasks/.writing/x` reports no ignore rule. A writer killed between `open` and `unlink` leaves
`<pid>-<hex>.T-N-slug.md` there until the next write sweeps it. A `git add -A` / `git add .tasks` (handover, commit
helpers) in between commits it.
**Fix:** add `.tasks/.writing/` to `.gitignore`, and to the consumer `.gitignore` that `fw init`/`fw upgrade`
manages.

### 8. NOTE — `lib/render_task.py:240-261` — `_sweep` can delete a live writer's temp file in another PID namespace
`os.kill(pid, 0)` raises `ProcessLookupError` for a live writer in another container that shares the bind mount.
The sweeper then unlinks that writer's temp file, and the writer's `os.link` fails. Rare. Including a hostname or
namespace marker in the temp name, or only sweeping files older than N minutes, would avoid it.

### 9. NOTE — `lib/idalloc.sh:242` — the multi-row ledger append is no longer one row per write
create-batch calls `fw_id_ledger_created` without the allocation lock. A 100-row append is about 5.8 KB, more than
bash's stdout buffer, so it can be split into several `write()`s. Those writes can interleave with another process's
row and leave a torn JSONL line. Low probability.
**Fix:** take the allocation lock around the append, or emit it from python in one `os.write`.

### 10. NOTE — `agents/task-create/create-batch.sh:84` — `_arc_known` accepts path components in `arc_id`
`[ -f "$ARCS_DIR/$a.yaml" ]` accepts `arc_id: templates/municipality-scan` or `../project/decisions`. Those resolve
to existing YAML files that are not arcs, and the value is written into the task. The `check-arc-id` hook would
refuse the same value under Write/Edit.
**Fix:** require `^[a-z][a-z0-9-]{1,63}$` (as in `_arc_validate_id`) or `^arc-[0-9]+$` before the file test.

### 11. NOTE — `lib/arc.sh:2697` — removing the arc on failure can free its `arc-NNN` for reuse
When no task is created, the arc file is deleted. `_arc_next_numeric_id` uses the maximum id, so if this arc held
the maximum, the next `fw arc create` reissues the same `arc-NNN`. That contradicts the D-Immutability axiom ("slots
are NEVER reused"). Nothing references the id yet, so the impact is small; mark the arc `abandoned` instead of
deleting it if the axiom must hold strictly.

### 12. NOTE — minor
- `create-task.sh:430`: `INCEPTION_TEMPLATE` is no longer set, so when the framework's fallback template was used,
  the "Fix the template at:" hint names the wrong path (`$TASKS_DIR/templates/inception.md`).
- `create-batch.sh:63-68`: `--spec`, `--purpose` or `--new-arc` given last with no value makes `shift 2` fail under
  `set -e`. The script exits 1 silently instead of printing usage (exit 2).
- `create-batch` re-reads and re-parses the spec in `write-batch` after validating it. A spec edited between the two
  steps is written unvalidated (instantiate's tmp spec is not exposed to this).

## What I checked and found correct
- Rendering is a verbatim lift: `set_key`, `indent_block`, json-quoted name, the Updates replacement (`\n` in old
  bash double quotes is the same string), and the fallback's `$()` trailing-newline strip.
- argv passing uses `--k=value`, so values starting with `-` are safe. Unicode passes through.
- The `slug()` byte semantics match `tr`/`cut -c` (only difference: names that are exactly `-n`/`-e`).
- Validation messages and exit codes are the same. The interactive path, the inception gate and the T-1263 section
  check are intact; `rm -f "$FILEPATH"` still works with the stdout-derived path.
- create-batch refuses everything before reserving. Exactly one reservation is made; created rows are written only
  for files that landed; a partial failure is reported and leaves complete files.
- Duplicate names in a spec are harmless (different ids).
- Instantiate: the RETURN-trap cleanup does not fire early (tested). `{{`/`}}` escaping is right, there is no
  recursive substitution, and slugs with newlines are rejected by the `_arc_validate_id` regex. `--dry-run` writes
  only to a `mktemp` dir. Arc removal is guarded by the grep for member tasks.
- `bin/fw` routing adds `create-batch` and `instantiate` without altering existing subcommands.
