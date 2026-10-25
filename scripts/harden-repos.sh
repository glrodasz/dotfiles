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
#   Rename default branch master -> main         ✓       ✓       ✓
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
#   Move classic branch protection to rulesets   ✓       ✓       ✓
#
# The rename only runs when the default branch is "master" and no "main" exists yet.
# GitHub retargets open PRs, updates classic rules naming the branch and redirects old
# URLs. Workflow files aren't rewritten, so any that still mention "master" are
# listed, and the commands to update local clones are printed at the end.
#
# Each classic rule (any pattern, wildcards included) becomes a ruleset named
# "classic-<pattern>" with the same rules and admin enforcement, and the classic rule
# is deleted only after that ruleset applies. Rules using settings rulesets can't
# express for a personal repo (push/dismissal restrictions, per-actor bypass
# allowances) are reported and left in place. Skip the migration with --keep-classic.
#
# Rulesets (and classic protection) on private repos need GitHub Pro (personal) or
# Team (org). On Free, the ruleset step is skipped, the rest still applies, and the
# unprotected repos are listed at the end.
#
# --dry-run reads each setting first and marks the step "= already set", "~ would change"
# or "? current state unknown", then sums up the changes at the end.
#
# Requirements: gh (logged in as the repo owner), jq
# Usage:
#   ./harden-repos.sh --dry-run                        # preview, public repos
#   ./harden-repos.sh                                  # apply to public repos
#   ./harden-repos.sh --private                        # public + private (light)
#   ./harden-repos.sh --private=strict                 # public + private (strict)
#   ./harden-repos.sh --private=strict my-team-repo    # specific repos only
#   ./harden-repos.sh --keep-classic                   # don't migrate classic protection

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

# Current ruleset (input) already enforces the wanted one ($want[0]). Rule parameters the
# API fills in with defaults are ignored.
cat > "$TMP/ruleset-matches.jq" <<'JQ'
def by_type: map({key: .type, value: (.parameters // {})}) | from_entries;
$want[0] as $w
| (.rules | by_type) as $have
| ($w.rules | by_type) as $need
| .enforcement == $w.enforcement
  and .conditions.ref_name == $w.conditions.ref_name
  and ([(.bypass_actors // [])[] | {actor_id, actor_type, bypass_mode}] == $w.bypass_actors)
  and ($have | keys) == ($need | keys)
  and all($need | to_entries[]; .key as $t | all(.value | to_entries[]; $have[$t][.key] == .value))
JQ

FAILURES=0
DRY_CHANGES=0
DRY_ALREADY_SET=0
DRY_UNKNOWN=0
PRIVATE_RULESETS_UNSUPPORTED=false
UNPROTECTED=()
RENAMED=()

fail_msg() { head -c 200 "$TMP/err" | tr '\n' ' '; }

# dry_run_line "<label>" <set|change|"">
dry_run_line() {
  case "$2" in
    set)    echo "  = $1 (already set)"; DRY_ALREADY_SET=$((DRY_ALREADY_SET + 1)) ;;
    change) echo "  ~ $1"; DRY_CHANGES=$((DRY_CHANGES + 1)) ;;
    *)      echo "  ? $1 (current state unknown)"; DRY_UNKNOWN=$((DRY_UNKNOWN + 1)) ;;
  esac
}

# Dry run only, prints the state of a setting: "set" when the jq filter holds for its
# current value, "change" when it doesn't, nothing when that can't be read.
#   state_from <json> <jq-filter>
#   state <jq-filter> gh-api-args...
state_from() {
  if echo "$1" | jq -e "$2" >/dev/null 2>&1; then echo set; else echo change; fi
}
state() {
  $DRY_RUN || return 0
  local filter="$1" json; shift
  json="$(gh api "$@" 2>/dev/null)" || return 0
  state_from "$json" "$filter"
}

# ruleset_state <ruleset-path> <wanted-ruleset-file>
ruleset_state() {
  $DRY_RUN || return 0
  local json
  json="$(gh api "$1" 2>/dev/null)" || return 0
  if echo "$json" | jq -e --slurpfile want "$2" -f "$TMP/ruleset-matches.jq" >/dev/null 2>&1; then
    echo set
  else
    echo change
  fi
}

# Dependabot alerts answer 204 when enabled and 404 when disabled
dependabot_alerts_state() {
  $DRY_RUN || return 0
  if gh api "$1/vulnerability-alerts" >/dev/null 2>"$TMP/err"; then
    echo set
  elif grep -q "HTTP 404" "$TMP/err"; then
    echo change
  fi
}

# [STATE=<set|change>] step "<label>" gh-api-args...   Returns non-zero on failure.
step() {
  local label="$1"; shift
  if $DRY_RUN; then
    dry_run_line "$label" "${STATE:-}"
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

# Classic rule (GraphQL node) -> equivalent ruleset. Admins bypass unless the rule
# was enforced for them too.
cat > "$TMP/classic-to-ruleset.jq" <<'JQ'
def rules: [
  if .allowsDeletions | not then {type: "deletion"} else empty end,
  if .allowsForcePushes | not then {type: "non_fast_forward"} else empty end,
  if .requiresLinearHistory then {type: "required_linear_history"} else empty end,
  if .requiresCommitSignatures then {type: "required_signatures"} else empty end,
  if .lockBranch then {type: "update",
    parameters: {update_allows_fetch_and_merge: .lockAllowsFetchAndMerge}} else empty end,
  if .requiresApprovingReviews then {type: "pull_request", parameters: {
    required_approving_review_count: (.requiredApprovingReviewCount // 0),
    dismiss_stale_reviews_on_push: .dismissesStaleReviews,
    require_code_owner_review: .requiresCodeOwnerReviews,
    require_last_push_approval: .requireLastPushApproval,
    required_review_thread_resolution: .requiresConversationResolution}} else empty end,
  if .requiresStatusChecks and (.requiredStatusChecks | length > 0) then
    {type: "required_status_checks", parameters: {
      strict_required_status_checks_policy: .requiresStrictStatusChecks,
      required_status_checks: [.requiredStatusChecks[]
        | {context} + (if .app then {integration_id: .app.databaseId} else {} end)]}}
  else empty end,
  if .requiresDeployments and (.requiredDeploymentEnvironments | length > 0) then
    {type: "required_deployments",
     parameters: {required_deployment_environments: .requiredDeploymentEnvironments}}
  else empty end
];
{
  name: ("classic-" + .pattern),
  target: "branch",
  enforcement: "active",
  conditions: {ref_name: {include: ["refs/heads/" + .pattern], exclude: []}},
  bypass_actors: (if .isAdminEnforced then []
    else [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always"}] end),
  rules: rules
}
JQ

# Settings with no ruleset equivalent on a personal repo; a rule using any of them is left alone
cat > "$TMP/classic-unsupported.jq" <<'JQ'
[
  if .restrictsPushes then "push restrictions" else empty end,
  if .restrictsReviewDismissals then "review dismissal restrictions" else empty end,
  if .bypassPullRequestAllowances.totalCount > 0 then "PR bypass allowances" else empty end,
  if .bypassForcePushAllowances.totalCount > 0 then "force push allowances" else empty end,
  if .requiresConversationResolution and (.requiresApprovingReviews | not)
    then "conversation resolution without required PRs" else empty end
] | join(", ")
JQ

# ruleset_id <repo-path> <name>   Prints the id of the ruleset with that name, if any.
# gh prints the error body to stdout on failure, so only trust output on success.
ruleset_id() {
  local json
  json="$(gh api "$1/rulesets" 2>/dev/null)" || return 0
  echo "$json" | jq -r --arg n "$2" '.[] | select(.name == $n) | .id' | head -n1
}

# rulesets_need_upgrade <repo-path>   True when the plan has no rulesets for this repo
# (GitHub Free, private repo), so dry runs see what the real run will hit.
rulesets_need_upgrade() {
  gh api "$1/rulesets" >/dev/null 2>"$TMP/err" && return 1
  grep -qi "upgrade" "$TMP/err"
}

# rename_default_branch <repo>   master -> main, then flag workflows still naming master
rename_default_branch() {
  local repo="$1" R="repos/$OWNER/$1" files f
  if gh api "$R/branches/main" >/dev/null 2>&1; then
    echo "  ! Both 'master' and 'main' exist — default branch not renamed, review manually"
    return
  fi
  STATE=change step "Rename default branch 'master' → 'main'" -X POST "$R/branches/master/rename" \
    -f new_name=main || return
  RENAMED+=("$repo")

  # gh prints the error body to stdout on failure (404 = no workflows), so only trust success
  files="$(gh api "$R/contents/.github/workflows" -q '.[] | select(.type == "file") | .path' \
    2>/dev/null)" || return
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if gh api -H "Accept: application/vnd.github.raw+json" "$R/contents/$f" 2>/dev/null \
        | grep -qw master; then
      echo "  ! $f still mentions 'master' — update it to 'main'"
    fi
  done <<< "$files"
}

# Move every classic protection rule of the repo into an equivalent ruleset
migrate_classic_protection() {
  local repo="$1" R="repos/$OWNER/$1" data
  if ! data="$(gh api graphql \
      -f query='query($o:String!,$r:String!){repository(owner:$o,name:$r){
        branchProtectionRules(first:100){nodes{
          id pattern isAdminEnforced allowsForcePushes allowsDeletions
          requiresLinearHistory requiresCommitSignatures lockBranch lockAllowsFetchAndMerge
          requiresApprovingReviews requiredApprovingReviewCount dismissesStaleReviews
          requiresCodeOwnerReviews requireLastPushApproval requiresConversationResolution
          requiresStatusChecks requiresStrictStatusChecks requiredStatusChecks{context app{databaseId}}
          requiresDeployments requiredDeploymentEnvironments
          restrictsPushes restrictsReviewDismissals
          bypassPullRequestAllowances(first:1){totalCount}
          bypassForcePushAllowances(first:1){totalCount}}}}}' \
      -f o="$OWNER" -f r="$repo" 2>"$TMP/err")"; then
    echo "  ✗ Read classic branch protection — $(fail_msg)"
    FAILURES=$((FAILURES + 1))
    return
  fi

  local found=false node id pattern unsupported name rule_types bypass existing_id label args current
  while IFS= read -r node; do
    [ -z "$node" ] && continue
    found=true
    id="$(echo "$node" | jq -r .id)"
    pattern="$(echo "$node" | jq -r .pattern)"

    unsupported="$(echo "$node" | jq -r -f "$TMP/classic-unsupported.jq")"
    if [ -n "$unsupported" ]; then
      echo "  ! Classic rule '$pattern' uses $unsupported — not migrated, review manually"
      continue
    fi

    echo "$node" | jq -f "$TMP/classic-to-ruleset.jq" > "$TMP/classic-ruleset.json"
    name="$(jq -r .name "$TMP/classic-ruleset.json")"
    rule_types="$(jq -r '[.rules[].type] | join(", ")' "$TMP/classic-ruleset.json")"
    bypass="$(jq -r 'if .bypass_actors == [] then "applies to admins" else "admins can bypass" end' \
      "$TMP/classic-ruleset.json")"

    # A classic rule that allows everything protects nothing, so there's nothing to move
    if [ -n "$rule_types" ]; then
      existing_id="$(ruleset_id "$R" "$name")"
      if [ -n "$existing_id" ]; then
        label="Update ruleset '$name' from classic rule ($rule_types; $bypass)"
        args=(-X PUT "$R/rulesets/$existing_id")
        current="$(ruleset_state "$R/rulesets/$existing_id" "$TMP/classic-ruleset.json")"
      else
        label="Create ruleset '$name' from classic rule ($rule_types; $bypass)"
        args=(-X POST "$R/rulesets")
        current=change
      fi
      STATE="$current" step "$label" "${args[@]}" --input "$TMP/classic-ruleset.json" || {
        echo "  ! Classic rule '$pattern' left in place so its branches stay protected"
        continue
      }
    fi

    STATE=change step "Delete classic protection rule '$pattern'" graphql \
      -f query='mutation($id:ID!){deleteBranchProtectionRule(input:{branchProtectionRuleId:$id}){clientMutationId}}' \
      -f id="$id"
  done < <(echo "$data" | jq -c '.data.repository.branchProtectionRules.nodes[]')

  $found || echo "  - No classic branch protection"
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

  # Default branch name (before the rulesets, so migrated classic rules already say "main")
  if [ "$(echo "$info" | jq -r '.default_branch')" = master ] \
      && gh api "$R/branches/master" >/dev/null 2>&1; then
    rename_default_branch "$repo"
  fi

  # Merge settings
  if [ "$profile" != private-light ]; then
    STATE="$(state '.allow_squash_merge and (.allow_merge_commit | not)
        and (.allow_rebase_merge | not) and .delete_branch_on_merge' "$R")" \
    step "Squash-only merging, auto-delete branches" -X PATCH "$R" \
      -F allow_squash_merge=true -F allow_merge_commit=false \
      -F allow_rebase_merge=false -F delete_branch_on_merge=true
  fi

  # Security
  STATE="$(dependabot_alerts_state "$R")" \
    step "Dependabot alerts" -X PUT "$R/vulnerability-alerts"
  STATE="$(state '.enabled' "$R/automated-security-fixes")" \
    step "Dependabot security updates" -X PUT "$R/automated-security-fixes"
  if [ "$profile" = public ]; then
    STATE="$(state '.enabled' "$R/private-vulnerability-reporting")" \
      step "Private vulnerability reporting" -X PUT "$R/private-vulnerability-reporting"
    STATE="$($DRY_RUN && state_from "$info" '.security_and_analysis
        | .secret_scanning.status == "enabled" and .secret_scanning_push_protection.status == "enabled"')" \
      step "Secret scanning + push protection" -X PATCH "$R" --input "$TMP/security.json"
  fi

  # Actions
  STATE="$(state '.default_workflow_permissions == "read" and (.can_approve_pull_request_reviews | not)' \
      "$R/actions/permissions/workflow")" \
  step "Read-only GITHUB_TOKEN, no PR approvals by Actions" \
    -X PUT "$R/actions/permissions/workflow" \
    -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
  if [ "$profile" = public ]; then
    STATE="$(state '.approval_policy == "all_external_contributors"' \
        "$R/actions/permissions/fork-pr-contributor-approval")" \
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
  ruleset_unsupported=false
  if [ "$profile" != public ] \
      && { $PRIVATE_RULESETS_UNSUPPORTED || rulesets_need_upgrade "$R"; }; then
    PRIVATE_RULESETS_UNSUPPORTED=true
    ruleset_unsupported=true
  else
    existing_id="$(ruleset_id "$R" "$RULESET_NAME")"
    if [ -n "$existing_id" ]; then
      label="Update ruleset '$RULESET_NAME' ($ruleset_desc)"; ruleset_args=(-X PUT "$R/rulesets/$existing_id")
      current="$(ruleset_state "$R/rulesets/$existing_id" "$ruleset_file")"
    else
      label="Create ruleset '$RULESET_NAME' ($ruleset_desc)"; ruleset_args=(-X POST "$R/rulesets")
      current=change
    fi
    if $DRY_RUN; then
      dry_run_line "$label" "$current"
    elif gh api "${ruleset_args[@]}" --input "$ruleset_file" >/dev/null 2>"$TMP/err"; then
      echo "  ✓ $label"
    elif [ "$profile" != public ] && grep -qi "upgrade" "$TMP/err"; then
      # Free plan: remember it so the remaining private repos don't retry
      PRIVATE_RULESETS_UNSUPPORTED=true
      ruleset_unsupported=true
    else
      echo "  ✗ $label — $(fail_msg)"
      FAILURES=$((FAILURES + 1))
    fi
  fi

  # Classic protection: each rule is deleted only once its replacement ruleset is in place
  if $ruleset_unsupported; then
    # Free has no branch protection of any kind (ruleset or classic) on private repos
    echo "  - Ruleset skipped — branch protection on private repos needs GitHub Pro"
    UNPROTECTED+=("$repo")
  elif $KEEP_CLASSIC; then
    echo "  - Keeping classic branch protection (--keep-classic)"
  else
    migrate_classic_protection "$repo"
  fi
done

echo ""
if [ ${#RENAMED[@]} -gt 0 ]; then
  renamed="renamed"; $DRY_RUN && renamed="would be renamed"
  echo "! ${#RENAMED[@]} repo(s) $renamed 'master' → 'main': ${RENAMED[*]}"
  echo "  In each local clone, run:"
  echo "    git branch -m master main && git fetch origin && git branch -u origin/main main && git remote set-head origin -a"
fi
if [ ${#UNPROTECTED[@]} -gt 0 ]; then
  echo "! ${#UNPROTECTED[@]} private repo(s) have an unprotected default branch (needs GitHub Pro):"
  echo "  ${UNPROTECTED[*]}"
fi
if $DRY_RUN; then
  echo "Dry run: $DRY_CHANGES change(s), $DRY_ALREADY_SET already set, $DRY_UNKNOWN unknown."
fi
if [ "$FAILURES" -gt 0 ]; then
  echo "Done with $FAILURES failed step(s). Review the ✗ lines above."
  exit 1
fi
echo "Done."
