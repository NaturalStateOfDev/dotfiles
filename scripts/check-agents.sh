#!/usr/bin/env bash
# Lint Claude Code subagent files for frontmatter validity and public-repo hygiene.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="${1:-$root/dot_claude/agents}"
fail=0
say_fail() { echo "FAIL $1: $2"; fail=1; }

for f in "$dir"/*.md; do
  [ -e "$f" ] || { echo "no agent files in $dir"; exit 1; }
  # frontmatter is lines between the first two '---' lines
  fm=$(awk 'NR==1 && $0!="---"{exit 1} NR>1 && $0=="---"{exit} NR>1{print}' "$f") \
    || { say_fail "$f" "missing frontmatter"; continue; }
  name=$(grep -E '^name:' <<<"$fm" | sed 's/^name:[[:space:]]*//') || true
  [ -n "$name" ] || say_fail "$f" "missing name"
  [ "$name" = "$(basename "$f" .md)" ] || say_fail "$f" "name '$name' != filename"
  grep -qE '^description:[[:space:]]*\S' <<<"$fm" || say_fail "$f" "missing description"
  model=$(grep -E '^model:' <<<"$fm" | sed 's/^model:[[:space:]]*//') || true
  case "$model" in
    fable|opus|sonnet|haiku|inherit) ;;
    *) say_fail "$f" "model '$model' not in fable|opus|sonnet|haiku|inherit" ;;
  esac
  # read-only agents must block Edit and Write
  case "$name" in
    deploy-checker|staff-reviewer)
      grep -qE '^disallowedTools:.*\bEdit\b' <<<"$fm" && grep -qE '^disallowedTools:.*\bWrite\b' <<<"$fm" \
        || say_fail "$f" "must set disallowedTools: Edit, Write" ;;
    staff-auditor)
      grep -qE '^disallowedTools:.*\bEdit\b' <<<"$fm" || say_fail "$f" "must set disallowedTools: Edit" ;;
  esac
  # body must exist
  [ "$(awk 'c>=2{print} /^---$/{c++}' "$f" | grep -c .)" -gt 5 ] || say_fail "$f" "body too short"
done

# hygiene: patterns that must never appear in synced files
targets=("$root"/dot_claude/agents "$root"/dot_claude/skills/staff "$root"/dot_claude/staff)
if grep -rniE '[0-9]{12}|\.internal\b|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}' "${targets[@]}" 2>/dev/null; then
  echo "FAIL hygiene: secret-looking pattern found above"; fail=1
fi

# machine-local denylist for names that must never appear; never commit it.
# Entries are extended regexes, one per line.
deny="${CHECK_AGENTS_DENYLIST:-$HOME/.config/check-agents.denylist}"
if [ -f "$deny" ]; then
  extra=$(grep -vE '^[[:space:]]*(#|$)' "$deny" | paste -sd'|' - || true)
  if [ -n "$extra" ] && grep -rniE "$extra" "${targets[@]}" 2>/dev/null; then
    echo "FAIL hygiene: denylisted term found above"; fail=1
  fi
fi

[ $fail -eq 0 ] && echo "OK: $(ls "$dir"/*.md | wc -l) agent files pass"
exit $fail
