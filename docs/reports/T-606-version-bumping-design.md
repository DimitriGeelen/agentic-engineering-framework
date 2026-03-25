# T-606: Version Bumping Mechanism — Design Document

## Status Quo

| Source | Location | Current Value |
|--------|----------|---------------|
| FW_VERSION | bin/fw:14 | 1.2.6 |
| Root VERSION file | VERSION | 1.2.6 |
| Vendored VERSION | .agentic-framework/VERSION | 1.2.6 |
| Git tag | git tag | v1.2.6 |
| .framework.yaml | consumer projects | version: 1.2.6 |

**Problem:** 458 commits since last tag (v1.2.6). All version sources are "in sync" at 1.2.6 but massively stale relative to actual code changes. No mechanism exists to bump versions — it's done manually by editing bin/fw line 14 and hoping the other files get updated.

**Current propagation path:**
- FW_VERSION in bin/fw is the single source of truth
- do_vendor() in bin/fw writes FW_VERSION to $dest/VERSION
- init.sh writes FW_VERSION to .framework.yaml
- upgrade.sh reads FW_VERSION and updates .framework.yaml version field
- update.sh reads vendored VERSION file, compares with upstream

## Proposed Command Interface

### fw version bump [major|minor|patch]

    fw version bump patch          # 1.2.6 -> 1.2.7
    fw version bump minor          # 1.2.6 -> 1.3.0
    fw version bump major          # 1.2.6 -> 2.0.0
    fw version bump patch --tag    # Also creates git tag v1.2.7
    fw version bump patch --dry-run # Show what would change, don't modify
    fw version bump                # Error: component required

### fw version check

    fw version check               # Check sync + staleness
    # Output:
    #   FW_VERSION (bin/fw):           1.2.7 OK
    #   VERSION (root):                1.2.7 OK
    #   .agentic-framework/VERSION:   1.2.6 STALE
    #   Last tag: v1.2.6 (458 commits ago)
    #   WARNING: 458 commits since last tag (threshold: 50)

### fw version sync

    fw version sync                # Force-sync all VERSION files to match FW_VERSION
    fw version sync --dry-run      # Show what would be synced

## Implementation Plan

### 1. Add version subcommand routing in bin/fw (~line 2775)

Currently version|-v|--version calls show_version. Extend to handle subcommands:

    version|-v|--version)
        case "${2:-}" in
            bump)  shift 2; source "$FW_LIB_DIR/version.sh"; do_version_bump "$@" ;;
            check) shift 2; source "$FW_LIB_DIR/version.sh"; do_version_check "$@" ;;
            sync)  shift 2; source "$FW_LIB_DIR/version.sh"; do_version_sync "$@" ;;
            ""|--help|-h) show_version ;;
            *) echo "Unknown: $2"; exit 1 ;;
        esac
        ;;

### 2. Create lib/version.sh (new file, ~150 lines)

#### do_version_bump()

1. Parse args: component (required), --tag, --dry-run, --task T-XXX
2. Read current version from FW_VERSION in bin/fw
3. Validate semver format (^[0-9]+\.[0-9]+\.[0-9]+$)
4. Compute new version (increment component, zero subordinates)
5. If --dry-run: show what would change, return
6. Warn if uncommitted changes exist
7. Update files:
   - bin/fw FW_VERSION (primary source) via _sed_i
   - VERSION (root)
   - .agentic-framework/VERSION (if exists)
   - .agentic-framework/bin/fw FW_VERSION (if exists)
8. Stage files: git add bin/fw VERSION [vendored files]
9. Commit: "T-XXX: Bump version to X.Y.Z" (or without task prefix)
10. If --tag: git tag -a "vX.Y.Z" -m "Release X.Y.Z"
11. Print summary + "Next: git push && git push --tags"

**Consumer project guard:** If PROJECT_ROOT != FRAMEWORK_ROOT, error with "Version bumping is only available in the framework repo. Use fw update to get the latest version."

#### do_version_check()

1. Read FW_VERSION from bin/fw (source of truth)
2. Compare against: VERSION file, vendored VERSION, vendored bin/fw FW_VERSION
3. Report sync status with green/red indicators
4. Check staleness: commits since latest git tag vs threshold (50)
5. Return 0 if all sync, 1 if out of sync

#### do_version_sync()

1. Read FW_VERSION from bin/fw
2. Update all other sources to match (with --dry-run support)
3. Don't create missing files — only update existing ones

### 3. Audit Integration — Add to self-audit.sh

New Layer 5: Version Consistency (between Layer 4 and Summary):

- 5.1 Check FW_VERSION matches root VERSION file
- 5.2 Check vendored VERSION matches (if exists)
- 5.3 Tag staleness: commits since last tag > 50 threshold -> warn

### 4. Pre-push Advisory

Add non-blocking note to pre-push hook:

    latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
    if [ -n "$latest_tag" ]; then
        commits_since=$(git rev-list --count "${latest_tag}..HEAD" 2>/dev/null || echo 0)
        if [ "$commits_since" -gt 50 ]; then
            echo "NOTE: $commits_since commits since $latest_tag. Consider: fw version bump patch --tag"
        fi
    fi

### 5. Help text update

Add to show_help() in bin/fw:

    version [subcommand]    Version management
      version               Show current version
      version bump <part>   Bump major|minor|patch (--tag, --dry-run)
      version check         Verify all version sources in sync + staleness
      version sync          Sync all files to FW_VERSION

## Files to Edit

| File | Change |
|------|--------|
| bin/fw | Add version subcommand routing (~line 2775), update help text |
| lib/version.sh | NEW — do_version_bump, do_version_check, do_version_sync |
| agents/audit/self-audit.sh | Add Layer 5: Version Consistency |
| agents/git/lib/hooks.sh | Add pre-push staleness advisory |

## Edge Cases and Error Handling

1. Non-semver version: Validate before bumping. Error with message.
2. Dirty working tree: Warn but don't block.
3. Missing VERSION files: Only update files that exist.
4. Tag already exists: Catch git tag failure, report clearly.
5. No git repo: fw version check and --tag need git. Error gracefully.
6. Consumer vs framework: fw version bump only in framework repo.
7. sed -i portability: Use _sed_i from compat.sh (handles macOS vs GNU).
8. Concurrent bumps: Not a concern — single-user CLI tool.

## Consumer Project Considerations

- fw update already propagates version from upstream to vendored copy. No changes needed.
- fw upgrade already syncs .framework.yaml version. No changes needed.
- fw version bump in consumer project: Error with helpful message.
- Version pinning: Already handled by .framework.yaml version: field.

## Constitutional Directive Alignment

| Directive | How This Serves It |
|-----------|--------------------|
| D1 Antifragility | Staleness detection (458 commits!) creates pressure to release. Audit integration makes drift visible. |
| D2 Reliability | Single source of truth (FW_VERSION), sync check, audit catches drift. |
| D3 Usability | fw version bump patch — one command. fw version check — instant status. |
| D4 Portability | Pure bash, sed, git. _sed_i for macOS/Linux. |

## Acceptance Criteria

### Agent
- [ ] fw version bump patch increments patch in all 4 files
- [ ] fw version bump minor zeroes patch, increments minor
- [ ] fw version bump major zeroes minor+patch, increments major
- [ ] fw version bump patch --tag creates annotated git tag
- [ ] fw version bump patch --dry-run shows changes without modifying
- [ ] fw version check reports sync status of all version sources
- [ ] fw version check reports commits since last tag with threshold warning
- [ ] fw version sync updates all files to match FW_VERSION
- [ ] fw version bump errors in consumer project (not framework repo)
- [ ] self-audit.sh includes Layer 5: Version Consistency
- [ ] Validates current version is semver before bumping
- [ ] fw help shows version subcommands
- [ ] Uses _sed_i for macOS/Linux portability

### Human
- [ ] Run fw version bump patch --dry-run and verify output
- [ ] Run fw version bump patch --tag and verify tag created
- [ ] Run fw version check after bump and verify sync
- [ ] Run fw audit and verify version staleness in report

## Verification

    bash -n lib/version.sh
    fw version bump --help 2>&1 | grep -q "bump"
    fw version check
    agents/audit/self-audit.sh 2>&1 | grep -q "VERSION CONSISTENCY"

## Immediate Action

458 commits since v1.2.6. After implementation:

    fw version bump minor --tag   # 1.2.6 -> 1.3.0
# Version Tracking Audit — Agentic Engineering Framework

**Date:** 2026-03-25
**Task:** T-606
**Auditor:** Sub-agent (version-current-gaps)

---

## 1. All Version Sources

| # | Location | Current Value | Last Updated | Auto-synced? | Breaks if stale? |
|---|----------|---------------|-------------|--------------|------------------|
| 1 | `bin/fw` line 14: `FW_VERSION="1.2.6"` | `1.2.6` | 2026-03-08 (commit 6257539) | **NO — manual edit** | `fw version`, `fw doctor` version mismatch warnings, `fw vendor` writes wrong VERSION file, `fw upgrade` stamps wrong version in consumer `.framework.yaml` |
| 2 | `VERSION` (root file) | `1.2.6` | 2026-03-08 (commit 74fbc68 — fix from 1.0.0→1.2.6) | **NO — manual edit** | `fw update` for git-based installs reads this; vendored consumers compare against it |
| 3 | `.agentic-framework/VERSION` (vendored copy) | `1.2.6` | Created by `do_vendor()` — copies from source `$FW_VERSION` | **YES** — auto-created by `fw vendor` | `fw update` vendored path reads this as "current version" |
| 4 | `.agentic-framework/bin/fw` line 14 | `1.2.6` | Copied verbatim by `do_vendor()` | **YES** — vendored copy of source | Consumer `fw version` shows wrong version if stale |
| 5 | Consumer `.framework.yaml` `version:` field | varies | Set by `fw upgrade` step 8 and `fw update` | **YES** — updated by upgrade/update | `fw doctor` warns on mismatch vs installed |
| 6 | Git tags | `v1.0.0` through `v1.2.6` (9 tags) | 2026-03-08 (last tag: v1.2.6) | **NO — manual `git tag`** | No runtime impact but breaks `fw update --check` changelog display |

**No version present in:** package.json (none exists), pyproject.toml (none), Cargo.toml (none), GitHub Actions (none), Homebrew formula (separate repo).

### Docs with Hardcoded Version Strings

Multiple docs reference `1.2.6` literally (12 occurrences across 5 files in docs/reports/ and docs/generated/). These are historical reports — staleness doesn't break anything.

---

## 2. Sync Analysis — The Three Manual Sources

### Source A: `bin/fw` FW_VERSION (line 14)
- **Authority:** This is the **canonical version**. Everything else derives from it.
- **Update mechanism:** Manual edit of string literal
- **What depends on it:** `fw version`, `fw doctor`, `fw vendor`, `fw upgrade`, `fw init`

### Source B: `VERSION` (root file)
- **Authority:** Secondary — read by `fw update` git-based path
- **Gap found:** Was stuck at `1.0.0` until T-522 fixed it (commit 74fbc68). **Out of sync from v1.1.0 through v1.2.5** — 7 releases with stale VERSION file.

### Source C: Git tags
- **Authority:** Release markers
- **Relationship:** Should match FW_VERSION. Currently aligned at v1.2.6.

### Gap: No automated sync between A, B, and C

No script, hook, or CI step validates consistency. Evidence: VERSION was 1.0.0 while FW_VERSION was 1.2.6 for 7 releases.

---

## 3. Vendored Project Flow — Propagation Trace

### fw update (vendored path):
1. Reads `VERSION` from upstream clone (root VERSION file)
2. Compares against `.agentic-framework/VERSION`
3. Copies code, writes new VERSION, updates `.framework.yaml`

### fw vendor:
1. Writes `$FW_VERSION` (from bin/fw) to `dest/VERSION`

**Critical inconsistency:** `fw update` reads root VERSION, `fw vendor` writes FW_VERSION. If mismatched, consumers get conflicting stamps.

### fw upgrade:
- Stamps `$FW_VERSION` into consumer `.framework.yaml`
- Does NOT update framework code — only governance artifacts
- Order dependency: must run `fw update` BEFORE `fw upgrade` (undocumented)

---

## 4. Commit/Tag History

| Tag | Date | Commits Since Previous |
|-----|------|----------------------|
| v1.0.0 | 2026-02-14 | — (initial) |
| v1.1.0 | 2026-03-08 | 1,019 commits |
| v1.2.0–v1.2.6 | 2026-03-08 | 1–11 commits each (all same day) |

**Current staleness: 458 commits and 17 days since v1.2.6** — massive changes (TermLink, budget gate, vendored install, bus system, dispatch) all shipping as "v1.2.6".

---

## 5. What the Audit System Checks

### self-audit.sh — ZERO version checks
406 lines checking 4 layers (foundation, structure, hooks, git). No version validation at all.

### fw doctor — Partial
Checks consumer `.framework.yaml` version vs installed FW_VERSION. Does NOT check FW_VERSION vs VERSION file or staleness.

---

## 6. Summary of Gaps

### Critical
| # | Gap | Evidence |
|---|-----|----------|
| G1 | No `fw bump`/`fw release` command — all 3 sources manual | VERSION was stale for 7 releases |
| G2 | No validation FW_VERSION == VERSION == latest tag | T-522 discovered the divergence |
| G3 | `fw update` reads VERSION, `fw vendor` writes FW_VERSION | Architectural inconsistency |
| G4 | 458 commits since last bump | Consumers see "up to date" falsely |

### Moderate
| # | Gap |
|---|-----|
| G5 | self-audit.sh has zero version checks |
| G6 | fw doctor doesn't check FW_VERSION vs VERSION |
| G7 | No staleness warning (commits-since-tag) |
| G8 | fw upgrade/update order dependency undocumented |

### Recommendations
1. Add `fw bump [major|minor|patch]` — atomic update of all 3 sources + git tag
2. Add version consistency check to self-audit.sh
3. Add staleness check to fw doctor (warn if >50 commits since tag)
4. Standardize VERSION file as derived from FW_VERSION (single source of truth)
5. Add pre-tag hook to validate version consistency
# Version Bumping Research — T-606

## Current State (fw framework v1.2.6)

Three version locations:
- `bin/fw` line 14: `FW_VERSION="1.2.6"` (source of truth)
- `VERSION` (framework root)
- `.agentic-framework/VERSION` (vendored copy)

`lib/update.sh` and `lib/upgrade.sh` already compare versions across these locations, detect mismatches, and handle vendored-vs-upstream divergence.

---

## 1. Package Manager Patterns

### npm version (Node.js)
- `npm version patch|minor|major` — user specifies bump type
- **Edits:** `package.json` version field
- **Git:** creates commit + tag `vX.Y.Z`
- **Runs:** `preversion`, `version`, `postversion` lifecycle scripts
- **Key insight:** Single source of truth (package.json), everything else reads from it

### cargo release (Rust)
- `cargo release patch|minor|major`
- **Edits:** `Cargo.toml` + `Cargo.lock`
- **Git:** commit + tag
- **Post-release:** auto-bumps to next pre-release (e.g., 1.0.1-alpha.0)
- **Key insight:** Workspace-aware — can bump multiple crates in a monorepo

### pip/setuptools (Python)
- No built-in `pip version bump` — relies on third-party tools
- `bump2version` / `bumpversion`: config-driven, edits multiple files via regex
- `setuptools-scm`: derives version FROM git tags (no version file needed)
- **Key insight:** setuptools-scm inverts the pattern — git tag IS the version, code reads it at build time

---

## 2. Commit-Driven (Fully Automated)

### semantic-release
- **Trigger:** CI pipeline after merge to main
- **Analyzes:** Conventional Commits (`fix:` → patch, `feat:` → minor, `BREAKING CHANGE:` → major)
- **Calculates:** next version automatically from commit history since last tag
- **Edits:** package.json (via plugins), can edit arbitrary files
- **Git:** creates tag, GitHub release, publishes to npm
- **Key insight:** Humans never choose version numbers — commits determine everything

### standard-version (deprecated → release-please)
- Same Conventional Commits analysis
- **Edits:** package.json + CHANGELOG.md
- **Git:** commit `chore(release): X.Y.Z` + tag
- **Key insight:** Lighter than semantic-release — no CI integration, runs locally

### git-cliff
- Primarily a changelog generator, not a version bumper
- `git-cliff --bump` can CALCULATE next version from commits
- Doesn't edit files directly — outputs to stdout or CHANGELOG.md
- Often paired with other tools for the actual bump

---

## 3. Shell-Based CLI Tools (Most Relevant to fw)

### oh-my-zsh
- `VERSION` file at repo root (contains just the version string)
- `upgrade.sh` reads `VERSION`, compares with remote
- Version bumped manually by maintainers before release
- Tags created manually: `git tag v0.x.x`
- **Pattern:** Simple VERSION file + manual bump + git tag

### nvm (Node Version Manager)
- Version embedded in `nvm.sh` as `NVM_VERSION` variable
- `install.sh` reads this when installing
- Version bumped manually in the script before release
- Uses git tags for release tracking
- **Pattern:** Version string in main script + git tag

### rbenv
- Version in `libexec/rbenv---version` (echoes the string)
- Makefile or release script bumps it
- Git tags for releases
- **Pattern:** Version in a dedicated executable + git tag

### Common Pattern Across Shell Tools:
1. VERSION string lives in **one canonical file** (either a VERSION file or the main script)
2. Git tags are created at release
3. Update/upgrade scripts compare local version against remote tag/VERSION
4. No automated commit-message-based bumping — shell tools are too simple for that

---

## 4. Homebrew Formula Pattern

### How `brew bump-formula-pr` works:
- Detects new upstream release (via GitHub API, checking tags)
- Downloads new tarball, computes SHA256
- Edits formula `.rb` file: updates `url` and `sha256`
- Creates PR to homebrew-core (or tap)
- **Key insight:** Homebrew doesn't bump YOUR version — it detects YOUR new tag and updates ITS reference

### What this means for fw:
- If fw ever has a Homebrew formula, version bumping in fw triggers formula update
- The formula reads from git tags (e.g., `v1.2.7`)
- So fw MUST create git tags as part of version bumping

---

## 5. Recommended Pattern for fw

Based on research, the **simplest reliable pattern** for a bash-based CLI:

### Design: Single Source + Propagation Script

```
Source of truth: bin/fw (FW_VERSION="X.Y.Z")
Propagation:    fw version bump patch|minor|major
```

### Mechanical Steps (what `fw version bump` should do):

1. **Read** current version from `bin/fw` (parse FW_VERSION line)
2. **Calculate** new version (semver bump based on argument)
3. **Edit** `bin/fw` — update FW_VERSION string (sed in-place)
4. **Write** `VERSION` — echo new version to framework root VERSION file
5. **Write** `.agentic-framework/VERSION` — same for vendored copy
6. **Git commit** — `git commit -am "chore(release): vX.Y.Z"`
7. **Git tag** — `git tag -a vX.Y.Z -m "Release X.Y.Z"`
8. **Print** — echo new version to stdout

### Why This Pattern:

| Choice | Rationale |
|--------|-----------|
| `bin/fw` as source of truth | Already exists, already read by `show_version()`, `fw doctor`, update/upgrade |
| Propagation (not derivation) | VERSION files are convenience copies for tools that can't parse bash |
| Manual trigger (not commit-driven) | Framework is too small for semantic-release overhead |
| Git tag required | Enables brew bump-formula-pr, enables lib/update.sh remote comparison |
| No CHANGELOG generation | Can add later via git-cliff if needed; not essential for v1 |

### Consumer Project Handling:

- `fw update` already copies VERSION from upstream to local `.agentic-framework/VERSION`
- Version mismatch detection already exists in `fw doctor` and `show_version()`
- No additional mechanism needed — vendored VERSION is updated on `fw update`

### Edge Cases to Handle:

1. **Dirty working tree** — refuse to bump if uncommitted changes exist
2. **Tag already exists** — refuse to create duplicate tag
3. **VERSION file out of sync** — `fw doctor` already detects this; bump command fixes it

### Anti-Patterns to Avoid:

- Don't derive version from git tags (requires git at runtime, breaks vendored copies)
- Don't use commit-message parsing (overkill for a bash CLI)
- Don't store version in multiple independent locations (single source + propagation only)
- Don't require external tools (node, python, cargo) — must work with bash + git only
