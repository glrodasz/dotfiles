#!/bin/sh
# Context injected into the team-reviewer skill.
#   context.sh rules  — the learned top-15 rules (or a hint to seed them)
#   context.sh diff   — the current branch diff against the default branch, capped
store="$(dirname "$0")/../.review-harvest"
max_bytes=150000

case "$1" in
  rules)
    if [ -s "$store/top-rules.md" ]; then
      cat "$store/top-rules.md"
    else
      echo "_No learned rules on this computer yet — run /harvest-reviews 90d in the team repo._"
    fi
    ;;
  diff)
    base=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
    if [ -z "$base" ]; then
      for b in origin/main origin/master main master; do
        if git rev-parse -q --verify "$b" >/dev/null 2>&1; then base=$b; break; fi
      done
    fi
    if [ -z "$base" ]; then
      echo "_Not a git repo, or no main/master branch found._"
      exit 0
    fi
    echo "Base: \`$base...HEAD\`"
    echo
    echo '```'
    git diff --stat "$base...HEAD"
    echo '```'
    echo
    echo '```diff'
    git diff "$base...HEAD" | head -c "$max_bytes"
    echo '```'
    size=$(git diff "$base...HEAD" | wc -c | tr -d ' ')
    if [ "$size" -gt "$max_bytes" ]; then
      echo "_Diff truncated at ${max_bytes} of ${size} bytes — read the rest with git diff per file._"
    fi
    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
      echo "_Uncommitted changes exist and are not shown — include them with \`git diff HEAD\`._"
    fi
    ;;
esac
