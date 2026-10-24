#!/usr/bin/env bash
# Apply a baseline of safe contribution settings to your repos.
#
# Profiles (picked per repo from its visibility):
#   public          Full profile. Always applied to public repos.
#   private light   --private (or --private=light). For solo private repos.
#   private strict  --private=strict. For private repos with collaborators.
#   Private repos are skipped unless --private is passed.
#
# What each profile sets:
#                                              public  strict  light
#   Ruleset: PR + 1 approval, stale dismissal,   ✓       ✓       -
#     code owners, last-push approval,
#     conversation resolution, squash only,
#     linear history (admins can bypass)
#   Ruleset: block force push + deletion         ✓       ✓       ✓ (no bypass, even for you)
#   Squash-only merging, auto-delete branches    ✓       ✓       -
#   Dependabot alerts + security updates         ✓       ✓       ✓
#   Read-only GITHUB_TOKEN, Actions can't        ✓       ✓       ✓
#     approve PRs
#   Private vulnerability reporting              ✓       -       -   (public repos only)
#   Secret scanning + push protection            ✓       -       -   (not included on personal private repos)
#   Fork PR workflows need approval              ✓       -       -   (public repos only)
#   Delete classic rule on default branch        ✓       ✓       -   (light is weaker, so classic is kept)
#
# Classic rule removal only happens after the ruleset applies successfully, and only
# for a rule whose pattern is exactly the default branch name. Wildcard rules
# (e.g. "*", "ma*") are reported, not deleted. Skip removal with --keep-classic.
#
# Rulesets (and classic protection) on private repos need GitHub Pro (personal) or
# Team (org). On Free, the ruleset step is skipped, the rest still applies, and the
# unprotected repos are listed at the end.
#
# Requirements: gh (logged in as the repo owner), jq
# Usage:
#   ./harden-repos.sh --dry-run                        # preview, public repos
#   ./harden-repos.sh                                  # apply to public repos
#   ./harden-repos.sh --private                        # public + private (light)
#   ./harden-repos.sh --private=strict                 # public + private (strict)
#   ./harden-repos.sh --private=strict my-team-repo    # specific repos only
#   ./harden-repos.sh --keep-classic                   # don't touch classic protection

set -uo pipefail

OWNER="${OWNER:-glrodasz}"
RULESET_NAME="protect-default-branch"
DRY_RUN=false
KEEP_CLASSIC=false
PRIVATE_MODE=none   # none | light | strict
REPOS=()

usage() { awk 'NR>1 && /^#/{sub(/^# ?/,""); print; next} NR>1{exit}' "$0"; }

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --keep-classic) KEEP_CLASSIC=true ;;
    --private|--private=light) PRIVATE_MODE=light ;;
    --private=strict) PRIVATE_MODE=strict ;;
    --private=*) echo "Unknown --private value: ${arg#*=} (use light or strict)"; exit 1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $arg"; usage; exit 1 ;;
    *) REPOS+=("$arg") ;;
  esac
done

command -v gh >/dev/null || { echo "gh CLI not found"; exit 1; }
command -v jq >/dev/null || { echo "jq not found"; exit 1; }

# Non-fork, non-archived repos; private ones only with --private
# (macOS bash 3.2 compatible: no mapfile)
if [ ${#REPOS[@]} -eq 0 ]; then
  visibility_args=(--visibility public)
  [ "$PRIVATE_MODE" != none ] && visibility_args=()
  while IFS= read -r name; do
    [ -n "$name" ] && REPOS+=("$name")
  done < <(gh repo list "$OWNER" --source --no-archived ${visibility_args[@]+"${visibility_args[@]}"} \
             --limit 1000 --json name -q '.[].name')
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Full ruleset: public + private strict. Repo admins can bypass.
cat > "$TMP/ruleset-full.json" <<JSON
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [
    { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }
  ],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    }
  ]
}
JSON

# Light ruleset: private light. No bypass, so it also guards against your own
# accidental force-push (disable the ruleset temporarily if you really need one).
cat > "$TMP/ruleset-light.json" <<JSON
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" }
  ]
}
JSON

cat > "$TMP/security.json" <<'JSON'
{
  "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}
JSON

FAILURES=0
PRIVATE_RULESETS_UNSUPPORTED=false
UNPROTECTED=()

fail_msg() { head -c 200 "$TMP/err" | tr '\n' ' '; }

# step "<label>" gh-api-args...   Returns non-zero on failure.
step() {
  local label="$1"; shift
  if $DRY_RUN; then
    echo "  [dry-run] $label"
    return 0
  fi
  if gh api "$@" >/dev/null 2>"$TMP/err"; then
    echo "  ✓ $label"
    return 0
  else
    echo "  ✗ $label — $(fail_msg)"
    FAILURES=$((FAILURES + 1))
    return 1
  fi
}

# Remove the classic protection rule for the default branch (exact-pattern match only)
remove_classic_protection() {
  local repo="$1" data default
  if ! data="$(gh api graphql \
      -f query='query($o:String!,$r:String!){repository(owner:$o,name:$r){
        defaultBranchRef{name} branchProtectionRules(first:100){nodes{id pattern}}}}' \
      -f o="$OWNER" -f r="$repo" 2>"$TMP/err")"; then
    echo "  ✗ Read classic branch protection — $(fail_msg)"
    FAILURES=$((FAILURES + 1))
    return
  fi

  default="$(echo "$data" | jq -r '.data.repository.defaultBranchRef.name // empty')"
  [ -z "$default" ] && { echo "  - No default branch (empty repo), skipping classic check"; return; }

  local found=false id pattern
  while IFS=$'\t' read -r id pattern; do
    [ -z "$id" ] && continue
    if [ "$pattern" = "$default" ]; then
      found=true
      if $DRY_RUN; then
        echo "  [dry-run] Delete classic protection rule '$pattern'"
      elif gh api graphql \
          -f query='mutation($id:ID!){deleteBranchProtectionRule(input:{branchProtectionRuleId:$id}){clientMutationId}}' \
          -f id="$id" >/dev/null 2>"$TMP/err"; then
        echo "  ✓ Deleted classic protection rule '$pattern'"
      else
        echo "  ✗ Delete classic protection rule '$pattern' — $(fail_msg)"
        FAILURES=$((FAILURES + 1))
      fi
    # shellcheck disable=SC2053  # intentional glob match against the rule pattern
    elif [[ "$default" == $pattern ]]; then
      found=true
      echo "  ! Wildcard classic rule '$pattern' also covers '$default' — left in place, review manually"
    fi
  done < <(echo "$data" | jq -r '.data.repository.branchProtectionRules.nodes[] | [.id, .pattern] | @tsv')

  $found || echo "  - No classic protection on '$default'"
}

echo "Owner: $OWNER | Repos: ${#REPOS[@]} | Private mode: $PRIVATE_MODE | Dry run: $DRY_RUN"

for repo in "${REPOS[@]}"; do
  R="repos/$OWNER/$repo"
  echo ""

  # Visibility decides the profile
  if ! info="$(gh api "$R" 2>"$TMP/err")"; then
    echo "▶ $OWNER/$repo"
    echo "  ✗ Read repo info — $(fail_msg)"
    FAILURES=$((FAILURES + 1))
    continue
  fi
  if [ "$(echo "$info" | jq -r '.private')" = "true" ]; then
    if [ "$PRIVATE_MODE" = none ]; then
      echo "▶ $OWNER/$repo [private] — skipped (pass --private to include)"
      continue
    fi
    profile="private-$PRIVATE_MODE"
  else
    profile="public"
  fi
  echo "▶ $OWNER/$repo [$profile]"

  # Merge settings
  if [ "$profile" != private-light ]; then
    step "Squash-only merging, auto-delete branches" -X PATCH "$R" \
      -F allow_squash_merge=true -F allow_merge_commit=false \
      -F allow_rebase_merge=false -F delete_branch_on_merge=true
  fi

  # Security
  step "Dependabot alerts"           -X PUT "$R/vulnerability-alerts"
  step "Dependabot security updates" -X PUT "$R/automated-security-fixes"
  if [ "$profile" = public ]; then
    step "Private vulnerability reporting"   -X PUT "$R/private-vulnerability-reporting"
    step "Secret scanning + push protection" -X PATCH "$R" --input "$TMP/security.json"
  fi

  # Actions
  step "Read-only GITHUB_TOKEN, no PR approvals by Actions" \
    -X PUT "$R/actions/permissions/workflow" \
    -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
  if [ "$profile" = public ]; then
    step "Fork PR workflows need approval (all external contributors)" \
      -X PUT "$R/actions/permissions/fork-pr-contributor-approval" \
      -f approval_policy=all_external_contributors
  fi

  # Ruleset (create or update by name, so reruns and profile switches are safe)
  if [ "$profile" = private-light ]; then
    ruleset_file="$TMP/ruleset-light.json"; ruleset_desc="force push + deletion only"
  else
    ruleset_file="$TMP/ruleset-full.json";  ruleset_desc="full"
  fi
  ruleset_ok=1
  ruleset_unsupported=false
  if [ "$profile" != public ] && $PRIVATE_RULESETS_UNSUPPORTED; then
    ruleset_unsupported=true
  else
    # gh prints the error body to stdout on failure, so only trust output on success
    existing_id=""
    if rulesets_json="$(gh api "$R/rulesets" 2>/dev/null)"; then
      existing_id="$(echo "$rulesets_json" | jq -r --arg n "$RULESET_NAME" \
        '.[] | select(.name == $n) | .id' | head -n1)"
    fi
    if [ -n "$existing_id" ]; then
      label="Update ruleset '$RULESET_NAME' ($ruleset_desc)"; ruleset_args=(-X PUT "$R/rulesets/$existing_id")
    else
      label="Create ruleset '$RULESET_NAME' ($ruleset_desc)"; ruleset_args=(-X POST "$R/rulesets")
    fi
    if $DRY_RUN; then
      echo "  [dry-run] $label"
      ruleset_ok=0
    elif gh api "${ruleset_args[@]}" --input "$ruleset_file" >/dev/null 2>"$TMP/err"; then
      echo "  ✓ $label"
      ruleset_ok=0
    elif [ "$profile" != public ] && grep -qi "upgrade" "$TMP/err"; then
      # Free plan: remember it so the remaining private repos don't retry
      PRIVATE_RULESETS_UNSUPPORTED=true
      ruleset_unsupported=true
    else
      echo "  ✗ $label — $(fail_msg)"
      FAILURES=$((FAILURES + 1))
    fi
  fi

  # Classic protection: only remove once the ruleset is in place
  if $ruleset_unsupported; then
    # Free has no branch protection of any kind (ruleset or classic) on private repos
    echo "  - Ruleset skipped — branch protection on private repos needs GitHub Pro"
    UNPROTECTED+=("$repo")
  elif $KEEP_CLASSIC; then
    echo "  - Keeping classic branch protection (--keep-classic)"
  elif [ "$profile" = private-light ]; then
    echo "  - Light profile: classic protection kept (it may be stricter)"
  elif [ "$ruleset_ok" -ne 0 ]; then
    echo "  ! Ruleset failed — classic protection left in place so the branch stays protected"
  else
    remove_classic_protection "$repo"
  fi
done

echo ""
if [ ${#UNPROTECTED[@]} -gt 0 ]; then
  echo "! ${#UNPROTECTED[@]} private repo(s) have an unprotected default branch (needs GitHub Pro):"
  echo "  ${UNPROTECTED[*]}"
fi
if [ "$FAILURES" -gt 0 ]; then
  echo "Done with $FAILURES failed step(s). Review the ✗ lines above."
  exit 1
fi
echo "Done."
