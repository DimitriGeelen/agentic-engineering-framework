# aef-testhost-boot

> aef-testhost-boot.sh — the test VM's only job (T-5099; T-5009 design A, section 8b). Runs once at boot as root, from aef-testhost.service, stdout/stderr on the serial console. 1. find the CD labelled AEFRUN, mount it read-only 2.

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/testhost/template/aef-testhost-boot.sh`

## What It Does

aef-testhost-boot.sh — the test VM's only job (T-5099; T-5009 design A, section 8b).
Runs once at boot as root, from aef-testhost.service, stdout/stderr on the serial console.
1. find the CD labelled AEFRUN, mount it read-only
2. copy it into /root/aefrun (mode 0700): the run's nonce stays unreadable for the PR's user
3. unmount the CD
4. run guest-run.sh from the COPY (this framework's released copy, never the PR's) as root;
it drops to the unprivileged `testhost` user for the PR's code
5. power off. The controller destroys the VM afterwards.
No network is configured; the VM has no network card. Nothing here reads the PR's files.

---
*Auto-generated from Component Fabric. Card: `agents-testhost-template-aef-testhost-boot.yaml`*
*Last verified: 2026-11-12*
