#!/bin/bash
# fw harvest - Collect learnings from projects back into the framework
#
# Reads a project's .context/ directory and identifies patterns, learnings,
# and decisions that could be promoted to the framework level.
#
# Graduation pipeline:
#   1 project  = local (stays in project)
#   2+ projects = candidate (proposed for framework)
#   3+ projects = practice (promoted to framework)

do_harvest() {
    local project_dir=""
    local dry_run=false
    local verbose=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) dry_run=true; shift ;;
            --verbose) verbose=true; shift ;;
            -h|--help)
                echo -e "${BOLD}fw harvest${NC} - Cross-project learning"
                echo ""
                echo "Usage: fw harvest [project-dir] [options]"
                echo ""
                echo "Arguments:"
                echo "  project-dir       Project to harvest from (default: PROJECT_ROOT)"
                echo ""
                echo "Options:"
                echo "  --dry-run         Show what would be harvested without modifying framework"
                echo "  --verbose         Show detailed comparison"
                echo "  -h, --help        Show this help"
                echo ""
                echo "Graduation pipeline:"
                echo "  1 project  = local (stays in project)"
                echo "  2+ projects = candidate (proposed for framework)"
                echo "  3+ projects = practice (promoted to framework)"
                echo ""
                echo "Examples:"
                echo "  fw harvest                     # Harvest from current project"
                echo "  fw harvest /path/to/project    # Harvest from specific project"
                echo "  fw harvest --dry-run           # Preview without changes"
                return 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                return 1
                ;;
            *)
                project_dir="$1"; shift
                ;;
        esac
    done

    # Default to PROJECT_ROOT
    if [ -z "$project_dir" ]; then
        project_dir="$PROJECT_ROOT"
    fi

    # Resolve to absolute path
    project_dir="$(cd "$project_dir" 2>/dev/null && pwd)" || {
        echo -e "${RED}ERROR: Directory does not exist: $project_dir${NC}" >&2
        return 1
    }

    # Don't harvest from framework itself
    if [ "$project_dir" = "$FRAMEWORK_ROOT" ]; then
        echo -e "${YELLOW}Cannot harvest from the framework itself${NC}"
        echo "Run fw harvest from a project directory, or specify a project path"
        return 1
    fi

    local project_context="$project_dir/.context/project"
    local framework_context="$FRAMEWORK_ROOT/.context/project"
    local harvest_log="$FRAMEWORK_ROOT/.context/harvest.log"
    local project_name
    project_name=$(basename "$project_dir")

    # Validate project has context
    if [ ! -d "$project_context" ]; then
        echo -e "${RED}ERROR: No .context/project/ found in $project_dir${NC}" >&2
        echo "Initialize the project first: fw init $project_dir" >&2
        return 1
    fi

    echo -e "${BOLD}fw harvest${NC} - Cross-project learning"
    echo ""
    echo "  Project:   $project_dir ($project_name)"
    echo "  Framework: $FRAMEWORK_ROOT"
    if [ "$dry_run" = true ]; then
        echo -e "  Mode:      ${YELLOW}dry-run${NC}"
    fi
    echo ""

    local new_patterns=0
    local new_learnings=0
    local new_decisions=0
    local new_episodics=0
    local new_practices=0
    local duplicates=0

    # --- Harvest Patterns ---
    echo -e "${YELLOW}Scanning patterns...${NC}"
    harvest_patterns "$project_context/patterns.yaml" "$framework_context/patterns.yaml" "$project_name"

    # --- Harvest Learnings ---
    echo -e "${YELLOW}Scanning learnings...${NC}"
    harvest_learnings "$project_context/learnings.yaml" "$framework_context/learnings.yaml" "$project_name"

    # --- Harvest Decisions ---
    echo -e "${YELLOW}Scanning decisions...${NC}"
    harvest_decisions "$project_context/decisions.yaml" "$framework_context/decisions.yaml" "$project_name"

    # --- Harvest Episodics ---
    echo -e "${YELLOW}Scanning episodic memory...${NC}"
    harvest_episodics

    # --- Harvest Practices ---
    echo -e "${YELLOW}Scanning practices...${NC}"
    harvest_practices "$project_context/practices.yaml" "$framework_context/practices.yaml" "$project_name"

    # --- CLAUDE.md Additions ---
    echo -e "${YELLOW}Scanning CLAUDE.md additions...${NC}"
    harvest_claude_additions "$project_dir" "$project_name"

    # --- Summary ---
    echo ""
    echo -e "${BOLD}=== Harvest Summary ===${NC}"
    echo "  New patterns:   $new_patterns"
    echo "  New learnings:  $new_learnings"
    echo "  New decisions:  $new_decisions"
    echo "  New episodics:  $new_episodics"
    echo "  New practices:  $new_practices"
    echo "  Duplicates:     $duplicates"

    if [ "$dry_run" = true ]; then
        echo ""
        echo -e "${YELLOW}Dry run — no changes made to framework${NC}"
    elif [ $((new_patterns + new_learnings + new_decisions + new_episodics + new_practices)) -gt 0 ]; then
        # Log the harvest
        echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") | project=$project_name | patterns=$new_patterns learnings=$new_learnings decisions=$new_decisions episodics=$new_episodics practices=$new_practices" >> "$harvest_log"
        echo ""
        echo -e "${GREEN}Harvested items added to framework .context/project/ files${NC}"
        echo "Review and commit: fw git commit -m \"T-035: Harvest from $project_name\""
    else
        echo ""
        echo -e "${CYAN}Nothing new to harvest${NC}"
    fi
}

# --- Pattern Harvesting ---
harvest_patterns() {
    local project_file="$1"
    local framework_file="$2"
    local project_name="$3"

    if [ ! -f "$project_file" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No patterns.yaml in project"
        return
    fi

    # Extract pattern descriptions from project (simple grep approach)
    local project_patterns
    project_patterns=$(grep "^    pattern:" "$project_file" 2>/dev/null | sed 's/.*pattern:[[:space:]]*//' | tr -d '"' || true)

    if [ -z "$project_patterns" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No patterns found in project"
        return
    fi

    local framework_patterns=""
    if [ -f "$framework_file" ]; then
        framework_patterns=$(grep "^    pattern:" "$framework_file" 2>/dev/null | sed 's/.*pattern:[[:space:]]*//' | tr -d '"' || true)
    fi

    while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue

        if echo "$framework_patterns" | grep -qF "$pattern"; then
            duplicates=$((duplicates + 1))
            if [ "$verbose" = true ]; then
                echo -e "  ${CYAN}DUP${NC}   Pattern: $pattern"
            fi
        else
            new_patterns=$((new_patterns + 1))
            echo -e "  ${GREEN}NEW${NC}   Pattern: $pattern (from $project_name)"

            if [ "$dry_run" != true ]; then
                # Extract the full pattern block and append to framework
                append_pattern_block "$project_file" "$pattern" "$framework_file" "$project_name"
            fi
        fi
    done <<< "$project_patterns"
}

# Append a pattern block from project to framework
append_pattern_block() {
    local project_file="$1"
    local pattern_name="$2"
    local framework_file="$3"
    local project_name="$4"

    # Use python for reliable YAML block extraction and append
    python3 << PYEOF
import re

pattern_name = "$pattern_name"
project_name = "$project_name"

with open("$project_file", "r") as f:
    content = f.read()

# Find the block containing this pattern
blocks = re.split(r'\n  - ', content)
target_block = None
for block in blocks:
    if pattern_name in block:
        target_block = block.strip()
        break

if target_block:
    # Add provenance
    provenance = f"\n    harvested_from: {project_name}"
    harvest_date = f"\n    harvest_date: $(date -u +%Y-%m-%d)"

    # Determine which section it belongs to
    section = "failure_patterns"
    if "success_pattern" in content.split(pattern_name)[0].split("patterns:")[-1]:
        section = "success_patterns"
    elif "workflow_pattern" in content.split(pattern_name)[0].split("patterns:")[-1]:
        section = "workflow_patterns"

    # Append to framework file
    with open("$framework_file", "r") as f:
        fw_content = f.read()

    # Find the section and append
    entry = f"\n\n  - {target_block}{provenance}{harvest_date}"

    if section + ":" in fw_content:
        # Find the last entry in this section
        lines = fw_content.split("\n")
        insert_idx = len(lines)
        in_section = False
        for i, line in enumerate(lines):
            if line.startswith(section + ":"):
                in_section = True
            elif in_section and line and not line.startswith(" ") and not line.startswith("#"):
                insert_idx = i
                break

        lines.insert(insert_idx, entry)
        fw_content = "\n".join(lines)
    else:
        fw_content += f"\n{section}:{entry}\n"

    with open("$framework_file", "w") as f:
        f.write(fw_content)
PYEOF
}

# --- Learning Harvesting ---
harvest_learnings() {
    local project_file="$1"
    local framework_file="$2"
    local project_name="$3"

    if [ ! -f "$project_file" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No learnings.yaml in project"
        return
    fi

    local project_learnings
    project_learnings=$(grep "^    learning:" "$project_file" 2>/dev/null | sed 's/.*learning:[[:space:]]*//' | tr -d '"' || true)

    if [ -z "$project_learnings" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No learnings found in project"
        return
    fi

    local framework_learnings=""
    if [ -f "$framework_file" ]; then
        framework_learnings=$(grep "^    learning:" "$framework_file" 2>/dev/null | sed 's/.*learning:[[:space:]]*//' | tr -d '"' || true)
    fi

    while IFS= read -r learning; do
        [ -z "$learning" ] && continue

        if echo "$framework_learnings" | grep -qF "$learning"; then
            duplicates=$((duplicates + 1))
            if [ "$verbose" = true ]; then
                echo -e "  ${CYAN}DUP${NC}   Learning: $learning"
            fi
        else
            new_learnings=$((new_learnings + 1))
            echo -e "  ${GREEN}NEW${NC}   Learning: $learning (from $project_name)"

            if [ "$dry_run" != true ] && [ -f "$framework_file" ]; then
                # Append as candidate learning
                cat >> "$framework_file" << LYEOF

  # Harvested from $project_name on $(date -u +%Y-%m-%d)
  - id: L-HARVEST-$(date +%s)
    learning: "$learning"
    source: "$project_name"
    task: "harvested"
    date: $(date -u +%Y-%m-%d)
    context: "Cross-project harvest from $project_name"
    application: "[Review and refine]"
LYEOF
            fi
        fi
    done <<< "$project_learnings"
}

# --- Decision Harvesting ---
harvest_decisions() {
    local project_file="$1"
    local framework_file="$2"
    local project_name="$3"

    if [ ! -f "$project_file" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No decisions.yaml in project"
        return
    fi

    local project_decisions
    project_decisions=$(grep "^  description:" "$project_file" 2>/dev/null | sed 's/.*description:[[:space:]]*//' | tr -d '"' || true)

    if [ -z "$project_decisions" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No decisions found in project"
        return
    fi

    local framework_decisions=""
    if [ -f "$framework_file" ]; then
        framework_decisions=$(grep "^  description:" "$framework_file" 2>/dev/null | sed 's/.*description:[[:space:]]*//' | tr -d '"' || true)
    fi

    while IFS= read -r decision; do
        [ -z "$decision" ] && continue

        if echo "$framework_decisions" | grep -qF "$decision"; then
            duplicates=$((duplicates + 1))
            if [ "$verbose" = true ]; then
                echo -e "  ${CYAN}DUP${NC}   Decision: $decision"
            fi
        else
            new_decisions=$((new_decisions + 1))
            echo -e "  ${GREEN}NEW${NC}   Decision: $decision (from $project_name)"
            # Decisions are project-specific, just report them — don't auto-promote
        fi
    done <<< "$project_decisions"

    if [ $new_decisions -gt 0 ]; then
        echo -e "  ${YELLOW}NOTE${NC}  Decisions are project-specific — review manually for framework relevance"
    fi
}

# --- Episodic Memory Harvesting ---
harvest_episodics() {
    local project_episodics="$project_dir/.context/episodic"
    local framework_episodics="$FRAMEWORK_ROOT/.context/episodic/harvested"

    if [ ! -d "$project_episodics" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No .context/episodic/ in project"
        return
    fi

    local episodic_files
    episodic_files=$(find "$project_episodics" -maxdepth 1 -name "T-*.yaml" 2>/dev/null || true)

    if [ -z "$episodic_files" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No episodic files found in project"
        return
    fi

    local dest_dir="$framework_episodics/$project_name"

    if [ "$dry_run" != true ]; then
        mkdir -p "$dest_dir"
    fi

    while IFS= read -r ep_file; do
        [ -z "$ep_file" ] && continue
        local ep_basename
        ep_basename=$(basename "$ep_file")

        if [ -f "$dest_dir/$ep_basename" ]; then
            duplicates=$((duplicates + 1))
            if [ "$verbose" = true ]; then
                echo -e "  ${CYAN}DUP${NC}   Episodic: $ep_basename"
            fi
        else
            new_episodics=$((new_episodics + 1))
            echo -e "  ${GREEN}NEW${NC}   Episodic: $ep_basename (from $project_name)"

            if [ "$dry_run" != true ]; then
                # Copy with provenance header
                {
                    echo "# Harvested from $project_name on $(date -u +%Y-%m-%d)"
                    cat "$ep_file"
                } > "$dest_dir/$ep_basename"
            fi
        fi
    done <<< "$episodic_files"
}

# --- Practice Harvesting ---
harvest_practices() {
    local project_file="$1"
    local framework_file="$2"
    local project_name="$3"

    if [ ! -f "$project_file" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No practices.yaml in project"
        return
    fi

    local project_practices
    project_practices=$(grep "^    name:" "$project_file" 2>/dev/null | sed 's/.*name:[[:space:]]*//' | tr -d '"' || true)

    if [ -z "$project_practices" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No practices found in project"
        return
    fi

    local framework_practices=""
    if [ -f "$framework_file" ]; then
        framework_practices=$(grep "^    name:" "$framework_file" 2>/dev/null | sed 's/.*name:[[:space:]]*//' | tr -d '"' || true)
    fi

    while IFS= read -r practice; do
        [ -z "$practice" ] && continue

        if echo "$framework_practices" | grep -qF "$practice"; then
            duplicates=$((duplicates + 1))
            if [ "$verbose" = true ]; then
                echo -e "  ${CYAN}DUP${NC}   Practice: $practice"
            fi
        else
            new_practices=$((new_practices + 1))
            echo -e "  ${GREEN}NEW${NC}   Practice: $practice (from $project_name)"

            if [ "$dry_run" != true ] && [ -f "$framework_file" ]; then
                # Append as candidate practice
                cat >> "$framework_file" << PPEOF

  # Harvested from $project_name on $(date -u +%Y-%m-%d)
  - id: P-HARVEST-$(date +%s)
    name: "$practice"
    derived_from: "harvested"
    description: "[Review and refine — harvested from $project_name]"
    anti_pattern: "[To be defined]"
    origin_task: "harvested"
    origin_date: $(date -u +%Y-%m-%d)
    status: candidate
    applications: 1
PPEOF
            fi
        fi
    done <<< "$project_practices"
}

# --- CLAUDE.md Addition Detection ---
harvest_claude_additions() {
    local project_dir="$1"
    local project_name="$2"
    local project_claude="$project_dir/CLAUDE.md"
    local template_claude="$FRAMEWORK_ROOT/lib/templates/claude-project.md"

    if [ ! -f "$project_claude" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No CLAUDE.md in project"
        return
    fi

    if [ ! -f "$template_claude" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No template claude-project.md in framework"
        return
    fi

    # Extract ## headings from both files
    local project_headings
    project_headings=$(grep "^## " "$project_claude" 2>/dev/null | sort || true)

    local template_headings
    template_headings=$(grep "^## " "$template_claude" 2>/dev/null | sort || true)

    if [ -z "$project_headings" ]; then
        echo -e "  ${CYAN}SKIP${NC}  No sections found in project CLAUDE.md"
        return
    fi

    local found_new=false
    while IFS= read -r heading; do
        [ -z "$heading" ] && continue

        if ! echo "$template_headings" | grep -qF "$heading"; then
            found_new=true
            echo -e "  ${GREEN}NEW${NC}   Section in project CLAUDE.md: $heading"
        fi
    done <<< "$project_headings"

    if [ "$found_new" != true ]; then
        echo -e "  ${CYAN}---${NC}   No new sections in project CLAUDE.md"
    else
        echo -e "  ${YELLOW}NOTE${NC}  Review new sections manually for framework inclusion"
    fi
}
