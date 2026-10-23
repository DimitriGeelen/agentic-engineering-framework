# t4513_git_grep_pager

> T-4513 (SECURITY, G-121): the read-only allowlist admitted `git grep` by verb name. git grep -O[CMD] / --open-files-in-pager[=CMD] STARTS CMD (default: the pager) on the matching files. Reported by ring20-dashboard (msg af2bbc85).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4513_git_grep_pager.bats`

## What It Does

T-4513 (SECURITY, G-121): the read-only allowlist admitted `git grep` by verb name.
git grep -O[CMD] / --open-files-in-pager[=CMD] STARTS CMD (default: the pager) on
the matching files. Reported by ring20-dashboard (msg af2bbc85).
Fix: agents/context/lib/safe-commands.sh _fw_git_grep_opens_pager — judged on the
dequoted words (_fw_option_words): a short bundle with O before an argument-taking
letter, any unambiguous prefix of --open-files-in-pager, or a word that begins with
an expansion is refused. Classification only: nothing here is executed.
`! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
`if cmd; then false; fi`.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4513_git_grep_pager.yaml`*
*Last verified: 2026-10-20*
