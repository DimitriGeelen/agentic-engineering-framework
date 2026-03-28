# Keeping a File Tracked in One Git Remote but Excluded from Another

**Use case:** `.onedev-buildspec.yml` must exist in the OneDev remote (CI reads build jobs from it) but must NOT appear on GitHub (contains username and internal IPs).

## TL;DR Recommendation

**Use Option 7 (GitHub Actions auto-delete)** for simplicity and reliability, or **Option 2 (branch-specific)** for zero-leak guarantees. All other options either don't work at the Git protocol level or introduce fragile/complex maintenance.

---

## Option 1: git attributes + export-ignore

**Mechanism:** Add `.onedev-buildspec.yml export-ignore` to `.gitattributes`.

**Finding: DOES NOT WORK for this use case.**

`export-ignore` only affects `git archive` (tar/zip exports). It has **zero effect** on `git push`, `git clone`, or `git fetch`. The file will still be transferred to GitHub on every push.

| Factor | Rating |
|--------|--------|
| Complexity | Low |
| Reliability | **N/A — does not achieve the goal** |
| Maintenance | N/A |
| Leak risk | **HIGH — file is pushed to GitHub** |

**Verdict: REJECTED.** This is the most common misconception. `export-ignore` is for package distribution (Composer, npm tarballs), not for remote-specific file exclusion.

---

## Option 2: Branch-specific approach (RECOMMENDED — zero-leak)

**Mechanism:** Maintain a `onedev` branch (or use the existing default branch only on OneDev). The GitHub remote's default branch never contains the buildspec file.

### Implementation

```bash
# One-time setup: create a onedev-specific branch
git checkout -b onedev
# Add the buildspec only on this branch
git add .onedev-buildspec.yml
git commit -m "Add OneDev buildspec (onedev branch only)"

# Configure remotes with different default push branches
git remote set-url --push github git@github.com:org/repo.git
git remote set-url --push onedev https://onedev.internal/org/repo.git

# Push main to GitHub (no buildspec)
git push github main

# Push onedev branch to OneDev (has buildspec)
# OneDev can be configured to use 'onedev' as its default branch,
# or to trigger CI on the 'onedev' branch
git push onedev onedev
```

### Workflow for keeping branches in sync

```bash
# After making changes on main:
git checkout onedev
git merge main        # brings all changes, buildspec stays
git push onedev onedev
git checkout main
git push github main
```

Or automate with a pre-push hook or alias:

```bash
# .git/hooks/pre-push (or alias)
#!/bin/bash
REMOTE="$1"
if [ "$REMOTE" = "github" ]; then
    # Verify buildspec is NOT in the branch being pushed
    if git ls-tree -r HEAD --name-only | grep -q '.onedev-buildspec.yml'; then
        echo "ERROR: .onedev-buildspec.yml detected in branch pushed to GitHub!"
        echo "Push the 'main' branch (without buildspec) to GitHub."
        exit 1
    fi
fi
```

### OneDev configuration

OneDev reads `.onedev-buildspec.yml` from whatever branch triggers the build. You can:
- Set the default branch in OneDev to `onedev`
- Or configure job triggers to watch the `onedev` branch
- Or merge main into onedev and push; OneDev builds from `onedev`

| Factor | Rating |
|--------|--------|
| Complexity | Medium (two branches to maintain, merge workflow) |
| Reliability | **HIGH — file physically cannot exist on GitHub's branch** |
| Maintenance | Medium (must remember to merge main→onedev before pushing to OneDev) |
| Leak risk | **ZERO if pre-push hook is used; NEAR-ZERO otherwise** |

**Verdict: RECOMMENDED if zero-leak guarantee is required.** The merge workflow adds friction but the file provably never reaches GitHub. A pre-push hook can enforce this structurally.

---

## Option 3: Git clean/smudge filter

**Mechanism:** Define a `clean` filter that replaces the file contents with an empty string (or removes it) when committing, and a `smudge` filter that restores it when checking out.

### Implementation concept

```bash
# .gitattributes
.onedev-buildspec.yml filter=strip-buildspec

# .git/config (local only — not shared with GitHub)
[filter "strip-buildspec"]
    clean = cat /dev/null
    smudge = cat ~/.onedev-buildspec.yml
```

**Finding: DOES NOT WORK for this use case.**

The clean filter runs at **commit time**, not at push time. It transforms what goes into the Git object store. This means:
- If you strip the file during clean, **both** remotes get the stripped version
- There is no way to make the filter remote-aware — it operates on the working tree → index transition
- You could strip credentials from the file content (replacing IPs/usernames with placeholders), but the file itself would still exist on GitHub

The only partial use: strip **sensitive values** from the file while keeping the file structure. But this doesn't remove the file from GitHub; it just sanitizes its content.

| Factor | Rating |
|--------|--------|
| Complexity | Medium-High (filter setup, per-machine config) |
| Reliability | **LOW — filters are per-machine, not enforced on clone** |
| Maintenance | High (every developer must configure the filter locally) |
| Leak risk | **HIGH — file still appears on GitHub (sanitized or not)** |

**Verdict: REJECTED for file exclusion. Usable only for credential scrubbing within the file.**

---

## Option 4: GitHub-specific .gitignore

**Finding: DOES NOT WORK.**

`.gitignore` only prevents **untracked** files from being staged. Once a file is tracked (committed), `.gitignore` has no effect on it. GitHub does not support any repo-level mechanism to ignore tracked files during push/clone.

The `.git/info/exclude` file works the same way — local-only, and only for untracked files.

| Factor | Rating |
|--------|--------|
| Complexity | N/A |
| Reliability | **N/A — does not achieve the goal** |
| Maintenance | N/A |
| Leak risk | **HIGH — tracked file is always pushed** |

**Verdict: REJECTED.** Fundamental Git limitation: .gitignore cannot ignore tracked files.

---

## Option 5: Push refspec with path filtering

**Finding: DOES NOT WORK.**

Git refspecs operate at the **ref level** (branches, tags), not at the file/path level. Negative refspecs like `^refs/heads/secret` exclude entire branches from being pushed, but there is no mechanism to exclude individual files from a branch during push.

```bash
# This excludes BRANCHES, not files:
git push github 'refs/heads/*' '^refs/heads/onedev'
```

Git's transfer protocol sends complete tree objects for each commit. There is no partial-tree push mechanism in the Git protocol.

| Factor | Rating |
|--------|--------|
| Complexity | N/A |
| Reliability | **N/A — does not exist** |
| Maintenance | N/A |
| Leak risk | N/A |

**Verdict: REJECTED.** Git protocol does not support file-level push filtering.

---

## Option 6: Git subtree / sparse approach

**Mechanism:** Use `git subtree split` to create a subset of the repo without the buildspec, push that subset to GitHub.

### Implementation concept

```bash
# This only works for DIRECTORY-based splits, not individual files
git subtree split --prefix=src -b github-only
git push github github-only:main
```

**Finding: IMPRACTICAL for this use case.**

`git subtree` splits by **directory prefix**, not by excluding individual files. You would need to restructure your entire repository so that the buildspec lives in a separate directory from everything else — which defeats the purpose since OneDev expects it at the repo root.

There is no `git subtree split --exclude` mechanism.

| Factor | Rating |
|--------|--------|
| Complexity | Very High (repo restructuring required) |
| Reliability | Low (subtree rewrites history, creates divergent commit SHAs) |
| Maintenance | Very High (every push requires subtree split + force push) |
| Leak risk | Low (if done correctly) |

**Verdict: REJECTED.** Massive overhead for excluding one file. Git subtree is designed for directory-based repository splitting.

---

## Option 7: GitHub Actions auto-delete (RECOMMENDED — simplest)

**Mechanism:** A GitHub Action triggers on push, detects the buildspec file, removes it, and commits the deletion. The file lives in the OneDev remote normally but is automatically cleaned from GitHub.

### Implementation

```yaml
# .github/workflows/clean-buildspec.yml
name: Remove OneDev buildspec
on:
  push:
    branches: ['**']
    paths:
      - '.onedev-buildspec.yml'

permissions:
  contents: write

jobs:
  clean:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Remove OneDev buildspec
        run: |
          if [ -f .onedev-buildspec.yml ]; then
            git rm .onedev-buildspec.yml
            git config user.name "github-actions[bot]"
            git config user.email "github-actions[bot]@users.noreply.github.com"
            git commit -m "Auto-remove .onedev-buildspec.yml (internal CI config)"
            git push
          fi
```

### Key characteristics

- **The file briefly exists on GitHub** between push and action completion (~30-60 seconds)
- The action only triggers when the buildspec file is in the push (`paths` filter)
- Subsequent pulls from GitHub will include the deletion commit
- You need to handle this in your OneDev workflow (don't pull the deletion back)

### Handling the deletion loop

To prevent OneDev from pulling the GitHub deletion:
- OneDev should be the **source of truth** — push TO OneDev, not pull FROM GitHub
- Or use a `.gitattributes` merge driver that keeps local version on conflict
- Or configure OneDev to ignore commits from `github-actions[bot]`

| Factor | Rating |
|--------|--------|
| Complexity | Low (one workflow file) |
| Reliability | **HIGH — GitHub Actions is very reliable** |
| Maintenance | Low (set and forget, unless workflow syntax changes) |
| Leak risk | **LOW-MEDIUM — file exists briefly in GitHub history** |

**IMPORTANT CAVEAT:** The file will exist in Git history on GitHub even after the action deletes it. Anyone with repo access can see it in the commit history. For truly sensitive data, this is a **data leak**. The action only removes it from the working tree of HEAD, not from history.

**Verdict: RECOMMENDED for convenience if the brief history exposure is acceptable. NOT suitable if the credentials are high-sensitivity (admin passwords, API keys with broad access).**

---

## Option 8: HYBRID — Pre-push hook + .gitignore (BEST PRACTICAL OPTION)

**Mechanism:** Never commit the buildspec on `main`. Use `.gitignore` + a pre-push safety net.

### Implementation

```bash
# Step 1: Remove buildspec from main branch tracking
git rm --cached .onedev-buildspec.yml
echo '.onedev-buildspec.yml' >> .gitignore
git add .gitignore
git commit -m "Remove buildspec from tracked files (OneDev-only)"

# Step 2: The file still exists on disk (just untracked on main)
# OneDev reads it from its branch where it IS tracked

# Step 3: For OneDev, maintain a separate branch where it's tracked
git checkout -b onedev
# Remove the .gitignore entry for buildspec on this branch
# Or just force-add it:
git add -f .onedev-buildspec.yml
git commit -m "Track buildspec on onedev branch"

# Step 4: Safety hook
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash
REMOTE="$1"
if [ "$REMOTE" = "github" ] || echo "$2" | grep -q "github.com"; then
    while read local_ref local_sha remote_ref remote_sha; do
        if git ls-tree -r "$local_sha" --name-only 2>/dev/null | grep -q '.onedev-buildspec.yml'; then
            echo "BLOCKED: .onedev-buildspec.yml found in $local_ref"
            echo "This file must not be pushed to GitHub."
            exit 1
        fi
    done
fi
EOF
chmod +x .git/hooks/pre-push
```

| Factor | Rating |
|--------|--------|
| Complexity | Medium (one-time setup, two branches) |
| Reliability | **VERY HIGH — structural prevention at push time** |
| Maintenance | Medium (merge main→onedev periodically) |
| Leak risk | **NEAR-ZERO — pre-push hook blocks accidental exposure** |

**Verdict: BEST OVERALL.** Combines the zero-leak guarantee of the branch approach with a structural safety net. The file physically cannot reach GitHub because (a) it's untracked on main and (b) the pre-push hook blocks any branch containing it from being pushed to GitHub.

---

## Comparison Matrix

| Option | Works? | Complexity | Reliability | Leak Risk | Maintenance |
|--------|--------|-----------|-------------|-----------|-------------|
| 1. export-ignore | NO | - | - | HIGH | - |
| 2. Branch-specific | YES | Medium | High | Near-zero | Medium |
| 3. Clean/smudge | NO* | High | Low | High | High |
| 4. GitHub .gitignore | NO | - | - | HIGH | - |
| 5. Push refspec filter | NO | - | - | - | - |
| 6. Subtree/sparse | Impractical | Very High | Low | Low | Very High |
| 7. GitHub Actions delete | YES | Low | High | Low-Medium** | Low |
| 8. Hybrid (recommended) | YES | Medium | Very High | Near-zero | Medium |

\* Clean/smudge can sanitize file *contents* but cannot exclude the file itself
\** File exists briefly in GitHub commit history — visible to anyone with repo access

---

## Final Recommendation

**For your use case (username + internal IPs in `.onedev-buildspec.yml`):**

### If credentials are moderate sensitivity (internal IPs, non-admin username):
Use **Option 7 (GitHub Actions)** — simplest setup, auto-cleans, low maintenance. Accept that the file briefly appears in history.

### If credentials are high sensitivity (must never appear on GitHub, even in history):
Use **Option 8 (Hybrid)** — file is never tracked on GitHub's branch, pre-push hook provides structural enforcement. Worth the merge workflow overhead.

### Quick-start for Option 8:
```bash
# On main branch:
git rm --cached .onedev-buildspec.yml
echo '.onedev-buildspec.yml' >> .gitignore
git commit -m "Exclude OneDev buildspec from GitHub"
git push github main

# Create onedev branch:
git checkout -b onedev
git add -f .onedev-buildspec.yml
git commit -m "Track buildspec on onedev branch"
git push onedev onedev

# Install safety hook (see Option 8 section above)
```

---

## Sources

- [Git gitattributes documentation](https://git-scm.com/docs/gitattributes) — export-ignore only affects `git archive`
- [Red Hat: Protect secrets with clean/smudge filter](https://developers.redhat.com/articles/2022/02/02/protect-secrets-git-cleansmudge-filter) — filter mechanics
- [Git push documentation](https://git-scm.com/docs/git-push) — refspec operates on refs, not paths
- [Git githooks documentation](https://git-scm.com/docs/githooks) — pre-push hook receives remote name as $1
- [OneDev Build Spec docs](https://docs.onedev.io/tutorials/cicd/reuse-buildspec) — buildspec read from branch
- [GitHub: Remove File Action](https://github.com/marketplace/actions/remove-file) — GitHub Actions file deletion
- [Atlassian: Git Subtree](https://www.atlassian.com/git/tutorials/git-subtree) — subtree splits by directory prefix
- [GitHub Docs: Ignoring files](https://docs.github.com/articles/ignoring-files) — .gitignore only for untracked files
