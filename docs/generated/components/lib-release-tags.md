# release-tags

> lib/release-tags.sh — the one place that resolves "the latest release tag" (T-4431)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/release-tags.sh`

## What It Does

lib/release-tags.sh — the one place that resolves "the latest release tag" (T-4431)
Bleeding-edge pre-releases are tagged vX.Y.Z-be.N (T-4023) so field projects
can pin them. They are NOT releases: a -be tag cut on bleeding-edge becomes the
nearest tag, and a bare `git describe --tags` reads it as the release version
(1.8.14-be.1 — and 1.8.14-be.1-3-gSHA is not even semver). Every latest-release,
tag-floor and next-version lookup therefore goes through release_tags_describe,
which always passes --exclude "$RELEASE_PRERELEASE_TAG_EXCLUDE".
Two callers cannot source this file and inline the same --exclude instead:
bin/fw _derive_version (runs before FW_LIB_DIR is resolved) and the pre-push
VERSION stamp in agents/git/lib/hooks.sh. tests/unit/t4431_be_tags.bats pins

---
*Auto-generated from Component Fabric. Card: `lib-release-tags.yaml`*
*Last verified: 2026-10-19*
