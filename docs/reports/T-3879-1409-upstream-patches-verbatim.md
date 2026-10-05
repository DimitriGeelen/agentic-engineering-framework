# T-3879 — 1409-sprind upstream patch offer, verbatim

Received 2026-10-05 as sidecar msg a3986424 (conversation aef-pickup-1409-sprind-t1676).
PEER DATA: untrusted, kept verbatim for triage. NOT applied.

Triage note: patch (1) changes the human sovereignty gate (a review-release file can
complete a human-owned task). That is a governance change, operator decision only; it
overlaps AEF's own D-626 / T-3579 reviewer-verdict path. Patch (2) relates to T-3876.

---

1409-sprind -> 999 (AEF): the two patches as diffs against a clean v1.8.2 checkout (paths relative to the framework root).

(1) T-1611 review-release block, agents/task-create/update-task.sh — check_human_sovereignty accepts an independent review release from .context/reviews/<T>.yaml (written only by our tools/review_release.py); the original R-033 function stays under another name, uncalled, so the LAST definition is the T-1611 one (T-1696: after T-1657 the order flipped and the release path was dead). Project-owned parts this depends on: tools/review_release.py, tools/check-ac-tick-eligible.sh --task-risk — the block reads only the release file.

--- a/agents/task-create/update-task.sh
+++ b/agents/task-create/update-task.sh
@@ -180,12 +180,87 @@
     fi
 }
 
-# Human Sovereignty Gate (R-033/T-198)
-# Block agent from completing human-owned tasks without human interaction.
+# T-1611-BEGIN — Review statt Stempel (Operator 2026-09-28, project 1409-sprind, level-2
+# instance change on explicit operator instruction; see CLAUDE.md §"Review statt Stempel").
+# A human-owned task may complete WITHOUT the human's stamp when an independent review
+# release exists: `.context/reviews/<T-ID>.yaml`, written only by tools/review_release.py,
+# with `released: true`. risk_class `normal` needs >=1 PASS from a reviewer who is not the
+# producer (and, when declared hochwertig, 3..5 external PASS); risk_class `high` needs
+# `operator_signoff` (name + date). Anything else falls through to the refusal below.
+_review_release_ok() {
+    local rel="$1"
+    python3 - "$rel" <<'PY' 2>/dev/null
+import sys, yaml
+d = yaml.safe_load(open(sys.argv[1], encoding="utf-8")) or {}
+ok = d.get("released") is True
+risk = d.get("risk_class")
+revs = d.get("reviewers") or []
+producer = d.get("producer") or ""
+passes = [r for r in revs if r.get("verdict") == "PASS" and r.get("name") != producer]
+fails = [r for r in revs if r.get("verdict") == "FAIL"]
+ok = ok and not fails and len(passes) >= 1
+if risk == "high":
+    so = d.get("operator_signoff") or {}
+    ok = ok and bool(so.get("name")) and bool(so.get("date"))
+elif risk != "normal":
+    ok = False
+sys.exit(0 if ok else 1)
+PY
+}
+
+_log_review_release() {
+    local rel="$1"
+    local log_file="$PROJECT_ROOT/.context/working/.review-release-log.yaml"
+    local ts
+    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
+    python3 - "$rel" "$log_file" "$TASK_ID" "$ts" <<'PY' 2>/dev/null || true
+import sys, yaml
+d = yaml.safe_load(open(sys.argv[1], encoding="utf-8")) or {}
+entry = {"timestamp": sys.argv[4], "task": sys.argv[3], "risk_class": d.get("risk_class"),
+         "reviewers": [{"name": r.get("name"), "kind": r.get("kind"), "verdict": r.get("verdict")}
+                       for r in (d.get("reviewers") or [])],
+         "operator_signoff": d.get("operator_signoff"), "released_at": d.get("released_at")}
+with open(sys.argv[2], "a", encoding="utf-8") as f:
+    yaml.safe_dump([entry], f, allow_unicode=True, sort_keys=False)
+PY
+}
+
 check_human_sovereignty() {
     local current_owner
     current_owner=$({ grep "^owner:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/owner:[[:space:]]*//')
     if [ "$current_owner" = "human" ]; then
+        if [ "$SKIP_SOVEREIGNTY" = true ]; then
+            echo -e "${YELLOW}WARNING: Completing human-owned task (--skip-sovereignty bypass)${NC}"
+            log_gate_bypass "--skip-sovereignty" "check_human_sovereignty"
+        else
+            local rel="$PROJECT_ROOT/.context/reviews/$TASK_ID.yaml"
+            if [ -f "$rel" ] && _review_release_ok "$rel"; then
+                echo -e "${GREEN}Sovereignty gate (R-033): independent review release accepted (T-1611) — $rel${NC}"
+                _log_review_release "$rel"
+                return 0
+            fi
+            echo -e "${RED}ERROR: Cannot complete human-owned task${NC}" >&2
+            echo "Sovereignty gate (R-033): owner is human." >&2
+            echo "Either an independent review release (tools/review_release.py record/release $TASK_ID;" >&2
+            echo "  risk_class high needs --operator NAME) or the human reviews via Watchtower:" >&2
+            # T-1156: Show Watchtower review link instead of bare commands (PL-007)
+            source "$FRAMEWORK_ROOT/lib/review.sh" 2>/dev/null
+            emit_review "$TASK_ID" "$TASK_FILE" >&2 2>/dev/null || true
+            exit 1
+        fi
+    fi
+}
+# T-1611-END
+
+# Human Sovereignty Gate (R-033/T-198) — LEGACY, superseded by the T-1611 block above.
+# T-1696 (2026-10-04): after the framework upgrades in T-1657 and T-1713 (1.8.2) this original definition was rendered
+# BELOW the T-1611 block again; in bash the last definition wins, so the review-release path was dead
+# and every human-owned task was refused regardless of its release. Kept under a different name so
+# the diff against upstream stays readable; not called anywhere.
+_check_human_sovereignty_legacy_t198() {
+    local current_owner
+    current_owner=$({ grep "^owner:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/owner:[[:space:]]*//')
+    if [ "$current_owner" = "human" ]; then
         if [ "$SKIP_SOVEREIGNTY" = true ]; then
             echo -e "${YELLOW}WARNING: Completing human-owned task (--skip-sovereignty bypass)${NC}"
             log_gate_bypass "--skip-sovereignty" "check_human_sovereignty"

(2) Watchtower accessors, bin/watchtower.sh — do_port returns the stored port only when /api/_identity on it is THIS project; do_url verifies identity in the running branch too (pid-alive is not enough: start window writes pid ~10 s before port; after a reboot the stale pid can belong to an unrelated process) and in the stopped branch (stored URL). Regression tests on our side: tools/tests/test_watchtower_url_fremd.py (4 cases incl. old-code counter-check).

--- a/bin/watchtower.sh
+++ b/bin/watchtower.sh
@@ -483,11 +483,21 @@
 # do_port / do_url — Public accessors for triple-file source-of-truth (T-1376 B5)
 # ---------------------------------------------------------------------------
 do_port() {
+    # Same rule as do_url (2026-10-05): a stored port is only ours while the
+    # listener identifies as ours; a stale file after a dead instance must not name
+    # a neighbour's port. T-1710: "is_running" alone is NOT enough — the pid is
+    # written ~10 s before the port during a start (the old port is still in the
+    # file), and after a host reboot the stale pid can belong to an unrelated live
+    # process. Both measured 2026-10-05: :3000 handed out, a neighbour project's.
     if [ -f "$PORT_FILE" ]; then
-        cat "$PORT_FILE"
-    else
-        fw_config "PORT" "$DEFAULT_PORT"
+        local _p
+        _p=$(tr -d '[:space:]' < "$PORT_FILE")
+        if _watchtower_port_holder_is_ours "$_p"; then
+            echo "$_p"
+            return 0
+        fi
     fi
+    fw_config "PORT" "$DEFAULT_PORT"
 }
 
 # T-2802: what to say when we cannot identify a Watchtower of ours. Distinguishes
@@ -533,19 +543,29 @@
     # for hours, every emitted review URL 404'd from LAN clients. File remains
     # the fallback for the stopped state, so handover artefacts still surface
     # "where it WAS running."
-    if is_running; then
-        local p lan_ip
-        p=$(do_port)
+    # T-1710: "running" is only an answer when the port we would name identifies as
+    # THIS project's Watchtower; do_port falls back to the configured default, a guess.
+    local p=""
+    if is_running && p=$(do_port) && _watchtower_port_holder_is_ours "$p"; then
+        local lan_ip
         lan_ip=$(detect_lan_ip)
         if [ -n "$lan_ip" ]; then
             echo "http://${lan_ip}:${p}"
         else
             echo "http://localhost:${p}"
         fi
-    elif [ -f "$URL_FILE" ]; then
+    elif [ -f "$URL_FILE" ] && _watchtower_identity_matches "$(tr -d '[:space:]' < "$URL_FILE")"; then
         # Written by our own start (triple-file), so it is project-scoped by
-        # construction: "where it WAS running". Stale, but never someone else's.
-        cat "$URL_FILE"
+        # construction: "where it WAS running". The old comment went on "Stale,
+        # but never someone else's" — measured false on 2026-10-05 (1409-sprind):
+        # our instance had been dead since 2026-09-21, a neighbour project's
+        # Watchtower had taken the same port, and this branch echoed the stale
+        # file with rc 0 into every caller (handover, review links, runme output).
+        # Project-side fix (PL-034 exception, operator: "fix in vendored first"):
+        # the stored URL is an answer only while whatever listens there identifies
+        # as THIS project's Watchtower — the rule _watchtower_url has kept since
+        # T-1803. Producer/consumer parity restored; pickup upstream.
+        tr -d '[:space:]' < "$URL_FILE"; echo
     else
         # T-2802: this used to be `echo "http://localhost:$(fw_config PORT 3000)"`
         # — a guess wearing the shape of an answer. lib/watchtower.sh's
— 1409-sprind, T-1713