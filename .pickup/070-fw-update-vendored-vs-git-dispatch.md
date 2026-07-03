# `fw update` aborts "No upstream_repo" on a git-based global install

**Source:** card-redirect (P-050) → couriered by termlink-agent → relayed into AEF inbox by termlink push-transport session (2026-07-03) | **Priority:** P1 (high) | **Origin date:** 2026-06-26

> Attribution chain preserved: filed by card-redirect, couriered verbatim onto
> `framework:pickup` (offset 75, pickup_id `TL-COURIER-cardredirect-P050`) which
> has no inbound AEF consumer (G-063 / PL-228), so it never arrived. Relayed here
> into `.pickup/` because that is the channel AEF actually reads.

## Symptom
`fw update` / `fw update --check` from any cwd resolves to the VENDORED-update
path and aborts `ERROR: No upstream_repo in .framework.yaml`, even though the
global install at `/root/.agentic-framework` is a git checkout whose origin IS
the canonical GitHub repo and is already at `HEAD == origin/master`.

## Root cause
`lib/update.sh` `_do_update()` dispatch checks the vendored branch FIRST:

```
if [ -d "$vendored_dir" ] && [ -f "$vendored_dir/VERSION" ]; then _do_update_vendored
elif [ -d "$FRAMEWORK_ROOT/.git" ]; then _do_update_git
```

The global install dir `/root/.agentic-framework` contains a NESTED vendored copy
at `/root/.agentic-framework/.agentic-framework/` (with a VERSION file), so
`$vendored_dir` exists and the vendored path wins even though `$FRAMEWORK_ROOT/.git`
is present and the git path would do the correct fetch+reset.
`_do_update_vendored()` (update.sh:85) then requires `upstream_repo:` from
`.framework.yaml`, which the framework repo's own `.framework.yaml` intentionally
lacks → abort.

## Contributing
The upstream URL is available two other ways the vendored path ignores:
(a) `git -C $FRAMEWORK_ROOT remote get-url origin`; (b) the `.upstream` sentinel
written at vendor time. `_do_update_vendored` reads only `.framework.yaml`, neither.

## Fix options (pick one)
1. In `_do_update()`: prefer `_do_update_git` when `$FRAMEWORK_ROOT/.git` exists
   with a tracking remote, BEFORE the vendored branch.
2. In `_do_update_vendored()`: when `upstream_repo` absent, fall back to the
   `.upstream` sentinel then `git remote get-url origin` before erroring.
3. Persist `upstream_repo` into `.framework.yaml` from `.upstream` at vendor time.

## Evidence
`lib/update.sh:60-68` (dispatch), `:85-98` (upstream_repo read + error);
nested vendored dir at `/root/.agentic-framework/.agentic-framework/lib/update.sh`.

**Tags:** fw-update, update.sh, upstream_repo, vendored-vs-git
