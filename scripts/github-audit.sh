#!/usr/bin/env bash
# Inventario de repos (públicos + privados) para auditoría de portfolio.
# Requiere: gh (autenticado con acceso a repos privados) y jq.
# Uso: github-audit.sh [owner] [since]
#   owner  usuario u org de GitHub (por defecto: el usuario autenticado en gh)
#   since  detalle sólo para repos con push desde esta fecha (por defecto: hace 5 años)
set -uo pipefail

OWNER="${1:-$(gh api user --jq .login)}"
SINCE="${2:-$(date -v-5y +%F 2>/dev/null || date -d '5 years ago' +%F)}"
OUT="$(dirname "$0")/github-audit"   # ignorado por git: contiene info de repos privados
mkdir -p "$OUT"

# 1. Metadata de todos los repos
gh repo list "$OWNER" --limit 300 \
  --json name,visibility,isFork,isArchived,description,pushedAt,createdAt,stargazerCount,forkCount,primaryLanguage,languages,repositoryTopics,diskUsage,licenseInfo \
  > "$OUT/repos.json"

echo "Repos: $(jq length "$OUT/repos.json")"

# 2. Detalle de repos propios (no forks) activos desde $SINCE
: > "$OUT/details.md"
jq -r --arg since "$SINCE" \
  '.[] | select(.isFork | not) | select(.pushedAt >= $since) | .name' "$OUT/repos.json" |
while read -r repo; do
  echo "→ $repo"
  branch=$(gh api "repos/$OWNER/$repo" --jq .default_branch 2>/dev/null)
  {
    echo "## $repo"
    echo
    echo "### Estructura (2 niveles)"
    gh api "repos/$OWNER/$repo/git/trees/$branch?recursive=1" --jq '.tree[].path' \
      | awk -F/ 'NF<=2' | grep -vE 'node_modules|dist/|build/|\.lock$' | head -80
    echo
    echo "### Últimos commits"
    gh api "repos/$OWNER/$repo/commits?per_page=8" \
      --jq '.[] | "\(.commit.author.date[:10]) \(.commit.message | split("\n")[0])"'
    echo
    echo "### README (primeras 60 líneas)"
    gh api -H 'Accept: application/vnd.github.raw' "repos/$OWNER/$repo/readme" | head -60
    echo
    echo "---"
    echo
  } >> "$OUT/details.md" 2>/dev/null
done

echo "Listo: $OUT/repos.json y $OUT/details.md"
