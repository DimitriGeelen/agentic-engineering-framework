# fs-root-guard

> T-4406: refuse to use an empty root, or one that is the filesystem root, as the base a writer joins paths onto. "$X/policy" with X empty or "/" is /policy — debris at / (policy/, episodic/, working/) came from exactly that join.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/fs-root-guard.sh`

## What It Does

T-4406: refuse to use an empty root, or one that is the filesystem root, as the
base a writer joins paths onto. "$X/policy" with X empty or "/" is /policy —
debris at / (policy/, episodic/, working/) came from exactly that join.
Sourceable and side-effect-free (unlike lib/paths.sh, which resolves and exports
paths on source), so bin/fw's own libs (init.sh, upgrade.sh) can load it too.
Usage: fw_refuse_fs_root <label> <path> || return 1
rc 0 = usable; rc 1 = refused (message on stderr names the label and the value).

---
*Auto-generated from Component Fabric. Card: `lib-fs-root-guard.yaml`*
*Last verified: 2026-10-19*
