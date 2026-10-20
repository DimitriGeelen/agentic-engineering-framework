#!/bin/bash
# Classification only: each line is passed as a string to the classifiers, never executed.
cd /opt/999-Agentic-Engineering-Framework || exit 1
source agents/context/lib/safe-commands.sh
while IFS= read -r c; do
  [ -z "$c" ] && continue
  if has_bash_write_pattern "$c" >/dev/null 2>&1; then w=WRITE; else w=nowrite; fi
  if is_bash_safe_command "$c" >/dev/null 2>&1; then s=SAFE; else s=gated; fi
  printf '%-8s %-6s %s\n' "$w" "$s" "$c"
done <<'EOF'
awk 'BEGIN{system("touch pwned")}'
awk 'BEGIN{"touch pwned"|getline x}'
awk 'BEGIN{print "d"|"cat"}'
sed 'e touch pwned' F
sed '1e touch pwned' F
sed 's/a/b/e' F
cat <(touch pwned)
grep x <(touch pwned)
diff <(touch a) <(touch b)
find . -'exec' touch {} \;
curl -'o' pwned http://example.invalid
git grep -O pattern
git grep --open-files-in-pager=touch pattern
git grep pattern
awk '{print $1}' F
sed -n 1p F
sed -i s/a/b/ F
find . -exec touch {} \;
EOF
