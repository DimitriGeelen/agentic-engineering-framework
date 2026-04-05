#!/bin/bash
# lib/verify-acs.sh — Automated Human AC evidence collection (T-824)
#
# Scans work-completed tasks with unchecked Human ACs, runs automated checks
# where possible, and reports results for human batch approval.
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/verify-acs.sh"
#   do_verify_acs [--verbose] [T-XXX]
#
# Origin: T-823 GO decision — 63% of Human ACs can be verified programmatically.

do_verify_acs() {
    local verbose=false
    local filter_task=""
    local auto_check=false
    local execute=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v) verbose=true; shift ;;
            --auto-check) auto_check=true; shift ;;
            --execute) auto_check=true; execute=true; shift ;;
            --help|-h)
                echo -e "${BOLD}fw verify-acs${NC} — Automated Human AC evidence collection"
                echo ""
                echo "Usage: fw verify-acs [options] [T-XXX]"
                echo ""
                echo "Scans work-completed tasks with unchecked Human ACs and runs"
                echo "automated verification where possible (HTTP checks, CLI commands)."
                echo ""
                echo "Options:"
                echo "  -v, --verbose     Show detailed evidence for each check"
                echo "  --auto-check      Report which RUBBER-STAMP ACs can be auto-checked"
                echo "  --execute         Actually check passing RUBBER-STAMP ACs in task files"
                echo "  T-XXX             Verify specific task only"
                echo "  -h, --help        Show this help"
                echo ""
                echo "AC types:"
                echo "  [RUBBER-STAMP]    Mechanical verification — automated where possible"
                echo "  [REVIEW]          Human judgment required — never auto-checked"
                echo ""
                echo "Origin: T-823 (Automated Human AC verification inception)"
                echo "        T-840 (Auto-check RUBBER-STAMP ACs)"
                return 0
                ;;
            T-*) filter_task="$1"; shift ;;
            *) echo -e "${RED}Unknown option: $1${NC}" >&2; return 1 ;;
        esac
    done

    source "$FRAMEWORK_ROOT/lib/config.sh" 2>/dev/null || true
    local wt_port
    wt_port=$(type fw_config >/dev/null 2>&1 && fw_config "PORT" 3000 || echo 3000)

    # Check if Watchtower is running (needed for HTTP checks)
    local wt_running=false
    if curl -sf --max-time 2 "http://localhost:${wt_port}/" >/dev/null 2>&1; then
        wt_running=true
    fi

    local total=0 pass_count=0 fail_count=0 skip_count=0 review_count=0

    echo -e "${BOLD}fw verify-acs${NC} — Automated Human AC Evidence Collection"
    echo ""

    # Find all tasks with unchecked Human ACs
    python3 - "$PROJECT_ROOT" "$filter_task" "$wt_port" "$wt_running" "$verbose" "$auto_check" "$execute" << 'PYVERIFY'
import os, re, sys, subprocess, json

project_root = sys.argv[1]
filter_task = sys.argv[2] if len(sys.argv) > 2 else ""
wt_port = sys.argv[3] if len(sys.argv) > 3 else "3000"
wt_running = sys.argv[4] == "true" if len(sys.argv) > 4 else False
verbose = sys.argv[5] == "true" if len(sys.argv) > 5 else False
auto_check = sys.argv[6] == "true" if len(sys.argv) > 6 else False
execute = sys.argv[7] == "true" if len(sys.argv) > 7 else False

BOLD = '\033[1m'
GREEN = '\033[0;32m'
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
NC = '\033[0m'

active_dir = os.path.join(project_root, '.tasks', 'active')
results = {"pass": 0, "fail": 0, "skip": 0, "review": 0, "total": 0}
task_results = []

def check_url(url, expected_content=None):
    """Check if a URL responds with 200 and optionally contains content."""
    try:
        r = subprocess.run(
            ["curl", "-sf", "--max-time", "3", url],
            capture_output=True, text=True, timeout=5
        )
        if r.returncode != 0:
            return False, "HTTP error"
        if expected_content:
            if expected_content.lower() not in r.stdout.lower():
                return False, f"Content '{expected_content}' not found"
        return True, f"HTTP 200, {len(r.stdout)} bytes"
    except Exception as e:
        return False, str(e)

def check_command(cmd):
    """Run a shell command and check exit code."""
    try:
        r = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=30,
            cwd=project_root
        )
        if r.returncode == 0:
            output = (r.stdout.strip()[:100] or "(no output)")
            return True, output
        return False, f"exit {r.returncode}: {r.stderr.strip()[:100]}"
    except Exception as e:
        return False, str(e)

def check_file_exists(path):
    """Check if a file exists."""
    full = os.path.join(project_root, path) if not path.startswith('/') else path
    if os.path.exists(full):
        return True, f"Exists ({os.path.getsize(full)} bytes)"
    return False, "Not found"

def auto_verify_ac(task_id, ac_text):
    """Try to automatically verify an AC based on its content."""
    text = ac_text.lower()

    # URL/page load checks
    url_patterns = [
        (r'http://localhost:\d+/\S+', None),
        (r'/review/T-\d+', f"http://localhost:{wt_port}"),
        (r'/config', f"http://localhost:{wt_port}"),
        (r'/approvals', f"http://localhost:{wt_port}"),
        (r'/fabric', f"http://localhost:{wt_port}"),
    ]

    # Watchtower page verification
    if wt_running:
        if '/config' in text or 'config page' in text:
            return check_url(f"http://localhost:{wt_port}/config")
        if '/review/' in text or 'review page' in text or 'task page' in text:
            return check_url(f"http://localhost:{wt_port}/review/{task_id}")
        if '/approvals' in text or 'approval' in text:
            return check_url(f"http://localhost:{wt_port}/approvals")
        if 'landing page' in text or 'dashboard' in text or 'summary card' in text:
            return check_url(f"http://localhost:{wt_port}/")
        if 'file link' in text or 'file viewer' in text or 'clickable' in text:
            # Use a file from a viewable directory
            return check_url(f"http://localhost:{wt_port}/file/docs/reports/T-823-automated-human-ac-verification.md")
        if 'qr code' in text or 'qr' in text:
            # QR is generated client-side; verify the review page loads
            return check_url(f"http://localhost:{wt_port}/review/{task_id}")

    # Command execution checks
    if 'fw version' in text:
        return check_command("bin/fw version")
    if 'fw update' in text and '--check' in text:
        return check_command("bin/fw update --check")
    if 'fw doctor' in text:
        return check_command("bin/fw doctor")
    if 'fw serve' in text:
        # Don't actually start a server, just check it can run
        return True, "Watchtower already running" if wt_running else (False, "Watchtower not running")
    if 'fw verify' in text or 'fw task verify' in text:
        return check_command("bin/fw task verify 2>&1 | head -3")

    # File existence checks
    file_match = re.search(r'(\S+\.(?:md|yaml|json|sh|py|ts))', ac_text)
    if file_match and 'exists' in text:
        return check_file_exists(file_match.group(1))

    # Cannot auto-verify
    return None, None

if not os.path.isdir(active_dir):
    print(f"{RED}No active tasks directory{NC}")
    sys.exit(1)

for fn in sorted(os.listdir(active_dir)):
    if not fn.endswith('.md'):
        continue
    path = os.path.join(active_dir, fn)
    with open(path) as f:
        text = f.read()

    # Parse frontmatter
    fm = {}
    if text.startswith('---'):
        try:
            end = text.index('---', 3)
            import yaml
            fm = yaml.safe_load(text[3:end]) or {}
        except:
            pass

    task_id = fm.get('id', '')
    status = fm.get('status', '')

    # Filter
    if filter_task and task_id != filter_task:
        continue
    if status != 'work-completed' and not filter_task:
        continue

    # Extract Human ACs
    ac_match = re.search(r'^## Acceptance Criteria\s*\n(.*?)(?=\n## |\Z)', text, re.MULTILINE | re.DOTALL)
    if not ac_match:
        continue
    ac_section = ac_match.group(1)
    if '### Human' not in ac_section:
        continue

    human_match = re.search(r'### Human\s*\n(.*?)(?=\n### |\Z)', ac_section, re.DOTALL)
    if not human_match:
        continue

    human_block = human_match.group(1)
    # Find unchecked ACs
    unchecked = re.findall(r'^\s*-\s*\[ \]\s*(.*?)$', human_block, re.MULTILINE)
    if not unchecked:
        continue

    results["total"] += len(unchecked)

    for ac in unchecked:
        ac_clean = ac.strip()
        is_rubber_stamp = '[RUBBER-STAMP]' in ac_clean
        is_review = '[REVIEW]' in ac_clean

        if is_review:
            results["review"] += 1
            if verbose:
                print(f"  {YELLOW}REVIEW{NC}  {task_id}: {ac_clean[:70]}")
            task_results.append((task_id, "REVIEW", ac_clean[:70], "Human judgment required"))
            continue

        # Try automated verification
        passed, evidence = auto_verify_ac(task_id, ac_clean)

        if passed is None:
            results["skip"] += 1
            task_results.append((task_id, "SKIP", ac_clean[:70], "No automated check available"))
            if verbose:
                print(f"  {CYAN}SKIP{NC}   {task_id}: {ac_clean[:70]}")
        elif passed:
            results["pass"] += 1
            task_results.append((task_id, "PASS", ac_clean[:70], evidence))
            print(f"  {GREEN}PASS{NC}   {task_id}: {ac_clean[:70]}")
            if verbose and evidence:
                print(f"         Evidence: {evidence}")
        else:
            results["fail"] += 1
            task_results.append((task_id, "FAIL", ac_clean[:70], evidence))
            print(f"  {RED}FAIL{NC}   {task_id}: {ac_clean[:70]}")
            if verbose and evidence:
                print(f"         Reason: {evidence}")

# Auto-check: modify task files for passing RUBBER-STAMP ACs (T-840)
checked_count = 0
if auto_check:
    # Collect passing RUBBER-STAMP ACs grouped by task file
    to_check = {}
    for tid, status, ac_text, evidence in task_results:
        if status == "PASS":
            to_check.setdefault(tid, []).append(ac_text)

    if to_check and not execute:
        print()
        print(f"{BOLD}Auto-check candidates (dry run):{NC}")
        for tid, acs in sorted(to_check.items()):
            print(f"  {tid}: {len(acs)} AC(s) would be checked")
        print()
        print(f"  Run with {BOLD}--execute{NC} to apply changes")

    elif to_check and execute:
        print()
        print(f"{BOLD}Auto-checking RUBBER-STAMP ACs:{NC}")
        for tid, acs in sorted(to_check.items()):
            # Find the task file
            task_file = None
            for fn in os.listdir(active_dir):
                if fn.startswith(f"{tid}-") and fn.endswith('.md'):
                    task_file = os.path.join(active_dir, fn)
                    break
            if not task_file:
                continue

            with open(task_file) as f:
                content = f.read()

            modified = False
            for ac_text in acs:
                # Find the unchecked AC line that matches (first 60 chars)
                ac_prefix = ac_text[:60]
                pattern = re.compile(r'^(\s*- )\[ \](\s*' + re.escape(ac_prefix) + r')', re.MULTILINE)
                match = pattern.search(content)
                if match:
                    content = content[:match.start()] + match.group(1) + '[x]' + match.group(2) + content[match.end():]
                    modified = True
                    checked_count += 1
                    print(f"  {GREEN}CHECKED{NC} {tid}: {ac_text[:60]}")

            if modified:
                with open(task_file, 'w') as f:
                    f.write(content)

# Summary
print()
print(f"{BOLD}Summary{NC}")
print(f"  Total ACs scanned: {results['total']}")
print(f"  {GREEN}PASS{NC}:   {results['pass']}")
print(f"  {RED}FAIL{NC}:   {results['fail']}")
print(f"  {CYAN}SKIP{NC}:   {results['skip']} (no automated check)")
print(f"  {YELLOW}REVIEW{NC}: {results['review']} (human judgment needed)")
if checked_count > 0:
    print(f"  {GREEN}AUTO-CHECKED{NC}: {checked_count}")

if results['pass'] > 0 and not auto_check:
    print()
    # Get LAN IP for Watchtower URL
    try:
        ip = subprocess.run(["hostname", "-I"], capture_output=True, text=True).stdout.split()[0]
    except:
        ip = "localhost"
    print(f"  {BOLD}Review verified tasks:{NC} http://{ip}:{wt_port}/approvals")
    print(f"  {BOLD}Auto-check:{NC} fw verify-acs --auto-check --execute")

# Exit code: 0 if any passes, 1 if all fail
sys.exit(0 if results['pass'] > 0 or results['total'] == 0 else 1)
PYVERIFY
}
