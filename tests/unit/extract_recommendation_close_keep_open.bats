#!/usr/bin/env bats
# T-1960: extend extract_recommendation parser to accept CLOSE / KEEP-OPEN
# verdicts (in addition to GO / NO-GO / DEFER). Pinned so the arc-close
# recommendation surface doesn't silently fall back to verdict='?'.

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    cd "$PROJECT_ROOT"
}

extract() {
    local body="$1"
    python3 -c "
import sys, json
sys.path.insert(0, 'web')
from shared import extract_recommendation
print(json.dumps(extract_recommendation(sys.stdin.read())))
" <<<"$body"
}

@test "CLOSE verdict is extracted" {
    body=$'## Recommendation\n\n**Recommendation:** CLOSE\n\n**Rationale:** Demo wire-fired.\n'
    out=$(extract "$body")
    [[ "$out" == *'"verdict": "CLOSE"'* ]]
}

@test "KEEP-OPEN verdict is extracted" {
    body=$'## Recommendation\n\n**Recommendation:** KEEP-OPEN\n\n**Rationale:** One headline-mechanic instance still missing.\n'
    out=$(extract "$body")
    [[ "$out" == *'"verdict": "KEEP-OPEN"'* ]]
}

@test "GO verdict still works (regression guard)" {
    body=$'## Recommendation\n\n**Recommendation:** GO\n\n**Rationale:** Tests green.\n'
    out=$(extract "$body")
    [[ "$out" == *'"verdict": "GO"'* ]]
}

@test "NO-GO verdict still works (regression guard)" {
    body=$'## Recommendation\n\n**Recommendation:** NO-GO\n\n**Rationale:** Substrate gap.\n'
    out=$(extract "$body")
    [[ "$out" == *'"verdict": "NO-GO"'* ]]
}

@test "DEFER verdict still works (regression guard)" {
    body=$'## Recommendation\n\n**Recommendation:** DEFER\n\n**Rationale:** Wait for upstream.\n'
    out=$(extract "$body")
    [[ "$out" == *'"verdict": "DEFER"'* ]]
}

@test "CLOSE verdict captures rationale and evidence" {
    body=$'## Recommendation\n\n**Recommendation:** CLOSE\n\n**Rationale:** Two demo instances captured.\n\n**Evidence:**\n\n- docs/reports/arc-006-demo.md\n- live URL: https://watchtower.example/arcs/value-prioritisation\n'
    out=$(extract "$body")
    [[ "$out" == *'"verdict": "CLOSE"'* ]]
    [[ "$out" == *"Two demo instances captured"* ]]
    [[ "$out" == *"arc-006-demo.md"* ]]
}

@test "lowercase close is extracted as CLOSE (case-insensitive)" {
    body=$'## Recommendation\n\n**Recommendation:** close\n\n**Rationale:** ok.\n'
    out=$(extract "$body")
    [[ "$out" == *'"verdict": "CLOSE"'* ]]
}

@test "lowercase keep-open is extracted as KEEP-OPEN (case-insensitive)" {
    body=$'## Recommendation\n\n**Recommendation:** keep-open\n\n**Rationale:** ok.\n'
    out=$(extract "$body")
    [[ "$out" == *'"verdict": "KEEP-OPEN"'* ]]
}

@test "no Recommendation section → verdict is '?'" {
    body=$'## Other\n\nNothing here.\n'
    out=$(extract "$body")
    [[ "$out" == *'"verdict": "?"'* ]]
}
