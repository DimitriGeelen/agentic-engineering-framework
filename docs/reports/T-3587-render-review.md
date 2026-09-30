# T-3587 render review: independent reviewer

**Reviewer:** t3587-review-67831b7e35ce (independent, not the builder) · 2026-09-30
**Scope:** commits e7d05fd01, 7866e6058; live Watchtower http://192.168.10.107:3002 (pid 2394128, `fw watchtower current` rc=0)

## VERDICT

**AMBER.** The operator's ask works. Evidence refs on /review/T-3581 link to the right files, brace groups link per member, `path:NNN` lands on the line, and the CLI prints the right host and port. Two problems need fixing before close. First, the new source viewer that line links land on is hard to read in light mode. Second, the "dead" marker makes false claims ("Not found … stale or mistyped") about files that exist, and about generic filenames in template prose.

## WHAT I CHECKED

1. **Links open the right file.** I curled every `/file/` href on /review/T-3581 (10 distinct files) and /inception/T-3576 (2). All 12 returned 200 and each body contained the target file's first line. /review/T-3581 has 0 unlinked path-shaped refs in rendered content. The Evidence brace groups `docs/reports/T-3579-code-review-{openai,zai}.md` and `T-3581-round3-review-{openai,zai}.md` link each member, and the bare `T-3581-rereview-openai.md` links. The screenshot shows readable text. The builder was right that the filing's `lib/task_pair_acd.sh` example was a CSS comment in review.html, not rendered content, and that the file exists. /approvals: 169 `/file/` links, recommendation now rendered as Markdown (no raw `**Evidence**`), 0 nested anchors.
2. **Dead vs live.** Styling is distinct and sensible: wavy red underline plus ✗ for dead, amber plus ? for ambiguous, grey for unserved, each with an explanatory title. Classification is wrong in several live cases, though (see Guidance 2–4). /approvals has 11 dead marks, 1 ambiguous, 13 unserved.
3. **`path:NNN` lands on the line.** /file/web/shared.py carries `id="L640"`, and the screenshot shows line 640 highlighted in view. `check-tier0.sh#L245` also resolves to the correct source line. Markdown targets have no line anchors; this is documented as a deliberate limit.
4. **Nothing else broken?**
   - Italics in prose (`_really_`, `_see web/shared.py_`) still render as `<em>`.
   - Underscore URLs (bare and `[x](…a_b_c.py)`) have no stray backslashes; 0 literal `\_` on any page checked.
   - Backticked `path:NNN` gives `<code><a>` with no nesting.
   - The /inception Verification comment still renders as `<h1>` lines. That rendering predates this task and is not caused by it.
   - **Regression:** the /file source view (screenshot t3587-file-line.png). Pygments uses `style="github-dark"` but the page is `data-theme="light"`. Name tokens get `.file-lines .n { color: #E6EDF3 }`, near-white on a light background. On line 640 itself, `exts`, `join` and `VIEWABLE_EXTENSIONS` are barely visible, and most identifiers in every source file look the same way. `get_style_defs` also emits an unscoped `pre { line-height: 125%; }`.
5. **CLI absolute URLs.** `bin/fw task review T-3581` prints `http://192.168.10.107:3002/review/T-3581`. `bin/fw watchtower url` prints `http://192.168.10.107:3002`, which matches `.context/working/watchtower.url` and port 3002, not a hard-coded 3000.
6. **Tests and sync.** 130 tests pass across test_t3587_file_refs.py plus the 5 neighbouring render suites. `bin/fw vendor self --check` is in sync.

## GUIDANCE

1. **(Must fix) Source-viewer contrast.** Choose the Pygments style by theme: a light style (`default`/`friendly`) for light and `github-dark` for dark, scoped with `[data-theme=…] .file-lines`. Alternatively, give `.file-lines pre` the dark background that matches the style. Scope or drop the bare `pre { line-height }` rule. Retake the #L640 screenshot and confirm identifiers are legible.
2. **(Must fix) "Not found" on files that exist.** `001-Vision.md` and `040-ValueDrivers.md` exist at the repo root. `settings.json` exists at `.claude/settings.json`. All three are marked dead with "stale or mistyped", which is the inverse of the task's goal: a live ref now looks broken. The cause is that the bare-name index only walks VIEWABLE_DIR_PREFIXES. When a bare name misses there, check the whole tree (excluding .git), and report it as *unserved* or *ambiguous*, not dead. Better still, add depth-0 `*.md` to the viewable root set so these links work.
3. **(Should fix) Generic filenames in prose.** Every /inception page's Verification template comment ("*.go, Cargo.toml, tsconfig.json, or pom.xml") now shows a red ✗ on `Cargo.toml` and links `tsconfig.json` to the unrelated `lib/ts/tsconfig.json`. The same happens with `snake_case_name.md` in prose. Options: don't mark a bare name dead unless it looks task-specific (T-NNNN, contains a path separator, or is backticked); skip template/HTML-comment text; or render a bare-name miss as neutral text instead of an error. Only a path with a directory component should say "stale or mistyped".
4. **(Should fix) `./` prefix.** `./agents/context/checkpoint.sh` is marked "outside the file viewer's allowlist", but the file is servable. Strip a leading `./` in `_resolve_ref`.
5. **(Minor) Marks inside code blocks.** `render_markdown_safe` has no fenced-code-blocks extra, so a fenced block comes out as `<p><code>`, not `<pre>`. The `in_pre` suppression never fires there, and pasted logs get dead marks, which the builder's own Decision rejected. Treat `<code>` spans over multiple lines like `<pre>`, or enable fenced-code-blocks.
6. **(Note) Allowlist coverage.** `docs/adr/` and `docs/runbooks/` refs show as unserved on /approvals. They are legitimate evidence directories; consider adding them to the shared list.

After fixes 1–2 (and ideally 3–4), a re-review on fresh screenshots of /file/web/shared.py#L640 and an /inception page should be enough to reach green.
