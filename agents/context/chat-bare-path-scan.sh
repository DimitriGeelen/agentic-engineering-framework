#!/bin/bash
# Stop hook — chat bare-path scanner (T-2183, Slice 2 of T-2181)
#
# Structural backstop for the bare-path regression class (T-2125 / T-2129 / T-2181):
# agents must surface Watchtower handoffs as FULL URLs (http://host/review/T-XXX),
# never as bare paths (`/review/T-XXX`) hand-typed into chat output. Slice 1 (T-2182)
# shipped the `fw task review-batch` helper that emits correct URLs; this Slice 2 is
# defence-in-depth — it catches the regression even when the helper isn't used.
#
# Fires on every Stop event. Reads the just-completed assistant turn from the
# transcript, strips code blocks + inline code (where bare paths are legitimate —
# the literal regex, doc examples, CLI snippets), then regex-scans markdown
# bullet/table-cell contexts for bare Watchtower paths NOT part of an http(s):// URL.
# Violations are appended to .context/working/.bare-path-violations.yaml; the
# companion UserPromptSubmit hook (chat-bare-path-warn.sh) surfaces them next turn.
#
# SAFETY (G-016 storm class — learnings.yaml:1998): the 2026-04-24 commit-storm was a
# DESTRUCTIVE child script (T-1223 silent-session scanner running commits/pushes) in a
# runaway. This hook is NON-DESTRUCTIVE (appends to one YAML file) and ALWAYS exits 0 —
# it cannot block, so it cannot drive a continue->Stop->continue loop, and it performs
# no git/filesystem-destructive operations. The storm root cause does not apply.
#
# Stop hook payload (stdin JSON): session_id, transcript_path, stop_hook_active,
# hook_event_name. We read transcript_path; $CLAUDE_TRANSCRIPT_PATH is a fallback.
#
# Part of: Agentic Engineering Framework — T-2183 (T-2181 GO Candidate D, Slice 2)

set -uo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WORKING_DIR="${PROJECT_ROOT}/.context/working"
VIOLATIONS="${WORKING_DIR}/.bare-path-violations.yaml"

mkdir -p "$WORKING_DIR" 2>/dev/null || true

# Read the whole stdin payload (Stop hook convention).
PAYLOAD="$(cat 2>/dev/null || true)"

python3 - "$PAYLOAD" "$VIOLATIONS" "${CLAUDE_TRANSCRIPT_PATH:-}" <<'PYEOF'
import sys, os, json, re, time

payload_raw, violations_path, env_transcript = sys.argv[1], sys.argv[2], sys.argv[3]

# --- Resolve transcript path: payload.transcript_path, else $CLAUDE_TRANSCRIPT_PATH ---
transcript = ""
try:
    payload = json.loads(payload_raw) if payload_raw.strip() else {}
    transcript = payload.get("transcript_path") or ""
except Exception:
    payload = {}
if not transcript:
    transcript = env_transcript or ""

if not transcript or not os.path.isfile(transcript):
    sys.exit(0)  # nothing to scan — never block

# --- Extract the text of the last assistant turn from the JSONL transcript ---
def last_assistant_text(path):
    last_text = None
    try:
        with open(path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                # Claude Code transcript: records carry {"type":"assistant","message":{...}}
                msg = rec.get("message") if isinstance(rec, dict) else None
                role = (rec.get("role") if isinstance(rec, dict) else None) or \
                       (msg.get("role") if isinstance(msg, dict) else None)
                if role != "assistant":
                    continue
                content = (msg or rec).get("content")
                parts = []
                if isinstance(content, str):
                    parts.append(content)
                elif isinstance(content, list):
                    for blk in content:
                        if isinstance(blk, dict) and blk.get("type") == "text":
                            parts.append(blk.get("text", ""))
                        elif isinstance(blk, str):
                            parts.append(blk)
                if parts:
                    last_text = "\n".join(parts)
    except Exception:
        return None
    return last_text

text = last_assistant_text(transcript)
if not text:
    sys.exit(0)

# --- Strip fenced code blocks and inline-code spans (bare paths are OK there) ---
def strip_code(s):
    # fenced ```...``` (incl language tag), non-greedy, multiline
    s = re.sub(r"```.*?```", " ", s, flags=re.DOTALL)
    # inline `...`
    s = re.sub(r"`[^`]*`", " ", s)
    return s

scan_text = strip_code(text)

# Watchtower route stems that must be surfaced as full URLs in chat.
ROUTES = r"(?:review|inception|approvals|arcs|gaps|fabric|cockpit|settings)"
# A bare path: /<route>/<id> where <id> looks like T-NNNN, a slug, etc.
BARE = re.compile(r"/" + ROUTES + r"/T?-?[A-Za-z0-9_][A-Za-z0-9_-]*")
# Any http(s):// URL — strip these first so /review/X inside a real URL is NOT flagged.
URL = re.compile(r"https?://\S+")

def is_markdown_context(line):
    st = line.lstrip()
    if st.startswith(("- ", "* ", "+ ")):
        return True
    if re.match(r"\d+\.\s", st):
        return True
    if "|" in line:  # table cell
        return True
    return False

violations = []
for raw_line in scan_text.splitlines():
    if not is_markdown_context(raw_line):
        continue
    # Remove real URLs first — their /review/X tail is correct, not a violation.
    line_wo_urls = URL.sub(" ", raw_line)
    for m in BARE.finditer(line_wo_urls):
        violations.append(m.group(0))

if not violations:
    sys.exit(0)

# --- Append violations as YAML entries (consume-on-show by the warn hook) ---
ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
sid = ""
try:
    sid = payload.get("session_id", "") if isinstance(payload, dict) else ""
except Exception:
    sid = ""

# De-dupe within this turn, preserve order.
seen = set()
uniq = []
for v in violations:
    if v not in seen:
        seen.add(v)
        uniq.append(v)

try:
    with open(violations_path, "a") as f:
        for v in uniq:
            f.write("- path: %s\n" % json.dumps(v))
            f.write("  ts: %s\n" % ts)
            if sid:
                f.write("  session: %s\n" % json.dumps(sid))
except Exception:
    pass

sys.exit(0)  # never block
PYEOF

exit 0
