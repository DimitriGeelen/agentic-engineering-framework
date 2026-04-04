#!/bin/bash
# lib/version.sh — Version bumping, checking, and sync for the Agentic Engineering Framework
#
# Provides:
#   fw version bump [major|minor|patch] [--tag] [--dry-run]
#   fw version check
#   fw version sync [--dry-run]
#
# Single source of truth: FW_VERSION in bin/fw line 14
# All other VERSION files are derived copies.
#
# Part of: Agentic Engineering Framework (T-606)

# Version staleness threshold (commits since last tag)
VERSION_STALENESS_THRESHOLD=50

do_version_bump() {
    local component="" do_tag=false dry_run=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            major|minor|patch) component="$1"; shift ;;
            --tag) do_tag=true; shift ;;
            --dry-run) dry_run=true; shift ;;
            -h|--help) _version_bump_help; return 0 ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                _version_bump_help >&2
                return 1
                ;;
        esac
    done

    if [ -z "$component" ]; then
        echo -e "${RED}ERROR: Version component required (major|minor|patch)${NC}" >&2
        _version_bump_help >&2
        return 1
    fi

    # Guard: only in framework repo
    if [ "$PROJECT_ROOT" != "$FRAMEWORK_ROOT" ]; then
        echo -e "${RED}ERROR: fw version bump is only available in the framework repo${NC}" >&2
        echo "Use 'fw update' to get the latest version from upstream." >&2
        return 1
    fi

    # Read current version
    local current_version
    current_version=$(_read_fw_version)
    if [ -z "$current_version" ]; then
        echo -e "${RED}ERROR: Could not read FW_VERSION from bin/fw${NC}" >&2
        return 1
    fi

    # Validate semver format
    if ! echo "$current_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo -e "${RED}ERROR: Current version '$current_version' is not valid semver (X.Y.Z)${NC}" >&2
        return 1
    fi

    # Parse components
    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"

    # Compute new version
    case "$component" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
    esac

    local new_version="${major}.${minor}.${patch}"

    # Collect files to update
    local files_to_update=()
    local fw_bin="$FRAMEWORK_ROOT/bin/fw"
    local root_version="$FRAMEWORK_ROOT/VERSION"
    local vendored_version="$FRAMEWORK_ROOT/.agentic-framework/VERSION"
    local vendored_bin="$FRAMEWORK_ROOT/.agentic-framework/bin/fw"

    files_to_update+=("$fw_bin")
    [ -f "$root_version" ] && files_to_update+=("$root_version")
    [ -f "$vendored_version" ] && files_to_update+=("$vendored_version")
    [ -f "$vendored_bin" ] && files_to_update+=("$vendored_bin")

    # Dry-run mode
    if [ "$dry_run" = true ]; then
        echo -e "${CYAN}[dry-run]${NC} Would bump ${BOLD}$current_version${NC} → ${BOLD}$new_version${NC} ($component)"
        echo ""
        echo "Files to update:"
        for f in "${files_to_update[@]}"; do
            local rel
            rel="${f#"$FRAMEWORK_ROOT"/}"
            echo "  $rel"
        done
        if [ "$do_tag" = true ]; then
            echo ""
            echo "Would create tag: v$new_version"
        fi
        return 0
    fi

    # Perform bump
    echo -e "${BOLD}Bumping${NC} $current_version → ${GREEN}$new_version${NC} ($component)"
    echo ""

    # 1. Update FW_VERSION in bin/fw
    _sed_i "s/^FW_VERSION=\"$current_version\"/FW_VERSION=\"$new_version\"/" "$fw_bin"
    echo -e "  ${GREEN}✓${NC} bin/fw FW_VERSION"

    # 2. Update root VERSION file
    if [ -f "$root_version" ]; then
        echo "$new_version" > "$root_version"
        echo -e "  ${GREEN}✓${NC} VERSION"
    fi

    # 3. Update vendored VERSION file
    if [ -f "$vendored_version" ]; then
        echo "$new_version" > "$vendored_version"
        echo -e "  ${GREEN}✓${NC} .agentic-framework/VERSION"
    fi

    # 4. Update vendored bin/fw
    if [ -f "$vendored_bin" ]; then
        _sed_i "s/^FW_VERSION=\"$current_version\"/FW_VERSION=\"$new_version\"/" "$vendored_bin"
        echo -e "  ${GREEN}✓${NC} .agentic-framework/bin/fw FW_VERSION"
    fi

    # 5. Git commit
    echo ""
    git add "$fw_bin"
    [ -f "$root_version" ] && git add "$root_version"
    [ -f "$vendored_version" ] && git add "$vendored_version"
    [ -f "$vendored_bin" ] && git add "$vendored_bin"

    # 6. Tag if requested
    if [ "$do_tag" = true ]; then
        local tag_name="v$new_version"
        if git rev-parse "$tag_name" >/dev/null 2>&1; then
            echo -e "${RED}ERROR: Tag $tag_name already exists${NC}" >&2
            echo "Files have been updated but not committed. Resolve manually." >&2
            return 1
        fi
        echo -e "  ${GREEN}✓${NC} Tag: $tag_name"
    fi

    echo ""
    echo -e "${GREEN}Version bumped to $new_version${NC}"
    echo ""
    echo "Staged files — commit with:"
    echo "  fw git commit -m \"T-XXX: Bump version to $new_version\""
    if [ "$do_tag" = true ]; then
        echo ""
        echo "Then tag:"
        echo "  git tag -a v$new_version -m \"Release $new_version\""
    fi
    echo ""
    echo "Then push:"
    echo "  git push && git push --tags"
}

do_version_check() {
    local all_sync=true
    local fw_version
    fw_version=$(_read_fw_version)

    echo -e "${BOLD}Version Consistency Check${NC}"
    echo ""

    # 1. FW_VERSION (source of truth)
    echo -e "  FW_VERSION (bin/fw):             ${BOLD}$fw_version${NC}"

    # 2. Root VERSION file
    local root_version_file="$FRAMEWORK_ROOT/VERSION"
    if [ -f "$root_version_file" ]; then
        local root_val
        root_val=$(tr -d '[:space:]' < "$root_version_file")
        if [ "$root_val" = "$fw_version" ]; then
            echo -e "  VERSION (root):                  ${GREEN}$root_val${NC} ✓"
        else
            echo -e "  VERSION (root):                  ${RED}$root_val${NC} ✗ (expected $fw_version)"
            all_sync=false
        fi
    else
        echo -e "  VERSION (root):                  ${YELLOW}missing${NC}"
    fi

    # 3. Vendored VERSION
    local vendored_version="$FRAMEWORK_ROOT/.agentic-framework/VERSION"
    if [ -f "$vendored_version" ]; then
        local vendored_val
        vendored_val=$(tr -d '[:space:]' < "$vendored_version")
        if [ "$vendored_val" = "$fw_version" ]; then
            echo -e "  .agentic-framework/VERSION:      ${GREEN}$vendored_val${NC} ✓"
        else
            echo -e "  .agentic-framework/VERSION:      ${RED}$vendored_val${NC} ✗ (expected $fw_version)"
            all_sync=false
        fi
    fi

    # 4. Vendored bin/fw
    local vendored_bin="$FRAMEWORK_ROOT/.agentic-framework/bin/fw"
    if [ -f "$vendored_bin" ]; then
        local vendored_bin_val
        vendored_bin_val=$(grep '^FW_VERSION=' "$vendored_bin" 2>/dev/null | sed 's/FW_VERSION="//;s/"//')
        if [ "$vendored_bin_val" = "$fw_version" ]; then
            echo -e "  .agentic-framework/bin/fw:       ${GREEN}$vendored_bin_val${NC} ✓"
        else
            echo -e "  .agentic-framework/bin/fw:       ${RED}$vendored_bin_val${NC} ✗ (expected $fw_version)"
            all_sync=false
        fi
    fi

    # 5. Latest git tag
    echo ""
    local latest_tag
    latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
    if [ -n "$latest_tag" ]; then
        local tag_version="${latest_tag#v}"
        local commits_since
        commits_since=$(git rev-list --count "${latest_tag}..HEAD" 2>/dev/null || echo 0)

        if [ "$tag_version" = "$fw_version" ] && [ "$commits_since" -eq 0 ]; then
            echo -e "  Latest tag:                      ${GREEN}$latest_tag${NC} (current) ✓"
        elif [ "$tag_version" = "$fw_version" ]; then
            echo -e "  Latest tag:                      ${YELLOW}$latest_tag${NC} ($commits_since commits since tag)"
            if [ "$commits_since" -gt "$VERSION_STALENESS_THRESHOLD" ]; then
                echo -e "  ${YELLOW}WARNING: $commits_since commits since last tag (threshold: $VERSION_STALENESS_THRESHOLD)${NC}"
                echo -e "  Consider: ${CYAN}fw version bump patch --tag${NC}"
            fi
        else
            echo -e "  Latest tag:                      ${RED}$latest_tag${NC} (FW_VERSION=$fw_version differs from tag=$tag_version)"
            all_sync=false
        fi
    else
        echo -e "  Latest tag:                      ${YELLOW}none${NC}"
    fi

    # 6. .framework.yaml (consumer project only)
    if [ "$PROJECT_ROOT" != "$FRAMEWORK_ROOT" ] && [ -f "$PROJECT_ROOT/.framework.yaml" ]; then
        local pinned
        pinned=$(grep "^version:" "$PROJECT_ROOT/.framework.yaml" 2>/dev/null | sed 's/^version:[[:space:]]*//')
        if [ -n "$pinned" ]; then
            if [ "$pinned" = "$fw_version" ]; then
                echo -e "  .framework.yaml (pinned):        ${GREEN}$pinned${NC} ✓"
            else
                echo -e "  .framework.yaml (pinned):        ${YELLOW}$pinned${NC} (installed: $fw_version)"
            fi
        fi
    fi

    echo ""
    if [ "$all_sync" = true ]; then
        echo -e "${GREEN}All version sources in sync${NC}"
        return 0
    else
        echo -e "${RED}Version sources out of sync${NC} — run: ${CYAN}fw version sync${NC}"
        return 1
    fi
}

do_version_sync() {
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) dry_run=true; shift ;;
            -h|--help)
                echo "Usage: fw version sync [--dry-run]"
                echo "Sync all VERSION files to match FW_VERSION in bin/fw"
                return 0
                ;;
            *) echo -e "${RED}Unknown option: $1${NC}" >&2; return 1 ;;
        esac
    done

    # Guard: only in framework repo
    if [ "$PROJECT_ROOT" != "$FRAMEWORK_ROOT" ]; then
        echo -e "${RED}ERROR: fw version sync is only available in the framework repo${NC}" >&2
        return 1
    fi

    local fw_version
    fw_version=$(_read_fw_version)

    echo -e "${BOLD}Syncing all version sources to $fw_version${NC}"
    echo ""

    local changed=0

    # Root VERSION
    local root_version="$FRAMEWORK_ROOT/VERSION"
    if [ -f "$root_version" ]; then
        local current
        current=$(tr -d '[:space:]' < "$root_version")
        if [ "$current" != "$fw_version" ]; then
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}[dry-run]${NC} VERSION: $current → $fw_version"
            else
                echo "$fw_version" > "$root_version"
                echo -e "  ${GREEN}✓${NC} VERSION: $current → $fw_version"
            fi
            changed=$((changed + 1))
        else
            echo -e "  ${GREEN}✓${NC} VERSION: $fw_version (already synced)"
        fi
    fi

    # Vendored VERSION
    local vendored_version="$FRAMEWORK_ROOT/.agentic-framework/VERSION"
    if [ -f "$vendored_version" ]; then
        local current
        current=$(tr -d '[:space:]' < "$vendored_version")
        if [ "$current" != "$fw_version" ]; then
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}[dry-run]${NC} .agentic-framework/VERSION: $current → $fw_version"
            else
                echo "$fw_version" > "$vendored_version"
                echo -e "  ${GREEN}✓${NC} .agentic-framework/VERSION: $current → $fw_version"
            fi
            changed=$((changed + 1))
        else
            echo -e "  ${GREEN}✓${NC} .agentic-framework/VERSION: $fw_version (already synced)"
        fi
    fi

    # Vendored bin/fw
    local vendored_bin="$FRAMEWORK_ROOT/.agentic-framework/bin/fw"
    if [ -f "$vendored_bin" ]; then
        local current
        current=$(grep '^FW_VERSION=' "$vendored_bin" 2>/dev/null | sed 's/FW_VERSION="//;s/"//')
        if [ "$current" != "$fw_version" ]; then
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}[dry-run]${NC} .agentic-framework/bin/fw: $current → $fw_version"
            else
                _sed_i "s/^FW_VERSION=\"$current\"/FW_VERSION=\"$fw_version\"/" "$vendored_bin"
                echo -e "  ${GREEN}✓${NC} .agentic-framework/bin/fw: $current → $fw_version"
            fi
            changed=$((changed + 1))
        else
            echo -e "  ${GREEN}✓${NC} .agentic-framework/bin/fw: $fw_version (already synced)"
        fi
    fi

    echo ""
    if [ "$changed" -eq 0 ]; then
        echo -e "${GREEN}All files already in sync${NC}"
    elif [ "$dry_run" = true ]; then
        echo -e "${CYAN}$changed file(s) would be updated${NC}"
    else
        echo -e "${GREEN}$changed file(s) updated${NC}"
    fi
}

# --- Internal helpers ---

_read_fw_version() {
    # T-690: Since T-648, FW_VERSION is dynamic ($(_derive_version)), not a literal.
    # Use the already-evaluated FW_VERSION variable instead of grep from file.
    echo "${FW_VERSION:-}"
}

_version_bump_help() {
    echo -e "${BOLD}fw version bump${NC} — Bump framework version"
    echo ""
    echo "Usage: fw version bump <major|minor|patch> [--tag] [--dry-run]"
    echo ""
    echo "Options:"
    echo "  major      Bump major version (X.0.0)"
    echo "  minor      Bump minor version (0.X.0)"
    echo "  patch      Bump patch version (0.0.X)"
    echo "  --tag      Create annotated git tag vX.Y.Z"
    echo "  --dry-run  Show what would change without modifying files"
    echo ""
    echo "Updates:"
    echo "  bin/fw FW_VERSION"
    echo "  VERSION"
    echo "  .agentic-framework/VERSION"
    echo "  .agentic-framework/bin/fw FW_VERSION"
}

# Version staleness check for audit integration
# Called by self-audit.sh — returns 0=ok, 1=warn, 2=fail
do_version_audit() {
    local pass=0 warn=0 fail=0

    local fw_version
    fw_version=$(_read_fw_version)

    # Check root VERSION sync
    local root_version="$FRAMEWORK_ROOT/VERSION"
    if [ -f "$root_version" ]; then
        local root_val
        root_val=$(tr -d '[:space:]' < "$root_version")
        if [ "$root_val" = "$fw_version" ]; then
            pass=$((pass + 1))
        else
            echo -e "  ${RED}FAIL${NC}  VERSION file ($root_val) != FW_VERSION ($fw_version)"
            fail=$((fail + 1))
        fi
    fi

    # Check vendored VERSION sync
    local vendored_version="$FRAMEWORK_ROOT/.agentic-framework/VERSION"
    if [ -f "$vendored_version" ]; then
        local vendored_val
        vendored_val=$(tr -d '[:space:]' < "$vendored_version")
        if [ "$vendored_val" = "$fw_version" ]; then
            pass=$((pass + 1))
        else
            echo -e "  ${YELLOW}WARN${NC}  .agentic-framework/VERSION ($vendored_val) != FW_VERSION ($fw_version)"
            warn=$((warn + 1))
        fi
    fi

    # Check tag staleness
    local latest_tag
    latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
    if [ -n "$latest_tag" ]; then
        local commits_since
        commits_since=$(git rev-list --count "${latest_tag}..HEAD" 2>/dev/null || echo 0)
        if [ "$commits_since" -gt "$VERSION_STALENESS_THRESHOLD" ]; then
            echo -e "  ${YELLOW}WARN${NC}  $commits_since commits since $latest_tag (threshold: $VERSION_STALENESS_THRESHOLD)"
            warn=$((warn + 1))
        else
            pass=$((pass + 1))
        fi
    fi

    # Return counts via stdout protocol (audit integration)
    echo "VERSION_AUDIT_PASS=$pass"
    echo "VERSION_AUDIT_WARN=$warn"
    echo "VERSION_AUDIT_FAIL=$fail"

    if [ "$fail" -gt 0 ]; then return 2; fi
    if [ "$warn" -gt 0 ]; then return 1; fi
    return 0
}
