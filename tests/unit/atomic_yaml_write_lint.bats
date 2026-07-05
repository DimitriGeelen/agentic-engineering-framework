#!/usr/bin/env bats
# T-100191: corpus-wide ratchet — no truncating YAML writers under lib/ and
# agents/ without an atomic-write signal in the same file.
#
# Origin: fourth instance of the non-atomic-YAML-write class (L-493):
# T-2457 (fabric cards), T-2456 (fw note inbox), T-100190 (audit
# metrics-history — a cron audit killed mid-`yaml.dump` truncated the file
# and the pre-push YAML gate blocked ALL pushes until manual recovery).
# T-100191 swept the remaining 14 writer files; this lint keeps the corpus
# clean: any NEW file that dumps YAML without temp+os.replace fails here.
#
# Granularity note: the check is FILE-level (mirrors the census method) —
# a file with one atomic site and one new truncating site would pass. The
# ratchet catches the dominant class: new writer files and files that never
# adopted the pattern. Site-level linting would need real AST analysis.

FRAMEWORK_DIR="$BATS_TEST_DIRNAME/../.."

@test "every lib/ and agents/ file that dumps YAML has an atomic-write signal" {
    run python3 - << 'PY'
import pathlib, re, sys

ROOT = pathlib.Path(".")

# Files whose yaml dumps never reach a file directly (string-only) or are
# test-scope fixtures. Each entry carries its reason — extend deliberately.
EXEMPT = {
    "lib/integrate.py":
        "string-only dumps: bodies are returned to the merge driver, "
        "which writes via git plumbing, not this module",
    "agents/docgen/test_docgen.py":
        "test fixture writer; regenerable test-scope output",
}

# A to-file YAML dump signal (PyYAML, ruamel alias forms used in this repo).
DUMP = re.compile(r"(?:yaml\.dump\(|yaml\.safe_dump\(|yaml_r\.dump\(|_ruamel_yaml\.dump\(|_ruamel\.dump\()")
# Accepted atomicity signals: stdlib os.replace, pathlib tmp.replace
# (lib/reviewer style), or a local _atomic_write_text helper.
ATOMIC = re.compile(r"(?:os\.replace\(|tmp\.replace\(|_atomic_write_text\()")

bad = []
for base in ("lib", "agents"):
    for p in sorted(ROOT.joinpath(base).rglob("*")):
        if p.suffix not in (".sh", ".py"):
            continue
        rel = p.as_posix()
        if rel in EXEMPT:
            continue
        try:
            src = p.read_text()
        except (UnicodeDecodeError, OSError):
            continue
        if DUMP.search(src) and not ATOMIC.search(src):
            bad.append(rel)

if bad:
    print("Truncating YAML writer(s) without atomic-write signal (L-493 class):")
    for rel in bad:
        print(f"  {rel} — use same-dir temp + os.replace (see T-100191)")
    sys.exit(1)
print("OK: all YAML-dumping files under lib/ and agents/ carry an atomic-write signal")
PY
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "exempt list entries still exist and still dump YAML (no stale exemptions)" {
    run python3 - << 'PY'
import pathlib, re, sys

EXEMPT = ["lib/integrate.py", "agents/docgen/test_docgen.py"]
DUMP = re.compile(r"(?:yaml\.dump\(|yaml\.safe_dump\()")
stale = []
for rel in EXEMPT:
    p = pathlib.Path(rel)
    if not p.is_file() or not DUMP.search(p.read_text()):
        stale.append(rel)
if stale:
    print("Stale exempt entries (file gone or no longer dumps YAML) — prune from lint:")
    for rel in stale:
        print(f"  {rel}")
    sys.exit(1)
print("OK: exempt list is live")
PY
    echo "$output"
    [ "$status" -eq 0 ]
}

setup() {
    cd "$FRAMEWORK_DIR" || exit 1
}
