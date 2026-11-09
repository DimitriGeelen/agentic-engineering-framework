#!/usr/bin/env bats
# T-5067 — a temp name for write-then-rename must be unique per WRITER, not per process.
#
# Origin: 1409-sprind's distributor staged files in threads under `<file>.<pid>.tmp`;
# threads share the pid, so they overwrote each other and sent 35 jobs back to local
# (remote-nodes write-up, lesson 4.5, AEF T-5066). AEF had the same shape in 27 places:
# Python `{os.getpid()}` (threads share it) and bash `.$$` (a background subshell sees
# the PARENT's $$). Fix: Python pid plus random bytes (or thread id); bash `${BASHPID:-$$}`.
#
# Allowed on purpose (one writer guaranteed, or not a temp file):
#   agents/audit/audit.sh  .audit-inflight.$$  — per-process marker naming the running audit
#   web/embeddings.py      .reindex.<pid>.tmp and .<pid>.building — written only under an
#                          exclusive flock, and _SCRATCH_RE parses the pid to sweep dead owners

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
}

_scan() {   # $1 = root to scan; prints file:line for every pid-only temp name
    python3 -I - "$1" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
ALLOW = [
    ("agents/audit/audit.sh", ".audit-inflight.$$"),
    ("web/embeddings.py", ".reindex.{os.getpid()}.tmp"),
    ("web/embeddings.py", "{os.getpid()}.building"),
]
bash_re = re.compile(r'\.\$\$')                       # ".$$" — not "${BASHPID:-$$}"
# ${BASHPID} in the redirect target of a command expands in the FORKED child (measured:
# `awk ... > f.${BASHPID}` names awk's pid), so the parent's later `cat f.${BASHPID}`
# reads another file. Fix the name in a variable first. A `{ ... } > f` group does not
# fork, so a line that starts with `}` is fine.
redir_re = re.compile(r'[0-9&]?>>?\s*"?[^\s;|&]*BASHPID')
py_re = re.compile(r'\{os\.getpid\(\)\}(?!-\{os\.urandom|\.\{threading|\.\{secrets)')
for sub in ("lib", "agents", "bin", "web"):
    base = root / sub
    if not base.is_dir():
        continue
    for p in sorted(base.rglob("*")):
        if not p.is_file() or "/.agentic-framework/" in str(p):
            continue
        is_py = p.suffix == ".py"
        is_sh = p.suffix == ".sh" or (p.parent.name == "bin" and p.suffix == "")
        if not (is_py or is_sh):
            continue
        rel = str(p.relative_to(root))
        try:
            lines = p.read_text(errors="replace").splitlines()
        except OSError:
            continue
        for n, line in enumerate(lines, 1):
            if line.lstrip().startswith("#"):
                continue
            if is_sh and redir_re.search(line) and not line.lstrip().startswith("}"):
                print(f"{rel}:{n}: BASHPID in a redirect expands in the child — use a variable: {line.strip()[:100]}")
                continue
            hit = (is_sh and bash_re.search(line)) or \
                  (is_py and py_re.search(line) and re.search(r"tmp|temp|building", line, re.I))
            if not hit:
                continue
            if re.search(r"mk[sd]temp\(|NamedTemporaryFile\(|\bmktemp\b", line):
                continue   # these add their own random part to the pid prefix

            if any(rel == f and s in line for f, s in ALLOW):
                continue
            print(f"{rel}:{n}: {line.strip()[:120]}")
PY
}

@test "T-5067: no temp name in lib/ agents/ bin/ web/ is keyed on the process id alone" {
    run _scan "$FW_ROOT"
    [ "$status" -eq 0 ]
    if [ -n "$output" ]; then
        echo "pid-only temp names (use \${BASHPID:-\$\$} in bash, pid + os.urandom(4).hex() in Python):" >&2
        echo "$output" >&2
        return 1
    fi
}

@test "T-5067/control: the scanner flags a pid-only name in bash and in Python" {
    d="$(mktemp -d)"
    mkdir -p "$d/lib"
    printf 'tmp="$f.tmp.$$"\n' > "$d/lib/a.sh"
    printf 'tmp = p.with_suffix(f".json.{os.getpid()}.tmp")\n' > "$d/lib/b.py"
    printf 'tmp="$f.tmp.${BASHPID:-$$}"\n' > "$d/lib/ok.sh"
    printf 'tmp = p.with_suffix(f".json.{os.getpid()}-{os.urandom(4).hex()}.tmp")\n' > "$d/lib/ok.py"
    printf 'awk 1 f > /tmp/x.${BASHPID:-$$}\n' > "$d/lib/redir.sh"
    printf '    } > "$f.${BASHPID:-$$}" 2>/dev/null\n' > "$d/lib/group.sh"
    run _scan "$d"
    rm -rf "$d"
    [[ "$output" == *"lib/redir.sh:1"* ]]
    [[ "$output" != *"group.sh"* ]]
    [[ "$output" == *"lib/a.sh:1"* ]]
    [[ "$output" == *"lib/b.py:1"* ]]
    [[ "$output" != *"ok.sh"* ]]
    [[ "$output" != *"ok.py"* ]]
}
