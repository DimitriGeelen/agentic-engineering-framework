#!/bin/bash
# Fabric Agent - graph traversal commands
# Implements: fw fabric impact, fw fabric blast-radius

do_impact() {
    ensure_fabric_dirs

    local file_path="${1:-}"
    local max_depth="${2:-10}"
    if [ -z "$file_path" ]; then
        echo -e "${RED}Error: File path required${NC}"
        echo "Usage: fw fabric impact <file-path> [--depth N]"
        exit 1
    fi

    # Handle --depth flag
    if [ "${2:-}" = "--depth" ] && [ -n "${3:-}" ]; then
        max_depth="$3"
    fi

    local rel_path
    rel_path=$(realpath --relative-to="$PROJECT_ROOT" "$file_path" 2>/dev/null || echo "$file_path")

    echo -e "${BOLD}Impact chain for: $rel_path${NC}"
    echo ""

    # Use Python for graph traversal
    local _rc=0
    python3 -c "
import yaml, glob, os, sys

COMPONENTS_DIR = '$COMPONENTS_DIR'
PROJECT_ROOT = '$PROJECT_ROOT'
start_path = '$rel_path'
max_depth = int('$max_depth')

# Load all component cards
cards = {}
for card_path in glob.glob(os.path.join(COMPONENTS_DIR, '*.yaml')):
    with open(card_path) as f:
        data = yaml.safe_load(f)
    if data:
        cid = data.get('id', '')
        name = data.get('name', '')
        location = data.get('location', '')
        cards[cid] = data
        if location:
            cards[location] = data
        if name:
            cards[name] = data

# Find starting component
start = None
for cid, data in cards.items():
    if data.get('location') == start_path or cid == start_path:
        start = data
        break

if not start:
    print(f'  No card found for: {start_path}')
    print(f'  Register it: fw fabric register {start_path}')
    sys.exit(1)

# Build forward edges: what does each component write/produce?
# For impact, we want: this component writes X → who reads X?
writes = {}  # component_id -> list of targets it writes to
reads = {}   # target -> list of components that read it

for cid, data in cards.items():
    loc = data.get('location', '')
    if not loc:
        continue
    for dep in data.get('depends_on', []):
        # T-908: 24 of 704 depends_on entries in this corpus are PLAIN STRINGS, not
        # {type,target} dicts — both shapes are in committed cards. dep.get() on a str
        # raised AttributeError, the traceback went to 2>/dev/null, and the whole verb
        # printed its header and stopped. Three procAsFit rounds read that as an EMPTY
        # IMPACT CHAIN and one of them changed a shared harness on the strength of it.
        # A bare string carries no edge type, so it is treated as an untyped dependency:
        # counted as a structural edge, never as a write.
        if not isinstance(dep, dict):
            dep = {'type': '', 'target': str(dep)}
        dtype = dep.get('type', '')
        target = dep.get('target', '')
        if dtype == 'writes':
            writes.setdefault(loc, []).append(target)
        elif dtype == 'reads':
            reads.setdefault(target, []).append(loc)

    # Also check writers/readers on data files
    for w in data.get('writers', []):
        t = w.get('target', '') if isinstance(w, dict) else w
        if t:
            writes.setdefault(t, []).append(loc)
    for r in data.get('readers', []):
        t = r.get('target', '') if isinstance(r, dict) else r
        if t:
            reads.setdefault(loc, []).append(t)

# Traverse: start → what it writes → who reads that → what they write → ...
visited = set()
total = [0]

def traverse(component_data, depth, prefix=''):
    if depth > max_depth:
        return
    loc = component_data.get('location', component_data.get('id', ''))
    if loc in visited:
        return
    visited.add(loc)

    # What does this component write to?
    for dep in component_data.get('depends_on', []):
        if not isinstance(dep, dict):   # T-908: str entries exist in committed cards
            dep = {'type': '', 'target': str(dep)}
        if dep.get('type') == 'writes':
            target_id = dep.get('target', '')
            # Find the target card
            target_data = cards.get(target_id)
            if target_data:
                target_loc = target_data.get('location', target_id)
                target_name = target_data.get('name', target_id)
                print(f'{prefix}  writes \u2192 {target_loc} ({target_name})')
                total[0] += 1
                # Who reads this target?
                for reader in target_data.get('readers', []):
                    reader_id = reader.get('target', '') if isinstance(reader, dict) else reader
                    reader_loc = reader.get('location', '') if isinstance(reader, dict) else ''
                    reader_data = cards.get(reader_id)
                    if reader_data:
                        rname = reader_data.get('name', reader_id)
                        rloc = reader_data.get('location', reader_id)
                        print(f'{prefix}    read by \u2192 {rloc} ({rname})')
                        total[0] += 1
                        traverse(reader_data, depth + 1, prefix + '    ')

    # Also check: who depends_on this component via reads/calls/triggers/renders?
    my_id = component_data.get('id', '')
    my_name = component_data.get('name', '')
    for cid, data in cards.items():
        if data.get('location', '') in visited:
            continue
        for dep in data.get('depends_on', []):
            if not isinstance(dep, dict):   # T-908
                dep = {'type': '', 'target': str(dep)}
            target = dep.get('target', '')
            if target in (my_id, my_name, loc) and dep.get('type') in ('renders', 'calls', 'triggers'):
                dep_loc = data.get('location', cid)
                dep_name = data.get('name', cid)
                dtype = dep.get('type', 'uses')
                print(f'{prefix}  {dtype} \u2192 {dep_loc} ({dep_name})')
                total[0] += 1
                traverse(data, depth + 1, prefix + '  ')

traverse(start, 0)

if total[0] == 0:
    print('  No downstream impact found (component may need enrichment)')
else:
    print(f'')
    print(f'{total[0]} downstream component(s) affected')
" || _rc=$?
    # T-908, TWO fixes on this line and the block below.
    #
    # 1. The `2>/dev/null` that used to sit on the closing quote is GONE, and its
    #    absence is the point. A traceback here was discarded, so a CRASH printed the
    #    header and nothing else — indistinguishable from a real empty chain, in the
    #    reassuring direction. Three procAsFit rounds independently reported "impact
    #    prints an empty chain" and none could see why: the why was on the stream
    #    being thrown away.
    #
    # 2. `|| _rc=$?` rather than a bare `local _rc=$?` on the next line. fabric.sh:26
    #    sets `-euo pipefail`, so errexit terminated the function the instant python
    #    exited non-zero and the refusal below was UNREACHABLE DEAD CODE. Measured by
    #    injecting a crash: the traceback appeared, the exit was 1, and the message
    #    never printed. The `||` is what makes the failure survivable long enough to
    #    be reported. Caught only because the control was run before the fix was
    #    believed.
    #
    # The verdict is no longer swallowed either: `return 0` unconditionally meant a
    # caller could not distinguish a computed answer from a failed one, and CLAUDE.md
    # sends the agent here BEFORE modifying a file, so a silent failure reads as
    # permission to proceed.
    if [ "$_rc" -ne 0 ]; then
        echo "" >&2
        echo -e "${RED}IMPACT NOT COMPUTED${NC} (traversal exited $_rc) — this is NOT 'nothing depends on this file'." >&2
        echo "  Nothing above was measured. Do not read the absence of downstream" >&2
        echo "  components as permission to change this file." >&2
        echo "  Cross-check with: fw fabric deps $rel_path" >&2
        return "$_rc"
    fi

    return 0
}

do_blast_radius() {
    ensure_fabric_dirs

    local ref="${1:-HEAD}"

    # Get changed files from commit
    local changed_files
    changed_files=$(git -C "$PROJECT_ROOT" diff-tree --no-commit-id --name-only -r "$ref" 2>/dev/null)

    if [ -z "$changed_files" ]; then
        echo -e "${YELLOW}No files changed in $ref${NC}"
        return 0
    fi

    local commit_msg
    commit_msg=$(git -C "$PROJECT_ROOT" log -1 --format='%s' "$ref" 2>/dev/null)

    echo -e "${BOLD}Blast radius: $ref${NC}"
    echo -e "  ${CYAN}$commit_msg${NC}"
    echo ""

    local total_impact=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        # Skip non-source files
        case "$file" in
            .context/*|.fabric/*|.tasks/*) continue ;;
        esac

        # Check if this file has a fabric card
        local has_card=false
        for card in "$COMPONENTS_DIR"/*.yaml; do
            [ -f "$card" ] || continue
            if grep -q "^location: $file" "$card" 2>/dev/null; then
                has_card=true
                local name
                name=$({ grep "^name:" "$card" 2>/dev/null || true; } | head -1 | sed 's/^name: //')
                echo -e "${GREEN}$file${NC} ($name)"

                # Quick impact lookup
                python3 -c "
import yaml
with open('$card') as f:
    data = yaml.safe_load(f)
for dep in data.get('depends_on', []):

    if not isinstance(dep, dict):   # T-908
        dep = {'type': '', 'target': str(dep)}
    if dep.get('type') == 'writes':
        print(f'    writes \u2192 {dep[\"target\"]}')
"
                # T-908: stderr mask removed here too. do_impact carried the
                # identical `" 2>/dev/null` and it turned an AttributeError into a
                # silent empty answer for three procAsFit rounds. This is the SIBLING
                # verb, and CLAUDE.md tells the agent to run it BEFORE COMMITTING —
                # so a swallowed failure here reads as "no blast radius, safe to
                # commit". Found by a verification leg that was too loose and
                # matched the sibling by accident.
                total_impact=$((total_impact + 1))
                break
            fi
        done

        if [ "$has_card" = false ]; then
            echo -e "  ${YELLOW}$file${NC} (no fabric card)"
        fi
    done <<< "$changed_files"

    echo ""
    echo "$total_impact registered component(s) changed"
    return 0
}
