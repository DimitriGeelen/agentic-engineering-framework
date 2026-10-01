VERDICT amber  
HIGH LEFT: NO

No HIGH identified within the accepted T-3581 same-user boundary. The targeted routes are addressed; disclosed configuration and timing residuals remain.

1. **R8-1: closed for the specific probes, with qualifications.** The real `run.sh` command expands `--setting-sources user --settings $WDIR/settings.json --strict-mcp-config`, without `--mcp-config`. Registration signs the settings hash; start and completion verify it. **Yes**, CLI `{"crossSessionInbound":"refuse"}` overrides user-file `"accept"` under [Claude Code’s documented precedence](https://code.claude.com/docs/en/settings#settings-precedence). Managed settings rank higher, so this is not an unconditional guarantee across managed installations. No live inbound-delivery test was performed.

   `_project_config_fault` refuses tracked modifications, non-ignored untracked files, differences from the reviewed revision, and untracked `CLAUDE.local.md`. Project settings and MCP configuration are excluded from launch. Ignored instruction files and post-start edits remain possible, as disclosed.

2. **Codex’s three mediums and R8-3/4/5: closed for the reported cases by inspection.** `_head_checked` distinguishes unborn HEAD from lookup failure; component cards use YAML parsing and historical mappings; spend uses signed start time with ledger-wide dispatch deduplication. Completion rechecks and signs input hashes. R8-5 does **not** detect a swap restored before completion.

3. **No new fail-open path or broken test established.** The current checkout’s modified `CLAUDE.md` correctly triggers refusal. That blocks an ordinary review in this dirty checkout, but implements the expressly requested restriction. Clean-start controls exist in the tests; I could not execute their fixtures.

   Verification: **2 round-9 tests passed, 34 deselected**; additional in-memory probes confirmed HEAD-error refusal and quoted-YAML parsing. Full execution was blocked by the sandbox’s lack of any writable temporary directory. Successful runtime dispatch remains independently unverified.

4. **Remaining findings:**

   - **MEDIUM — existing operability residual; T-3580 Decisions / rung policy.** R8-2 remains: many tasks require a three-vendor panel that cannot currently launch. Restricting attribution to task-owned commits does not resolve this. **Fix:** operator policy decision or T-3582 backend support; do not count this as closed.
   - **LOW — documentation precision; `CLAUDE.md:890`, runtime comments.** The residual list substantially matches implementation: user configuration, parent instructions, ignored `.claude` files, post-start edits, PATH and served-model control remain. However, “project config committed at the reviewed revision is loaded” is too broad: project settings and MCP configuration are deliberately excluded. The launch-integrity wording also exceeds what endpoint hash checks establish. **Fix:** distinguish loaded instructions from excluded settings/MCP; explicitly mention swap-and-restore and the managed-settings precedence caveat.

No repository files, real verdicts, or criteria were changed. The read-only sandbox prevented appending this review.