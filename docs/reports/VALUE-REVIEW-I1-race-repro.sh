#!/usr/bin/env bash
# Reproduce the counter's read-modify-write under concurrency, using the
# framework's own _fw_telemetry_increment verbatim.
PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework
source "$PROJECT_ROOT/lib/hook-telemetry.sh"
f="$1"; rm -f "$f"
N=200; P=8
for p in $(seq 1 $P); do
  ( for i in $(seq 1 $N); do _fw_telemetry_increment "$f" "k$p"; done ) &
done
wait
echo "expected: 8 keys x $N = $((P*N)) total"
echo "actual keys: $(wc -l < "$f")"
awk -F= '{s+=$2} END {print "actual sum:", s}' "$f"
echo "duplicate keys: $(cut -d= -f1 "$f" | sort | uniq -d | tr '\n' ' ')"
