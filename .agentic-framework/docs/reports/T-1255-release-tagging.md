# T-1255 — Release tagging + tag-push gap

**Task:** T-1255
**Type:** Inception (research artifact per C-001)
**Created:** 2026-04-14
**Reporter:** Human observed "GitHub is still on v1.0.0"

## Problem

`https://github.com/DimitriGeelen/agentic-engineering-framework` shows `v1.0.0` as
Latest release while local framework is at VERSION `1.5.614`. Three problems layered:

1. Tags not pushed to remotes (`git push HEAD`, not `--follow-tags`)
2. Only one `v1.5.x` tag exists locally (`v1.5.742` from 2026-04-06) — no bump cadence
3. GitHub Releases are not tags — need `gh release create` on top of tag push

## Spikes

### Spike A — Current-state inventory

Raw evidence gathered this session:

| Surface | State |
|---------|-------|
| `VERSION` file | `1.5.614` |
| `.agentic-framework/VERSION` | `1.5.614` (same, stamped by pre-push hook) |
| `git describe` | `v1.5.742-614-g42009344` |
| Local `v*` tags | v1.0.0, v1.1.0, v1.2.0-v1.2.6, v1.3.0, v1.4.0, **v1.5.742** (12 tags) |
| `github` remote tags | v1.0.0 … v1.4.0 (8 tags — **no v1.5.x**) |
| `onedev` remote tags | v1.0.0 … v1.4.0 (8 tags — **no v1.5.x**) |
| `v1.5.742` tag date | 2026-04-06 (8 days old) |
| Commits since v1.5.742 | 614 |
| handover.sh push | `git push "$remote" HEAD` (line 759) — no `--follow-tags` |

**Finding 1:** The only post-v1.4.0 tag (v1.5.742) was created a week ago and never
pushed anywhere. Every push since has been to `HEAD` only, so the tag remains local.

**Finding 2:** The VERSION file number (`1.5.614`) is synthesised by T-648 pre-push
stamping as `{major.minor of latest tag}.{commit count since that tag}`. It is not a
tag itself and cannot be fetched by anyone.

**Finding 3:** Tag cadence is effectively zero. 614 commits since the last tag with no
intervening bumps. No automated or manual tagging happens on meaningful events
(release-worthy features, breaking changes, consumer-visible fixes).

### Spike B — Tag-cadence options

Four options scored against constitutional directives (Antifragility, Reliability,
Usability, Portability):

| Option | A | R | U | P | Notes |
|--------|:-:|:-:|:-:|:-:|-------|
| 1 — Manual `fw release` command | = | + | − | + | Simple, explicit, requires discipline |
| 2 — Auto-tag on every commit | − | − | − | − | Tag spam, breaks Release semantics |
| 3 — Weekly cron auto-tag if commits since last tag | + | + | = | + | Bounded cadence, survives amnesia |
| 4 — Auto-tag on VERSION-worthy events (release notes file, feature flag) | + | + | − | = | High signal but requires author intent flag |

**Recommended: Option 3 (weekly cron)** — aligns with framework antifragility (system
strengthens under stress — tags happen even if authors forget), reliability (predictable
cadence), and portability (no third-party CI dependency). Cost: one cron entry + small
script that cuts `v1.5.N` if commits exist, skips otherwise.

**Complement with Option 1** — `fw release` remains for explicit cuts between weekly
auto-tags (e.g., hotfix release).

### Spike C — GitHub Release mechanics

`gh` version on host: **2.89.0** (available, authenticated assumed via existing push).

`gh release create v1.5.N --generate-notes --target master` will:
- Create a GitHub Release attached to the tag
- Auto-generate notes from commits since previous release
- Mark as Latest (unless `--latest=false`)

Requirements:
- Tag must exist on `origin` (GitHub) first
- `gh auth status` must be authenticated
- Repo must have a `main`/`master` reference matching

**Automation path:** Extend the weekly auto-tag script to also create the Release,
gated on `gh` being available. Fallback: tag only, warn about Release missing.

### Spike D — Push-fix scope

Two options for fixing the push mechanism:

**Option 1 — One-liner change to handover.sh**
```diff
- if git -C "$PROJECT_ROOT" push "$remote_name" HEAD 2>&1; then
+ if git -C "$PROJECT_ROOT" push --follow-tags "$remote_name" HEAD 2>&1; then
```
`--follow-tags` pushes annotated tags reachable from HEAD. Safe: only pushes tags that
point to commits already being pushed. No risk of leaking local-only tags.

**Option 2 — New `fw git push-tags` subcommand**
Explicit control over which tags get pushed. Useful for backfill ("push only v1.5.742
now, not v1.0.0") but adds surface area.

**Recommended: Option 1 first, Option 2 later if needed.** `--follow-tags` solves the
going-forward problem with zero new surface. For backfilling `v1.5.742`, a one-shot
`git push github v1.5.742 && git push onedev v1.5.742` is enough — doesn't need a
command.

## Findings

1. Tag-push is a one-line fix in `handover.sh:759` (`--follow-tags`)
2. No bump cadence is the bigger problem — even with the push fix, there's nothing
   new to push
3. Weekly cron auto-tag + `gh release create` solves both forward-going
4. Backfill (push `v1.5.742`, maybe cut `v1.5.614` now) is a one-off command,
   not a structural change
5. GitHub "Latest release" widget requires a formal Release, not just a tag —
   so automation must do both

## Recommendation

**Recommendation:** GO — four-part structural fix

**Rationale:** The public-facing release surface has been invisible to consumers for
over a week. Three root causes (push gap, cadence gap, Release gap) are independent
but related; each is bounded, testable, and reversible.

**Proposed changes:**
1. **Push fix** (5 min): `handover.sh:759` use `--follow-tags`. Installed copy and template.
2. **Weekly auto-tag** (30 min): cron job + `lib/release.sh` that cuts `v1.5.N` when
   commits exist since last tag, using the pre-push stamper's formula inverse
   (latest tag → bump patch → tag new commit count or date-based).
3. **Release automation** (15 min): same cron calls `gh release create --generate-notes`
   after successful tag push. Skip gracefully if `gh` unavailable.
4. **Backfill** (5 min): one-shot `git push github v1.5.742 && git push onedev v1.5.742`
   to clear the existing local-only tag. Optionally cut + push `v1.5.614` to match
   current VERSION.

**Evidence:**
- All three remotes/surfaces verified behind: GitHub tags, OneDev tags, GitHub Releases
- `gh` CLI available and recent (v2.89.0)
- `--follow-tags` is standard git, zero new surface
- Cron infrastructure already used for other framework auto-tasks
- No competing inception addresses release surface

**Next step if GO:** Create `T-1256-build: implement weekly release tagging + push-tags fix`
with four sub-deliverables matching the four changes above.

**Go/No-Go criteria:**
- **GO if:** Root cause identified with bounded fix path ✓, Fix is scoped, testable, reversible ✓
- **NO-GO if:** Requires fundamental redesign (no), Cost exceeds benefit (no — cost is ~1h of work)

## Dialogue Log

### 2026-04-14 — Initial observation (human)

> why is https://github.com/DimitriGeelen/agentic-engineering-framework still on v1.0.0
> shoudl be align with build versions ,!!

Agent investigated: local `v1.5.742`, remotes stop at `v1.4.0`, no v1.5.x pushed ever.
VERSION file `1.5.614` is synthetic (pre-push stamping from git describe).

Human chose option 1 (inception with spikes) over option 2 (one-line fix now).
Rationale implied: the push fix alone doesn't help because there's nothing new to
push — the cadence gap is the real root cause.
