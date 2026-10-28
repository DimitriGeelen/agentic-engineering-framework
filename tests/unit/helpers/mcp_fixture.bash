# tests/unit/helpers/mcp_fixture.bash — a private framework tree for MCP manifest tests (T-4862)
#
#   load helpers/mcp_fixture
#   setup()    { mcp_live_guard_begin; mcp_fixture_make; ... }
#   teardown() { ...; mcp_fixture_cleanup; mcp_live_guard_end; }
#
# WHY. t2293 and t2459 used to emit, edit and delete the live
# agents/mcp/framework-mcp-manifest.json and policy/capability-overlay/tool-set.yaml,
# restoring them from backups in teardown. The unit suite runs files in parallel
# (T-3602), so one file's emit landed inside another's delete-then-check window
# (t2293 t3, be.47 checks, T-4861), and a killed run left the repo edited.
#
# WHAT. mcp_fixture_make copies the TRACKED files of bin/, lib/, agents/mcp/ and
# policy/capability-overlay/ (plus FRAMEWORK.md, VERSION) from the working tree —
# so uncommitted edits are what gets tested — into a temp dir, marks it a project
# (.framework.yaml) and emits a manifest there. Run fw in it with mcp_fw.
# The live-guard pair fails a test that changed either live file's bytes or mode.

MCP_LIVE_FILES=(agents/mcp/framework-mcp-manifest.json policy/capability-overlay/tool-set.yaml)

_mcp_live_snapshot() {
    local f
    for f in "${MCP_LIVE_FILES[@]}"; do
        if [ -e "$FRAMEWORK_ROOT/$f" ]; then
            echo "$f $(stat -c %a "$FRAMEWORK_ROOT/$f") $(sha256sum < "$FRAMEWORK_ROOT/$f" | cut -d' ' -f1)"
        else
            echo "$f absent"
        fi
    done
}

mcp_live_guard_begin() { MCP_LIVE_BEFORE="$(_mcp_live_snapshot)"; }

mcp_live_guard_end() {
    local after
    after="$(_mcp_live_snapshot)"
    if [ "$after" != "${MCP_LIVE_BEFORE:-}" ]; then
        echo "T-4862: test changed the live MCP manifest/tool-set.yaml" >&2
        echo "before: ${MCP_LIVE_BEFORE:-}" >&2
        echo "after:  $after" >&2
        return 1
    fi
}

# mcp_fixture_make — sets and exports MCP_FIX (the fixture framework root).
mcp_fixture_make() {
    MCP_FIX_TMP="$(mktemp -d -t fw-mcpfix-XXXXXX)"
    MCP_FIX="$MCP_FIX_TMP/fw"
    mkdir -p "$MCP_FIX"
    (cd "$FRAMEWORK_ROOT" && git ls-files -z bin lib agents/mcp policy/capability-overlay FRAMEWORK.md VERSION \
        | tar --null -T - -cf -) | tar -xf - -C "$MCP_FIX"
    printf 'project_name: mcp-fixture\n' > "$MCP_FIX/.framework.yaml"
    export MCP_FIX MCP_FIX_TMP
    mcp_fw mcp emit-manifest > /dev/null
    [ -f "$MCP_FIX/agents/mcp/framework-mcp-manifest.json" ]
}

# mcp_fw ARGS... — the fixture's bin/fw, rooted at the fixture (never the live repo).
mcp_fw() {
    (cd "$MCP_FIX" && FRAMEWORK_ROOT="$MCP_FIX" PROJECT_ROOT="$MCP_FIX" bin/fw "$@")
}

mcp_fixture_cleanup() {
    [ -n "${MCP_FIX_TMP:-}" ] && [ -d "$MCP_FIX_TMP" ] && rm -rf "$MCP_FIX_TMP"
    return 0
}
