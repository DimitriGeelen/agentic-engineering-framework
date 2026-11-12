#!/usr/bin/env bash
# aef-testhost-boot.sh — the test VM's only job (T-5099; T-5009 design A, section 8b).
# Runs once at boot as root, from aef-testhost.service, stdout/stderr on the serial console.
#  1. find the CD labelled AEFRUN, mount it read-only
#  2. copy it into /root/aefrun (mode 0700): the run's nonce stays unreadable for the PR's user
#  3. unmount the CD
#  4. run guest-run.sh from the COPY (this framework's released copy, never the PR's) as root;
#     it drops to the unprivileged `testhost` user for the PR's code
#  5. power off. The controller destroys the VM afterwards.
# No network is configured; the VM has no network card. Nothing here reads the PR's files.
set -uo pipefail
echo "== aef-testhost boot =="
dev="$(blkid -L AEFRUN 2>/dev/null || true)"
if [ -z "$dev" ]; then
    echo "== aef-testhost: no AEFRUN CD attached; powering off =="
    systemctl poweroff; exit 0
fi
mnt="$(mktemp -d)"
mount -o ro,nosuid,nodev,noexec "$dev" "$mnt"
install -d -m 0700 /root/aefrun /root/aefout
cp -a "$mnt"/. /root/aefrun/
umount "$mnt"; rmdir "$mnt"
chmod -R go-rwx /root/aefrun
PATH="/opt/aef-venv/bin:$PATH" TMPDIR=/var/tmp \
    bash /root/aefrun/guest-run.sh /root/aefrun /root/aefout
echo "== aef-testhost: done, powering off =="
systemctl poweroff
