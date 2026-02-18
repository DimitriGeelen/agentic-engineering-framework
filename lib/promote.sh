#!/bin/bash
# Graduation Pipeline — fw promote
#
# Implements the knowledge graduation pipeline from 015-Practices.md:
#   Task Update → Learning (2+ tasks) → Practice (3+ applications) → Directive
#
# Commands:
#   suggest     Show learnings ready for promotion (3+ applications)
#   status      Show all learnings with application counts
#   L-XXX       Promote a specific learning to practice
#
# Usage:
#   fw promote suggest
#   fw promote status
#   fw promote L-008 --name "Avoid ((x++)) in set -e scripts" --directive D1

do_promote() {
    local subcmd="${1:-}"
    shift || true

    case "$subcmd" in
        suggest|status|L-*)
            python3 - "$subcmd" "$@" << 'PYPROMOTE'
import os, sys, yaml, re
from datetime import datetime

subcmd = sys.argv[1]
args = sys.argv[2:]

project_root = os.environ.get('PROJECT_ROOT', '.')
learnings_file = os.path.join(project_root, '.context', 'project', 'learnings.yaml')
practices_file = os.path.join(project_root, '.context', 'project', 'practices.yaml')
episodic_dir = os.path.join(project_root, '.context', 'episodic')
tasks_dir = os.path.join(project_root, '.tasks')

BOLD = '\033[1m'
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
NC = '\033[0m'

# Load learnings
if not os.path.isfile(learnings_file):
    print(f'{RED}No learnings file found{NC}')
    sys.exit(1)

with open(learnings_file) as f:
    l_data = yaml.safe_load(f) or {}
learnings = l_data.get('learnings', [])

# Load practices
practices = []
if os.path.isfile(practices_file):
    with open(practices_file) as f:
        p_data = yaml.safe_load(f) or {}
    practices = p_data.get('practices', [])

# Build a set of learning IDs already promoted
promoted_ids = set()
for p in practices:
    origin = p.get('derived_from', '')
    # Check if any learning was the origin
    # Practices can derive from directives (D1) or learnings (L-001)
    if isinstance(origin, str) and origin.startswith('L-'):
        promoted_ids.add(origin)
    elif isinstance(origin, list):
        for o in origin:
            if str(o).startswith('L-'):
                promoted_ids.add(str(o))

# Count applications: scan episodics, tasks, and patterns for learning references
def count_applications(learning_id, learning_text):
    """Count how many distinct tasks/episodics reference this learning or its pattern."""
    count = 0
    referenced_tasks = set()

    # The learning's own task
    # Don't count origin task — that's where it was created, not applied

    # Search episodics for references to this learning or similar text
    if os.path.isdir(episodic_dir):
        for fn in os.listdir(episodic_dir):
            if not fn.endswith('.yaml') or fn == 'TEMPLATE.yaml':
                continue
            try:
                with open(os.path.join(episodic_dir, fn)) as f:
                    content = f.read()
                if learning_id in content:
                    tid = fn.replace('.yaml', '')
                    referenced_tasks.add(tid)
            except:
                continue

    # Search task update sections for learning references
    for subdir in ['active', 'completed']:
        td = os.path.join(tasks_dir, subdir)
        if not os.path.isdir(td):
            continue
        for fn in os.listdir(td):
            if not fn.endswith('.md'):
                continue
            try:
                with open(os.path.join(td, fn)) as f:
                    content = f.read()
                if learning_id in content:
                    # Extract task ID
                    m = re.match(r'(T-\d+)', fn)
                    if m:
                        referenced_tasks.add(m.group(1))
            except:
                continue

    # Search patterns for references
    patterns_file = os.path.join(project_root, '.context', 'project', 'patterns.yaml')
    if os.path.isfile(patterns_file):
        try:
            with open(patterns_file) as f:
                content = f.read()
            if learning_id in content:
                count += 1  # Pattern reference counts as 1 application
        except:
            pass

    return len(referenced_tasks) + count


# --- SUGGEST command ---
if subcmd == 'suggest':
    print(f'{BOLD}Promotion Candidates{NC} (learnings with 3+ applications)')
    print()

    candidates = []
    for l in learnings:
        lid = l.get('id', '')
        if lid in promoted_ids:
            continue
        apps = count_applications(lid, l.get('learning', ''))
        if apps >= 3:
            candidates.append((l, apps))

    if not candidates:
        # Check if any are close (2 applications)
        close = []
        for l in learnings:
            lid = l.get('id', '')
            if lid in promoted_ids:
                continue
            apps = count_applications(lid, l.get('learning', ''))
            if apps == 2:
                close.append((l, apps))

        print(f'  {YELLOW}No learnings currently meet the 3-application threshold{NC}')
        if close:
            print()
            print(f'{BOLD}Almost Ready{NC} (2 applications — one more and they qualify)')
            for l, apps in close:
                print(f'  {CYAN}{l["id"]}{NC} ({apps} apps): {l.get("learning", "")}')
        print()
        print(f'  Total learnings: {len(learnings)}')
        print(f'  Already promoted: {len(promoted_ids)}')
        print(f'  Tip: Apply learnings explicitly in task updates to build evidence')
    else:
        candidates.sort(key=lambda x: -x[1])
        for l, apps in candidates:
            lid = l.get('id', '')
            text = l.get('learning', '')
            task = l.get('task', '')
            print(f'  {GREEN}{lid}{NC} ({apps} applications): {text}')
            print(f'    Origin: {task} | Source: {l.get("source", "?")}')
            print(f'    {CYAN}Promote:{NC} fw promote {lid} --name "..." --directive D1')
            print()

        print(f'{len(candidates)} learning(s) ready for promotion')


# --- STATUS command ---
elif subcmd == 'status':
    print(f'{BOLD}Graduation Pipeline Status{NC}')
    print(f'  Learnings: {len(learnings)} | Practices: {len(practices)} | Promoted: {len(promoted_ids)}')
    print()
    print(f'  {"ID":<8} {"Apps":>4} {"Status":<12} {"Task":<8} {"Learning"}')
    print(f'  {chr(9472)*8} {chr(9472)*4} {chr(9472)*12} {chr(9472)*8} {chr(9472)*50}')

    for l in learnings:
        lid = l.get('id', '')
        apps = count_applications(lid, l.get('learning', ''))
        task = l.get('task', '?')
        text = l.get('learning', '')
        if len(text) > 55:
            text = text[:52] + '...'

        if lid in promoted_ids:
            status = f'{GREEN}promoted{NC}'
        elif apps >= 3:
            status = f'{YELLOW}ready{NC}'
        elif apps >= 2:
            status = f'{CYAN}almost{NC}'
        else:
            status = 'building'

        print(f'  {lid:<8} {apps:>4} {status:<23} {task:<8} {text}')

    print()
    ready = sum(1 for l in learnings if l.get('id', '') not in promoted_ids and count_applications(l['id'], '') >= 3)
    if ready > 0:
        print(f'  {YELLOW}{ready} learning(s) ready for promotion{NC} — run: fw promote suggest')


# --- PROMOTE L-XXX command ---
elif subcmd.startswith('L-'):
    learning_id = subcmd

    # Parse args
    name = None
    directive = None
    i = 0
    while i < len(args):
        if args[i] == '--name' and i + 1 < len(args):
            name = args[i+1]; i += 2
        elif args[i] == '--directive' and i + 1 < len(args):
            directive = args[i+1]; i += 2
        elif args[i] in ('-h', '--help'):
            print(f'{BOLD}fw promote L-XXX{NC} — Promote a learning to a practice')
            print()
            print('Options:')
            print('  --name <name>          Practice name (required)')
            print('  --directive <D1|D2..>  Which directive this serves (required)')
            print()
            print('Example:')
            print('  fw promote L-008 --name "Safe Arithmetic in set -e" --directive D1')
            sys.exit(0)
        else:
            i += 1

    # Find the learning
    learning = None
    for l in learnings:
        if l.get('id') == learning_id:
            learning = l
            break

    if not learning:
        print(f'{RED}Learning {learning_id} not found{NC}')
        sys.exit(1)

    if learning_id in promoted_ids:
        print(f'{YELLOW}Learning {learning_id} is already promoted to a practice{NC}')
        sys.exit(1)

    apps = count_applications(learning_id, learning.get('learning', ''))
    if apps < 3:
        print(f'{YELLOW}Warning: {learning_id} has only {apps} application(s) (3 recommended){NC}')
        print(f'Proceeding anyway — you can promote early if confident.')
        print()

    if not name:
        # Auto-generate from learning text
        name = learning.get('learning', 'Unnamed Practice')
        if len(name) > 60:
            name = name[:57] + '...'

    if not directive:
        # Try to infer from learning source
        source = learning.get('source', '')
        if source.startswith('P-'):
            # Look up which directive the source practice serves
            for p in practices:
                if p.get('id') == source:
                    directive = p.get('derived_from', 'D1')
                    break
        if not directive:
            directive = 'D1'  # Default to antifragility
        print(f'{CYAN}Auto-assigned directive: {directive}{NC}')

    # Generate next practice ID
    max_id = 0
    for p in practices:
        pid = p.get('id', '')
        m = re.match(r'P-(\d+)', pid)
        if m:
            max_id = max(max_id, int(m.group(1)))
    new_id = f'P-{max_id + 1:03d}'

    # Create the practice
    new_practice = {
        'id': new_id,
        'name': name,
        'derived_from': directive,
        'description': learning.get('learning', ''),
        'anti_pattern': learning.get('context', ''),
        'scope': 'project',
        'origin_task': learning.get('task', ''),
        'origin_date': str(learning.get('date', datetime.now().strftime('%Y-%m-%d'))),
        'promoted_from': learning_id,
        'status': 'active',
        'applications': apps,
    }

    # Append to practices file
    practices.append(new_practice)
    p_data['practices'] = practices
    with open(practices_file, 'w') as f:
        yaml.dump(p_data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f'{GREEN}=== Learning Promoted ==={NC}')
    print(f'  {learning_id} → {new_id}: {name}')
    print(f'  Directive: {directive}')
    print(f'  Applications: {apps}')
    print(f'  Origin: {learning.get("task", "?")}')
    print()
    print(f'Practice added to: {practices_file}')

else:
    print(f'{BOLD}fw promote{NC} — Graduation Pipeline')
    print()
    print('Commands:')
    print('  suggest     Show learnings ready for promotion (3+ applications)')
    print('  status      Show all learnings with application counts')
    print('  L-XXX       Promote a specific learning to practice')
    print()
    print('Examples:')
    print('  fw promote suggest')
    print('  fw promote status')
    print('  fw promote L-008 --name "Safe Arithmetic in set -e" --directive D1')
    print()
    print('Graduation criteria (from 015-Practices.md):')
    print('  Learning → Practice: 3+ successful applications, traces to directive')
    print('  Practice → Directive: Universal, stable 6+ months, human decision')
PYPROMOTE
            ;;
        -h|--help|"")
            echo -e "${BOLD}fw promote${NC} — Graduation Pipeline"
            echo ""
            echo "Commands:"
            echo "  suggest     Show learnings ready for promotion (3+ applications)"
            echo "  status      Show all learnings with application counts"
            echo "  L-XXX       Promote a specific learning to practice"
            echo ""
            echo "Examples:"
            echo "  fw promote suggest"
            echo "  fw promote status"
            echo '  fw promote L-008 --name "Safe Arithmetic" --directive D1'
            ;;
        *)
            echo -e "${RED}Unknown promote subcommand: $subcmd${NC}" >&2
            echo "Run 'fw promote' for usage" >&2
            exit 1
            ;;
    esac
}
