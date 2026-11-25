# test-bundle

> lib/test-bundle.sh: package a commit as a one-commit git bundle so the unit suite can run somewhere else (provider-neutral; caller passes --out and --max-mb).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/test-bundle.sh`

## What It Does

lib/test-bundle.sh: package a commit so the unit suite can run somewhere else.
Builds a git bundle of one commit's tree, the same way every time:
- from a commit (git archive), never from the working folder, so a bundle names one
code version and carries no half-finished edit;
- without three history folders the code under test does not read;
- one commit made with git plumbing (write-tree/commit-tree), which runs no hooks, so
no hook setting is touched; author, committer and dates come from the source commit,
so the same ref always gives the same bundle commit id;
- with --max-mb N, refused (exit 1, nothing written) when over N MB. No cap by default:
a size limit belongs to whatever receives the bundle, so its caller passes it.

---
*Auto-generated from Component Fabric. Card: `lib-test-bundle.yaml`*
*Last verified: 2026-11-09*
