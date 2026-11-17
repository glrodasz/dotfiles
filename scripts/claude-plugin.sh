#!/usr/bin/env bash
# Packs the skills listed in skills/claude-plugin-skills.yaml into a Claude plugin zip.
#
#   claude-plugin.sh version   print the next version and what changed
#   claude-plugin.sh build     write dist/<name>-<version>.zip from the committed HEAD
#   claude-plugin.sh release   build, then publish it as a GitHub release tagged claude-plugin-v<version>
#
# The git tag is the only place the version lives. The next one comes from what changed
# in the listed skills since the last tag: a skill removed from the list bumps major, a
# skill added bumps minor, any other change to a listed skill or the manifest bumps patch.
# Only committed files are packed, so gitignored data (.review-harvest, .DS_Store) never ships.
set -euo pipefail

cd "$(dirname "$0")/.."

MANIFEST=skills/claude-plugin-skills.yaml
TAG_PREFIX=claude-plugin-v
DIST=dist

die() { echo "error: $*" >&2; exit 1; }

command -v yq >/dev/null || die "yq is required (brew install yq)"
git cat-file -e "HEAD:$MANIFEST" 2>/dev/null || die "$MANIFEST is not committed"

skills_at() { git show "$1:$MANIFEST" | yq -r '.skills[]' | sort; }

last_tag=$(git describe --tags --abbrev=0 --match "${TAG_PREFIX}[0-9]*" HEAD 2>/dev/null || true)
current=${last_tag#"$TAG_PREFIX"}
new_skills=$(skills_at HEAD)

for s in $new_skills; do
	git cat-file -e "HEAD:skills/$s/SKILL.md" 2>/dev/null || die "skills/$s/SKILL.md is not committed"
done

if [[ -z "$last_tag" ]]; then
	added=$new_skills removed="" changed="" bump=initial
else
	old_skills=$(skills_at "$last_tag")
	added=$(comm -13 <(echo "$old_skills") <(echo "$new_skills"))
	removed=$(comm -23 <(echo "$old_skills") <(echo "$new_skills"))
	changed=""
	for s in $(comm -12 <(echo "$old_skills") <(echo "$new_skills")); do
		git diff --quiet "$last_tag" HEAD -- "skills/$s" || changed+="$s"$'\n'
	done
	if [[ -n "$removed" ]]; then bump=major
	elif [[ -n "$added" ]]; then bump=minor
	elif [[ -n "$changed" ]] || ! git diff --quiet "$last_tag" HEAD -- "$MANIFEST"; then bump=patch
	else bump=none
	fi
fi

IFS=. read -r major minor patch <<<"${current:-0.0.0}"
case $bump in
	initial) version=1.0.0 ;;
	major) version=$((major + 1)).0.0 ;;
	minor) version=$major.$((minor + 1)).0 ;;
	patch) version=$major.$minor.$((patch + 1)) ;;
	none) version=$current ;;
esac

name=$(yq -r '.name' "$MANIFEST")
zip_path="$DIST/$name-$version.zip"

# Markdown list of what changed since the last tag; also the release notes.
summary() {
	local title list
	for title in Added Removed Changed; do
		case $title in
			Added) list=$added ;;
			Removed) list=$removed ;;
			Changed) list=$changed ;;
		esac
		[[ -z "${list//[[:space:]]/}" ]] && continue
		echo "### $title"
		echo "$list" | sed '/^$/d; s/^/- /'
		echo
	done
}

print_version() {
	if [[ $bump == none ]]; then
		echo "$version (no changes since $last_tag)"
	else
		echo "${current:-none} -> $version ($bump)"
		echo
		summary
	fi
}

build() {
	stage=$(mktemp -d)
	trap 'rm -rf "$stage"' EXIT

	mkdir -p "$stage/.claude-plugin" "$DIST"
	git show "HEAD:$MANIFEST" | VERSION=$version yq -o=json \
		'{"name": .name, "version": strenv(VERSION), "description": .description, "author": .author, "homepage": .homepage}' \
		>"$stage/.claude-plugin/plugin.json"
	for s in $new_skills; do
		git archive HEAD "skills/$s" | tar -x -C "$stage"
	done

	rm -f "$zip_path"
	(cd "$stage" && zip -qr - .claude-plugin skills) >"$zip_path"

	if ! git diff --quiet HEAD -- "$MANIFEST" $(printf 'skills/%s ' $new_skills) ||
		[[ -n "$(git ls-files -o --exclude-standard -- $(printf 'skills/%s ' $new_skills))" ]]; then
		echo "warning: uncommitted changes in the listed skills are not in the zip" >&2
	fi
	echo "packed $zip_path ($(echo "$new_skills" | wc -l | tr -d ' ') skills)"
}

release() {
	if [[ $bump == none ]]; then
		echo "nothing to release: no changes since $last_tag"
		return
	fi
	command -v gh >/dev/null || die "gh is required"
	[[ -n "$(git branch -r --contains HEAD)" ]] || die "HEAD is not pushed; push it first"

	build
	gh release create "$TAG_PREFIX$version" "$zip_path" \
		--target "$(git rev-parse HEAD)" \
		--title "Claude plugin $version" \
		--notes "$(summary)"
}

case "${1:-}" in
	version) print_version ;;
	build) build ;;
	release) release ;;
	*) die "usage: $0 version|build|release" ;;
esac
