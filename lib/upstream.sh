#!/usr/bin/env bash
# lib/upstream.sh — Safe issue/PR creation from field installations to framework repo
# Part of the Agentic Engineering Framework
# Inception: T-451 | Build: T-454

set -euo pipefail

# Colors (may already be sourced, but safe to re-declare)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# --- Configuration resolution ---

_upstream_resolve_repo() {
    local repo=""

    # 1. Check .framework.yaml in PROJECT_ROOT (consumer project)
    if [ -f "${PROJECT_ROOT:-.}/.framework.yaml" ]; then
        repo=$(grep '^upstream_repo:' "${PROJECT_ROOT}/.framework.yaml" 2>/dev/null | sed 's/upstream_repo: *//' | tr -d '"' || true)
    fi

    # 2. Fallback: detect from framework repo's git remotes (try origin, then any github.com remote)
    if [ -z "$repo" ] && [ -d "${FRAMEWORK_ROOT:-.}/.git" ]; then
        local remote_url
        # Try origin first
        remote_url=$(cd "$FRAMEWORK_ROOT" && git remote get-url origin 2>/dev/null || true)
        # If no origin, find first github.com remote
        if [ -z "$remote_url" ] || ! echo "$remote_url" | grep -q "github.com"; then
            remote_url=$(cd "$FRAMEWORK_ROOT" && git remote -v 2>/dev/null | grep "github.com" | grep "(push)" | head -1 | awk '{print $2}' || true)
        fi
        if [ -n "$remote_url" ] && echo "$remote_url" | grep -q "github.com"; then
            repo=$(echo "$remote_url" | sed -E 's|.*github\.com[:/]||;s|\.git$||')
        fi
    fi

    # 3. Fallback: detect from current repo's git remotes (self-hosting)
    if [ -z "$repo" ]; then
        local remote_url
        remote_url=$(git remote get-url origin 2>/dev/null || true)
        if [ -z "$remote_url" ] || ! echo "$remote_url" | grep -q "github.com"; then
            remote_url=$(git remote -v 2>/dev/null | grep "github.com" | grep "(push)" | head -1 | awk '{print $2}' || true)
        fi
        if [ -n "$remote_url" ] && echo "$remote_url" | grep -q "github.com"; then
            repo=$(echo "$remote_url" | sed -E 's|.*github\.com[:/]||;s|\.git$||')
        fi
    fi

    echo "$repo"
}

_upstream_get_config() {
    local repo
    repo=$(_upstream_resolve_repo)

    if [ -z "$repo" ]; then
        echo -e "${RED}ERROR: Cannot determine upstream repo.${NC}" >&2
        echo -e "Set it explicitly: ${GREEN}fw upstream config --repo OWNER/REPO${NC}" >&2
        return 1
    fi

    echo "$repo"
}

_upstream_sent_file() {
    echo "${PROJECT_ROOT:-$FRAMEWORK_ROOT}/.context/working/.upstream-issues-sent"
}

_upstream_is_sent() {
    local title="$1"
    local sent_file
    sent_file=$(_upstream_sent_file)
    [ -f "$sent_file" ] && grep -qF "$title" "$sent_file"
}

_upstream_mark_sent() {
    local title="$1"
    local issue_url="$2"
    local sent_file
    sent_file=$(_upstream_sent_file)
    mkdir -p "$(dirname "$sent_file")"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $issue_url | $title" >> "$sent_file"
}

# --- Subcommands ---

do_upstream_config() {
    local set_repo=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --repo) set_repo="$2"; shift 2 ;;
            *) echo -e "${RED}Unknown option: $1${NC}" >&2; return 1 ;;
        esac
    done

    if [ -n "$set_repo" ]; then
        # Validate format: OWNER/REPO
        if ! echo "$set_repo" | grep -qE '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$'; then
            echo -e "${RED}ERROR: Invalid repo format. Expected OWNER/REPO (e.g., DimitriGeelen/agentic-engineering-framework)${NC}" >&2
            return 1
        fi

        local yaml_file="${PROJECT_ROOT:-$FRAMEWORK_ROOT}/.framework.yaml"
        if [ -f "$yaml_file" ]; then
            if grep -q '^upstream_repo:' "$yaml_file"; then
                sed -i "s|^upstream_repo:.*|upstream_repo: $set_repo|" "$yaml_file"
            else
                echo "upstream_repo: $set_repo" >> "$yaml_file"
            fi
            echo -e "${GREEN}✓${NC} Upstream repo set to ${BOLD}$set_repo${NC} in $yaml_file"
        else
            echo -e "${YELLOW}⚠${NC} No .framework.yaml found. Creating minimal config."
            echo "upstream_repo: $set_repo" > "$yaml_file"
            echo -e "${GREEN}✓${NC} Created $yaml_file with upstream_repo: $set_repo"
        fi
        return 0
    fi

    # Show current config
    echo -e "${BOLD}Upstream Configuration${NC}"
    echo ""

    local repo
    repo=$(_upstream_resolve_repo)

    if [ -n "$repo" ]; then
        echo -e "  Repo:     ${GREEN}$repo${NC}"

        # Show source
        if [ -f "${PROJECT_ROOT:-.}/.framework.yaml" ] && grep -q '^upstream_repo:' "${PROJECT_ROOT}/.framework.yaml" 2>/dev/null; then
            echo -e "  Source:   .framework.yaml (persistent)"
        else
            echo -e "  Source:   git remote (auto-detected)"
        fi
    else
        echo -e "  Repo:     ${RED}Not configured${NC}"
        echo -e "  Fix:      fw upstream config --repo OWNER/REPO"
    fi

    # Auth status
    echo ""
    if command -v gh &>/dev/null; then
        local gh_user
        gh_user=$(gh api user --jq '.login' 2>/dev/null || echo "")
        if [ -n "$gh_user" ]; then
            echo -e "  Auth:     ${GREEN}$gh_user${NC} (gh cli)"
        else
            echo -e "  Auth:     ${RED}Not authenticated${NC} — run: gh auth login"
        fi
    else
        echo -e "  Auth:     ${RED}gh CLI not installed${NC} — install: https://cli.github.com"
    fi

    # Sent history
    local sent_file
    sent_file=$(_upstream_sent_file)
    if [ -f "$sent_file" ]; then
        local count
        count=$(wc -l < "$sent_file")
        echo ""
        echo -e "  Sent:     $count issue(s) reported"
        echo -e "  History:  $sent_file"
    fi
}

do_upstream_status() {
    do_upstream_config "$@"
}

do_upstream_report() {
    local title=""
    local body=""
    local attach_doctor=false
    local attach_patch=""
    local labels="field-report"
    local dry_run=false
    local force=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --title|-t) title="$2"; shift 2 ;;
            --body|-b) body="$2"; shift 2 ;;
            --attach-doctor) attach_doctor=true; shift ;;
            --attach-patch) attach_patch="$2"; shift 2 ;;
            --label|-l) labels="$labels,$2"; shift 2 ;;
            --dry-run) dry_run=true; shift ;;
            --force|-f) force=true; shift ;;
            *) echo -e "${RED}Unknown option: $1${NC}" >&2; return 1 ;;
        esac
    done

    if [ -z "$title" ]; then
        echo -e "${RED}ERROR: --title is required${NC}" >&2
        echo -e "Usage: fw upstream report --title \"Bug: description\" [--body \"details\"] [--attach-doctor] [--dry-run]" >&2
        return 1
    fi

    # Check gh CLI
    if ! command -v gh &>/dev/null; then
        echo -e "${RED}ERROR: gh CLI is required but not installed${NC}" >&2
        echo -e "Install: https://cli.github.com" >&2
        return 1
    fi

    # Resolve upstream repo
    local repo
    repo=$(_upstream_get_config) || return 1

    # Check for duplicate
    if ! $force && _upstream_is_sent "$title"; then
        echo -e "${YELLOW}⚠${NC} An issue with this title was already sent. Use --force to send anyway."
        return 1
    fi

    # Build issue body
    local full_body=""
    local fw_version="${FW_VERSION:-unknown}"
    local project_name=""
    if [ -f "${PROJECT_ROOT:-.}/.framework.yaml" ]; then
        project_name=$(grep '^project_name:' "${PROJECT_ROOT}/.framework.yaml" 2>/dev/null | sed 's/project_name: *//' || echo "unknown")
    fi
    local mode="self-hosting"
    if [ "${PROJECT_ROOT:-$FRAMEWORK_ROOT}" != "$FRAMEWORK_ROOT" ]; then
        mode="shared-tooling"
    fi

    full_body="## Context
- **Framework version:** $fw_version
- **Project:** ${project_name:-$(basename "${PROJECT_ROOT:-$FRAMEWORK_ROOT}")} ($mode mode)
- **Reported:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
"

    if [ -n "$body" ]; then
        full_body="$full_body
## Description
$body
"
    fi

    # Attach fw doctor output
    if $attach_doctor; then
        local doctor_output
        doctor_output=$("$FRAMEWORK_ROOT/bin/fw" doctor 2>&1 | head -50 || echo "fw doctor failed")
        full_body="$full_body
## fw doctor output
\`\`\`
$doctor_output
\`\`\`
"
    fi

    # Attach patch
    if [ -n "$attach_patch" ]; then
        local patch_content
        patch_content=$(cd "$FRAMEWORK_ROOT" && git diff "$attach_patch" 2>/dev/null | head -200 || echo "Could not generate patch")
        if [ -n "$patch_content" ]; then
            full_body="$full_body
## Suggested Patch
\`\`\`diff
$patch_content
\`\`\`
"
        fi
    fi

    full_body="$full_body
---
*Reported via \`fw upstream report\` from field installation*"

    # Dry run
    if $dry_run; then
        echo -e "${BOLD}=== DRY RUN ===${NC}"
        echo ""
        echo -e "  Target:   ${GREEN}$repo${NC}"
        echo -e "  Title:    $title"
        echo -e "  Labels:   $labels"
        echo ""
        echo -e "${BOLD}Body:${NC}"
        echo "$full_body"
        echo ""
        echo -e "${YELLOW}No issue created (dry-run mode).${NC}"
        echo -e "Remove --dry-run to create the issue."
        return 0
    fi

    # Confirmation
    echo -e "${BOLD}=== Create Upstream Issue ===${NC}"
    echo ""
    echo -e "  Target:   ${GREEN}$repo${NC}"
    echo -e "  Title:    $title"
    echo -e "  Labels:   $labels"
    echo ""

    if ! $force; then
        echo -n -e "Create issue on ${BOLD}$repo${NC}? [y/N] "
        read -r confirm
        if [ "${confirm,,}" != "y" ]; then
            echo -e "${YELLOW}Cancelled.${NC}"
            return 0
        fi
    fi

    # Create the issue
    local issue_url
    issue_url=$(gh issue create \
        --repo "$repo" \
        --title "$title" \
        --body "$full_body" \
        --label "$labels" \
        2>&1) || {
        # Labels might not exist — retry without labels
        echo -e "${YELLOW}⚠${NC} Label creation failed, retrying without labels..."
        issue_url=$(gh issue create \
            --repo "$repo" \
            --title "$title" \
            --body "$full_body" \
            2>&1) || {
            echo -e "${RED}ERROR: Failed to create issue${NC}" >&2
            echo "$issue_url" >&2
            return 1
        }
    }

    # Mark as sent
    _upstream_mark_sent "$title" "$issue_url"

    echo ""
    echo -e "${GREEN}✓${NC} Issue created: ${BOLD}$issue_url${NC}"
    echo -e "  Tracked in: $(_upstream_sent_file)"
}

do_upstream_list() {
    local sent_file
    sent_file=$(_upstream_sent_file)

    if [ ! -f "$sent_file" ]; then
        echo -e "No upstream issues sent yet."
        return 0
    fi

    echo -e "${BOLD}Upstream Issues Sent${NC}"
    echo ""
    while IFS= read -r line; do
        local ts url title_part
        ts=$(echo "$line" | cut -d'|' -f1 | tr -d ' ')
        url=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
        title_part=$(echo "$line" | cut -d'|' -f3-)
        echo -e "  ${GREEN}$ts${NC}  $url"
        echo -e "    $title_part"
    done < "$sent_file"
}

# --- Router ---

do_upstream() {
    local subcmd="${1:-}"
    shift || true

    case "$subcmd" in
        config)
            do_upstream_config "$@"
            ;;
        status)
            do_upstream_status "$@"
            ;;
        report)
            do_upstream_report "$@"
            ;;
        list)
            do_upstream_list "$@"
            ;;
        ""|help|-h|--help)
            echo -e "${BOLD}fw upstream${NC} — Report issues to framework upstream repo"
            echo ""
            echo -e "${BOLD}Subcommands:${NC}"
            echo -e "  ${GREEN}config${NC}                     Show upstream configuration"
            echo -e "  ${GREEN}config --repo OWNER/REPO${NC}   Set upstream repo explicitly"
            echo -e "  ${GREEN}status${NC}                     Show config + auth + history"
            echo -e "  ${GREEN}report${NC} --title \"...\"       Create issue on upstream repo"
            echo -e "  ${GREEN}list${NC}                       Show issues previously sent"
            echo ""
            echo -e "${BOLD}Report options:${NC}"
            echo -e "  --title \"...\"        ${BOLD}(required)${NC} Issue title"
            echo -e "  --body \"...\"         Issue description"
            echo -e "  --attach-doctor      Include fw doctor output"
            echo -e "  --attach-patch REF   Include git diff as patch (e.g., HEAD~1)"
            echo -e "  --label NAME         Additional label (default: field-report)"
            echo -e "  --dry-run            Show what would be created without creating"
            echo -e "  --force              Skip duplicate check and confirmation"
            echo ""
            echo -e "${BOLD}Examples:${NC}"
            echo -e "  fw upstream report --title \"Bug: audit fails on empty task list\" --attach-doctor"
            echo -e "  fw upstream report --title \"Fix: budget gate stale status\" --body \"Details...\" --attach-patch HEAD~1"
            echo -e "  fw upstream report --title \"Feature: harvest --upstream\" --dry-run"
            ;;
        *)
            echo -e "${RED}Unknown upstream subcommand: $subcmd${NC}" >&2
            echo -e "Run ${GREEN}fw upstream help${NC} for usage." >&2
            return 1
            ;;
    esac
}
