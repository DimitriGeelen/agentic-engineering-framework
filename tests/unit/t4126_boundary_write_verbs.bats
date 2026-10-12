#!/usr/bin/env bats
# T-4126: check-project-boundary Pattern 3 knew only redirects and tee as writes,
# so `cp /tmp/a /etc/fstab` (and mv/install/ln/dd/sed -i/...) exited 0 — Pattern 4
# allowlists /etc/ for reads. Each verb now names its written operands.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ -x "$HOOK" ]
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
}

run_hook() {
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$1")
    echo "$payload" | bash "$HOOK"
}

blocks() {
    run run_hook "$1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "File write to"
}

allows() {
    run run_hook "$1"
    [ "$status" -eq 0 ]
}

# ── outside destinations block ──
@test "cp outside" { blocks 'cp /tmp/a /etc/fstab'; }
@test "cp -a options first" { blocks 'cp -a -f /tmp/a /srv/x'; }
@test "cp -- end of options" { blocks 'cp -- /tmp/a /srv/x'; }
@test "cp -t DIR" { blocks 'cp -t /srv/dir /tmp/a'; }
@test "cp -tDIR glued" { blocks 'cp -t/srv/dir /tmp/a'; }
@test "cp --target-directory=DIR" { blocks 'cp --target-directory=/srv/dir /tmp/a'; }
@test "cp multiple sources" { blocks 'cp /tmp/a /tmp/b /srv/dir/'; }
@test "mv destination outside" { blocks 'mv /tmp/a /srv/x'; }
@test "mv source outside is removed" { blocks 'mv /srv/x /tmp/a'; }
@test "mv -t" { blocks 'mv -t /srv/dir /tmp/a'; }
@test "install outside" { blocks 'install -m 755 /tmp/a /usr/local/bin/a'; }
@test "install -t" { blocks 'install -t /usr/local/bin /tmp/a'; }
@test "ln -s target path outside" { blocks 'ln -sf /tmp/a /srv/link'; }
@test "ln -T" { blocks 'ln -sfT /tmp/a /srv/link'; }
@test "dd of= outside" { blocks 'dd if=/dev/zero of=/srv/img bs=1M count=1'; }
@test "rsync outside" { blocks 'rsync -a /tmp/a/ /srv/b/'; }
@test "rsync -e ssh then outside" { blocks 'rsync -e ssh -a /tmp/a /srv/b'; }
@test "sed -i outside" { blocks 'sed -i s/a/b/ /etc/hosts'; }
@test "sed -i.bak outside" { blocks 'sed -i.bak s/a/b/ /etc/hosts'; }
@test "sed --in-place outside" { blocks 'sed --in-place s/a/b/ /etc/hosts'; }
@test "sed -n -i -e outside" { blocks 'sed -n -i -e p /etc/hosts'; }
@test "sed -i with /re/ script outside" { blocks 'sed -i /foo/d /srv/f'; }
@test "perl -pi -e outside" { blocks 'perl -pi -e s/a/b/ /etc/hosts'; }
@test "truncate outside" { blocks 'truncate -s 0 /srv/log'; }
@test "chmod outside" { blocks 'chmod 777 /srv/x'; }
@test "chmod -R outside" { blocks 'chmod -R u+x /srv/x'; }
@test "chown outside" { blocks 'chown root:root /srv/x'; }
@test "touch outside" { blocks 'touch /srv/x'; }
@test "mkdir -p outside" { blocks 'mkdir -p /srv/x'; }
@test ">| redirect outside" { blocks 'echo x >| /etc/fstab'; }
@test "sudo prefix" { blocks 'sudo cp /tmp/a /etc/fstab'; }
@test "sudo -u prefix" { blocks 'sudo -u root cp /tmp/a /etc/fstab'; }
@test "env VAR prefix" { blocks 'FOO=1 cp /tmp/a /etc/fstab'; }
@test "env wrapper" { blocks 'env -i cp /tmp/a /etc/fstab'; }
@test "absolute /usr/bin/cp" { blocks '/usr/bin/cp /tmp/a /etc/fstab'; }
@test "absolute /bin/mv" { blocks '/bin/mv /tmp/a /srv/x'; }
@test "after && chain" { blocks 'true && cp /tmp/a /etc/fstab'; }
@test "after pipe" { blocks 'echo x | cp /tmp/a /etc/fstab'; }

# ── /tmp and in-project writes stay allowed ──
@test "allow cp to /tmp" { allows 'cp /etc/hosts /tmp/hosts'; }
@test "allow cp from outside (read side) into project" { allows "cp /etc/hosts $FRAMEWORK_ROOT/.context/scratch/h"; }
@test "allow cp -t /tmp" { allows 'cp -t /tmp/d /etc/hosts'; }
@test "allow mv in project" { allows "mv $FRAMEWORK_ROOT/.context/scratch/a $FRAMEWORK_ROOT/.context/scratch/b"; }
@test "allow install to project" { allows "install -m 644 /tmp/a $FRAMEWORK_ROOT/.context/scratch/a"; }
@test "allow ln into /tmp" { allows 'ln -sf /etc/hosts /tmp/h'; }
@test "allow dd to /tmp" { allows 'dd if=/dev/zero of=/tmp/img bs=1 count=1'; }
@test "allow dd to /dev/null" { allows 'dd if=/etc/hosts of=/dev/null'; }
@test "allow rsync into project" { allows "rsync -a /tmp/a/ $FRAMEWORK_ROOT/.context/scratch/b/"; }
@test "allow sed -i in project" { allows "sed -i s/a/b/ $FRAMEWORK_ROOT/README.md"; }
@test "allow sed -i /tmp" { allows 'sed -i /foo/d /tmp/f'; }
@test "allow sed without -i reads outside" { allows 'sed -n p /etc/hosts'; }
@test "allow perl -MFile::Find outside read" { allows 'perl -MFile::Find -e 1 /etc/hosts'; }
@test "allow chmod /tmp" { allows 'chmod 600 /tmp/x'; }
@test "allow chmod in project" { allows "chmod +x $FRAMEWORK_ROOT/bin/fw"; }
@test "allow touch /tmp" { allows 'touch /tmp/x'; }
@test "allow mkdir -p /tmp" { allows 'mkdir -p /tmp/a/b'; }
@test "allow truncate in project" { allows "truncate -s 0 $FRAMEWORK_ROOT/.context/scratch/x"; }
@test "allow >| /tmp" { allows 'echo x >| /tmp/x'; }
@test "allow sudo cp into /tmp" { allows 'sudo cp /etc/hosts /tmp/h'; }
@test "allow cp relative paths" { allows 'cp a b'; }
@test "allow grep mentioning cp" { allows 'grep -r cp /etc/hosts'; }
@test "allow cat outside (read side unchanged)" { allows 'cat /etc/hosts'; }
