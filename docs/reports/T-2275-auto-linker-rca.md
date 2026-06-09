---
task: T-2275
kind: inception research artifact
session: S-2026-0609-0935
date: 2026-06-09
---

# T-2275 — Auto-linker excludes root files + docs/articles/

## TL;DR

`README.md` and `docs/articles/launch-article.md` referenced from Human AC
Steps render as `<code>README.md</code>` / `<code>docs/articles/launch-article.md</code>`
on `/review/T-XXX`, not as `<a href="/file/...">`. The framework HAS the
auto-linker (T-1722) and HAS the `/file/<path>` route (T-632), but the
whitelist that gates both excludes root files and excludes `docs/articles/`.
Two-prong structural fix; ~5-10 lines in `web/shared.py`.

## Symptom

Operator reported on T-2274's `/review/T-2274` page:

> Human AC section does not produce full usable links: for example
> `README.md` & `docs/articles/launch-article.md`

Reproduced via:

```
$ curl -s http://localhost:3000/review/T-2274 | grep -oE '.{20}README.md.{30}'
t 80 lines of <code>README.md</code> past the title
```

`<code>...</code>` — code span only, no `<a>` wrapper. Same shape for
`docs/articles/launch-article.md`.

Contrast with paths that DO get linked on the same page:

```
$ curl -s /review/T-2274 | grep -oE '<a href="[^"]+\.md[^"]*"[^>]*>' | head -3
<a href="/file/docs/reports/T-2274-readme-research.md">
<a href="/file/docs/reports/T-2274-readme-research.md" target="_blank">
```

Dossier path (`docs/reports/...`) gets `<a href="/file/...">`. Root README
does not. Article path does not.

## Root Cause — Five Whys

1. **Why does `README.md` render as `<code>` not `<a>`?**
   Because the auto-linker (`_auto_link_files`, `web/shared.py:596-621`)
   did not match it.

2. **Why didn't the auto-linker match it?**
   Because the regex built by `_build_artefact_path_re()`
   (`web/shared.py:572-590`) REQUIRES the path to start with one of the
   directory prefixes in `VIEWABLE_DIR_PREFIXES`. Bare `README.md` has no
   prefix.

3. **Why does the regex require a prefix?**
   Because `is_viewable_path()` (`web/shared.py:543-562`) — the single
   source of truth shared by the auto-linker AND the `/file/<path>` route
   (T-1764 lockstep) — requires `startswith(d)` for one of those prefixes.
   The regex and the route helper agree by design.

4. **Why was the prefix list designed that way?**
   T-1722 promoted the linker from `web/blueprints/docs.py` (T-633) where
   it was scoped to component-doc pages. The original whitelist was
   "directories full of artefacts the framework writes" — task files,
   handovers, episodics, fabric components, etc. Root files (`README.md`,
   `CLAUDE.md`, `FRAMEWORK.md`) and `docs/articles/` weren't on the
   author's mind because the original surface (component-doc page) didn't
   reference them.

5. **Why didn't the promotion to all Markdown surfaces (T-1722) catch the
   gap?**
   Because no Human AC at the time of T-1722 referenced a root file or an
   `docs/articles/` path in its Steps. The agent-authoring conventions
   that bring these references into AC bodies (worker contract for T-2274
   names `README.md` + `docs/articles/launch-article.md` directly) post-date
   T-1722. The contract grew; the whitelist didn't.

**Root cause:** the whitelist that gates the auto-linker is a static
allowlist that did not grow as agent-authoring conventions expanded the
set of paths that appear in rendered task content.

## Prong A — `docs/articles/` missing

`VIEWABLE_DIR_PREFIXES` (web/shared.py:518-538) has `docs/reports/` but
NOT `docs/articles/`. Neither are `docs/articles/deep-dives/`,
`docs/plans/`, `docs/dispatch-templates/` — all of which contain `.md`
files referenced from task bodies, the README, and FRAMEWORK.md.

## Prong B — Root files entirely excluded

`is_viewable_path()` line 557:

```python
if not any(filepath.startswith(d) for d in VIEWABLE_DIR_PREFIXES):
    return False
```

Any file at depth 0 returns False. `README.md`, `CLAUDE.md`,
`FRAMEWORK.md`, `VERSION`, `LICENSE`, `CHANGELOG` — every file at the
project root — is structurally unviewable and therefore unlinkable.

Extension whitelist (`VIEWABLE_EXTENSIONS` line 540) DOES permit
`.md`/`.txt` etc., so the only barrier is the prefix requirement.

## Candidate Fixes

### Candidate 1 — Minimal (Prong A only, 1-line)

Add `"docs/articles/"` to `VIEWABLE_DIR_PREFIXES`. Closes the operator's
immediate symptom for `docs/articles/launch-article.md`. Does NOT close
the README issue.

**Pro:** smallest change.
**Con:** partial fix; README still un-linkable; comes back.

### Candidate 2 — Both prongs, explicit allowlist (RECOMMENDED)

- Extend `VIEWABLE_DIR_PREFIXES` with `docs/articles/`,
  `docs/articles/deep-dives/`, `docs/plans/`, `docs/dispatch-templates/`.
- Add `ROOT_FILES = frozenset({"README.md", "CLAUDE.md", "FRAMEWORK.md",
  "VERSION", "LICENSE", "CHANGELOG"})`.
- In `is_viewable_path`, accept `filepath in ROOT_FILES` as an OR with
  the existing prefix check.
- Rebuild the regex `_build_artefact_path_re()` to alternate either
  `(?:dir1|dir2|...)[A-Za-z0-9_/.-]+\.ext` OR
  `(?:README|CLAUDE|FRAMEWORK|VERSION|LICENSE|CHANGELOG)\.(?:md|txt)`.

**Pro:** closes both prongs; explicit allowlist is easy to reason about;
no false-positive risk (existence-gated); covers the surfaces the
operator actually mentions.
**Con:** slightly larger diff (~10 lines); requires careful regex test.

### Candidate 3 — General "depth-0 known extension" rule

Allow any depth-0 file with a `VIEWABLE_EXTENSIONS` extension that
exists at PROJECT_ROOT.

**Pro:** auto-covers future root files; no allowlist maintenance.
**Con:** broader linkification surface; any prose mention of e.g.
`setup.py` or `script.sh` becomes a link if those files exist. Higher
false-positive rate.

### Recommendation

**Candidate 2** for the GO build. Rationale: closes both prongs, smallest
defensible diff, no false-positive surface beyond the existing existence
gate, explicit allowlist matches the operator's expected files. Defer
Candidate 3 to a follow-up if the allowlist grows to >10 entries.

## Test Surface

One file — `tests/unit/test_auto_link_root_and_articles.{py,bats}` —
covering:

- **Positive:** each of the 5-6 root files in the allowlist emits
  `<a href="/file/<file>">` after `_auto_link_files`.
- **Positive:** `docs/articles/launch-article.md` (and one path from each
  newly-added prefix) emits an anchor.
- **Negative:** `random_root_file.md` not in the allowlist + not present
  on disk does NOT emit an anchor.
- **Negative:** a path containing `..` still rejected.
- **Idempotency:** running the linker on already-linked HTML doesn't
  double-wrap (covered by existing lookbehinds).

## Affected Surfaces (no source change needed in any of them)

Every page that calls `render_markdown_safe` or `_render_md_inline` /
`_render_md_block` inherits the fix automatically:

- `/review/T-XXX` — Human AC Steps, Expected, If-not blocks
- `/tasks/T-XXX` — task body Markdown
- `/inception/T-XXX` — inception body + Recommendation + Evidence
- `/approvals` — list rendering of recommendations
- `/arcs/<slug>` — arc body + headline mechanic + recommendation
- Cockpit + system-health surfaces that embed rendered task fragments

## Out of Scope

- Mass-relinking existing rendered cached HTML — the renderer is
  request-time; pages re-render on each load.
- New routes, new templates, new Markdown extensions.
- Changes to `/file/<path>` route handler beyond what `is_viewable_path`
  already serves.
- Catching paths that DON'T exist (intentional — existence gate prevents
  false positives in prose).

## Recommendation

**GO** — implement Candidate 2 as a single build task. Surface estimate:
~10-line diff in `web/shared.py` + one ~30-line test file. Effort: small
(1-2 hour bounded build). Blast radius: 0 (pure additive linkification;
no behavioural regression possible on existing linked paths because the
regex is OR-extended, not modified).

The operator's reported symptom maps cleanly to this fix; no further
research needed before the GO decision.
