# test-bundle

> lib/test-bundle.sh — T-5070: build the package node1 runs AEF's unit suite from.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/test-bundle.sh`

## What It Does

lib/test-bundle.sh — T-5070: build the package node1 runs AEF's unit suite from.
Measured in T-5069 (docs/reports/T-5069-node1-unit-suite-spec.md): the tests need a git
repository, and a git bundle of a trimmed tree with ONE commit is 46.2 MB, under the node's
64 MB stage limit. This builds that bundle the same way every time:
- from a commit (git archive), never from the working folder, so a bundle names one
code version and carries no half-finished edit;
- without three history folders the code under test does not read;
- one commit made with git plumbing (write-tree/commit-tree), which runs no hooks, so
no hook setting is touched; author, committer and dates come from the source commit,
so the same ref always gives the same bundle commit id;

---
*Auto-generated from Component Fabric. Card: `lib-test-bundle.yaml`*
*Last verified: 2026-11-09*
