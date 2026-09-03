#!/usr/bin/env python3
"""Safety helper for rebuilding a Git branch into reviewable commits.

The helper deliberately does not decide how commits should be grouped. It only:

1. Captures the complete desired worktree in a backup commit/branch.
2. Mixed-resets the current branch to its merge base so the final state can be
   recommitted.
3. Verifies that the rebuilt HEAD exactly matches the captured final tree.

No third-party Python packages are required.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Mapping, Sequence

SCRIPT_VERSION = 1
PROTECTED_BRANCH_NAMES = {"main", "master", "trunk"}
IN_PROGRESS_GIT_PATHS = (
    "MERGE_HEAD",
    "CHERRY_PICK_HEAD",
    "REVERT_HEAD",
    "BISECT_LOG",
    "rebase-merge",
    "rebase-apply",
    "sequencer",
)
DISALLOWED_SUBJECT_RE = re.compile(r"^(?:fixup!|squash!|amend!|wip\b)", re.IGNORECASE)


class ReviewableCommitsError(RuntimeError):
    """Raised for an unsafe or invalid repository state."""


@dataclass(frozen=True)
class GitResult:
    stdout: str
    stderr: str
    returncode: int


def run_git(
    args: Sequence[str],
    *,
    cwd: Path,
    env: Mapping[str, str] | None = None,
    input_text: str | None = None,
    check: bool = True,
) -> GitResult:
    process_env = os.environ.copy()
    if env:
        process_env.update(env)

    completed = subprocess.run(
        ["git", *args],
        cwd=str(cwd),
        env=process_env,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    result = GitResult(
        stdout=completed.stdout.strip(),
        stderr=completed.stderr.strip(),
        returncode=completed.returncode,
    )
    if check and completed.returncode != 0:
        command = "git " + " ".join(args)
        detail = result.stderr or result.stdout or "unknown Git error"
        raise ReviewableCommitsError(f"{command} failed: {detail}")
    return result


def repo_root_from(cwd: Path) -> Path:
    result = run_git(["rev-parse", "--show-toplevel"], cwd=cwd)
    return Path(result.stdout).resolve()


def absolute_git_dir(repo_root: Path) -> Path:
    absolute = run_git(
        ["rev-parse", "--absolute-git-dir"], cwd=repo_root, check=False
    )
    if absolute.returncode == 0 and absolute.stdout:
        return Path(absolute.stdout).resolve()

    fallback = run_git(["rev-parse", "--git-dir"], cwd=repo_root).stdout
    path = Path(fallback)
    if not path.is_absolute():
        path = repo_root / path
    return path.resolve()


def current_branch(repo_root: Path) -> str:
    result = run_git(
        ["symbolic-ref", "--quiet", "--short", "HEAD"],
        cwd=repo_root,
        check=False,
    )
    if result.returncode != 0 or not result.stdout:
        raise ReviewableCommitsError(
            "HEAD is detached. Check out the intended feature branch before rewriting history."
        )
    return result.stdout


def git_path(repo_root: Path, name: str) -> Path:
    raw = run_git(["rev-parse", "--git-path", name], cwd=repo_root).stdout
    path = Path(raw)
    if not path.is_absolute():
        path = repo_root / path
    return path.resolve()


def assert_safe_repository_state(repo_root: Path) -> None:
    active = [name for name in IN_PROGRESS_GIT_PATHS if git_path(repo_root, name).exists()]
    if active:
        raise ReviewableCommitsError(
            "Git operation in progress: " + ", ".join(active) + ". Finish or abort it first."
        )

    unmerged = run_git(["ls-files", "-u"], cwd=repo_root).stdout
    if unmerged:
        raise ReviewableCommitsError(
            "The index contains unresolved conflicts. Resolve them before rebuilding commits."
        )


def resolve_commit(repo_root: Path, ref: str) -> str:
    result = run_git(
        ["rev-parse", "--verify", f"{ref}^{{commit}}"],
        cwd=repo_root,
        check=False,
    )
    if result.returncode != 0 or not result.stdout:
        raise ReviewableCommitsError(f"Cannot resolve base ref as a commit: {ref}")
    return result.stdout


def normalize_base_branch(repo_root: Path, base_ref: str) -> str:
    normalized = base_ref
    for prefix in ("refs/heads/", "refs/remotes/"):
        if normalized.startswith(prefix):
            normalized = normalized[len(prefix) :]
            break

    remotes = run_git(["remote"], cwd=repo_root, check=False).stdout.splitlines()
    for remote in remotes:
        prefix = f"{remote}/"
        if normalized.startswith(prefix):
            return normalized[len(prefix) :]
    return normalized


def assert_not_base_branch(repo_root: Path, branch: str, base_ref: str) -> None:
    normalized_base = normalize_base_branch(repo_root, base_ref)
    if branch in PROTECTED_BRANCH_NAMES or branch == normalized_base:
        raise ReviewableCommitsError(
            f"Refusing to rewrite branch '{branch}', which appears to be the base or a protected branch."
        )


def merge_base(repo_root: Path, base_commit: str) -> str:
    result = run_git(
        ["merge-base", "HEAD", base_commit], cwd=repo_root, check=False
    )
    if result.returncode != 0 or not result.stdout:
        raise ReviewableCommitsError(
            "No merge base exists between HEAD and the selected base ref."
        )
    return result.stdout


def compute_worktree_tree(repo_root: Path) -> str:
    """Write the current worktree to an isolated index and return its tree ID.

    This captures tracked changes, staged changes, deletions, and untracked
    non-ignored files without touching the repository's real index.
    """

    descriptor, index_name = tempfile.mkstemp(prefix="reviewable-commits-index-")
    os.close(descriptor)
    index_path = Path(index_name)
    index_path.unlink(missing_ok=True)  # Git expects a missing or valid index.

    env = {"GIT_INDEX_FILE": str(index_path)}
    try:
        run_git(["read-tree", "HEAD"], cwd=repo_root, env=env)
        add_result = run_git(
            ["add", "-A", "--", "."], cwd=repo_root, env=env, check=False
        )
        if add_result.returncode != 0:
            sparse_result = run_git(
                ["add", "--sparse", "-A", "--", "."],
                cwd=repo_root,
                env=env,
                check=False,
            )
            if sparse_result.returncode != 0:
                detail = sparse_result.stderr or add_result.stderr
                raise ReviewableCommitsError(
                    "Could not capture the complete worktree in an isolated index: "
                    + (detail or "unknown Git error")
                )
        return run_git(["write-tree"], cwd=repo_root, env=env).stdout
    finally:
        index_path.unlink(missing_ok=True)
        Path(str(index_path) + ".lock").unlink(missing_ok=True)


def tree_for_commit(repo_root: Path, commit: str) -> str:
    return run_git(["rev-parse", f"{commit}^{{tree}}"], cwd=repo_root).stdout


def config_value(repo_root: Path, key: str, fallback: str) -> str:
    result = run_git(["config", "--get", key], cwd=repo_root, check=False)
    return result.stdout if result.returncode == 0 and result.stdout else fallback


def create_snapshot_commit(
    repo_root: Path,
    *,
    desired_tree: str,
    original_head: str,
    branch: str,
    created_at: str,
) -> str:
    author_name = config_value(repo_root, "user.name", "Reviewable Commits Snapshot")
    author_email = config_value(
        repo_root, "user.email", "reviewable-commits-snapshot@local"
    )
    env = {
        "GIT_AUTHOR_NAME": author_name,
        "GIT_AUTHOR_EMAIL": author_email,
        "GIT_COMMITTER_NAME": author_name,
        "GIT_COMMITTER_EMAIL": author_email,
    }
    message = (
        f"Safety snapshot before rebuilding {branch}\n\n"
        f"Original HEAD: {original_head}\n"
        f"Captured at: {created_at}\n"
    )
    return run_git(
        ["commit-tree", desired_tree, "-p", original_head],
        cwd=repo_root,
        env=env,
        input_text=message,
    ).stdout


def safe_branch_component(branch: str) -> str:
    safe = re.sub(r"[^A-Za-z0-9._-]+", "-", branch).strip(".-")
    safe = safe.replace("..", "-")
    return safe or "branch"


def ref_exists(repo_root: Path, full_ref: str) -> bool:
    result = run_git(
        ["show-ref", "--verify", "--quiet", full_ref],
        cwd=repo_root,
        check=False,
    )
    return result.returncode == 0


def choose_backup_branch(repo_root: Path, branch: str, timestamp: str) -> str:
    base_name = (
        f"reviewable-commits-backup/{safe_branch_component(branch)}-{timestamp}"
    )
    candidate = base_name
    counter = 2
    while ref_exists(repo_root, f"refs/heads/{candidate}"):
        candidate = f"{base_name}-{counter}"
        counter += 1
    return candidate


def repository_status(repo_root: Path) -> str:
    return run_git(
        ["status", "--porcelain=v1", "--untracked-files=all"], cwd=repo_root
    ).stdout


def write_json_atomic(path: Path, data: Mapping[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def prepare(args: argparse.Namespace) -> int:
    repo_root = repo_root_from(Path.cwd())
    assert_safe_repository_state(repo_root)
    branch = current_branch(repo_root)
    assert_not_base_branch(repo_root, branch, args.base)

    original_head = resolve_commit(repo_root, "HEAD")
    base_commit = resolve_commit(repo_root, args.base)
    fork_point = merge_base(repo_root, base_commit)
    desired_tree = compute_worktree_tree(repo_root)
    base_tree = tree_for_commit(repo_root, fork_point)
    status_before = repository_status(repo_root)

    if desired_tree == base_tree:
        raise ReviewableCommitsError(
            "The final worktree matches the merge base; there is no final code change to rebuild."
        )

    preview = {
        "action": "prepare",
        "applied": bool(args.apply),
        "base_ref": args.base,
        "base_commit": base_commit,
        "branch": branch,
        "desired_tree": desired_tree,
        "merge_base": fork_point,
        "original_head": original_head,
        "repo_root": str(repo_root),
        "status_before": status_before,
    }

    if not args.apply:
        print("DRY_RUN")
        print(json.dumps(preview, indent=2, sort_keys=True))
        print("Re-run with --apply after reviewing the commit plan.")
        return 0

    now = datetime.now(timezone.utc)
    created_at = now.isoformat()
    timestamp = now.strftime("%Y%m%d-%H%M%S")
    snapshot_commit = create_snapshot_commit(
        repo_root,
        desired_tree=desired_tree,
        original_head=original_head,
        branch=branch,
        created_at=created_at,
    )
    backup_branch = choose_backup_branch(repo_root, branch, timestamp)
    run_git(["branch", backup_branch, snapshot_commit], cwd=repo_root)

    state_dir = absolute_git_dir(repo_root) / "reviewable-commits"
    state_file = state_dir / f"state-{timestamp}.json"
    state: dict[str, object] = {
        "script_version": SCRIPT_VERSION,
        "repo_root": str(repo_root),
        "branch": branch,
        "base_ref": args.base,
        "base_commit": base_commit,
        "merge_base": fork_point,
        "original_head": original_head,
        "desired_tree": desired_tree,
        "snapshot_commit": snapshot_commit,
        "backup_branch": backup_branch,
        "status_before": status_before,
        "created_at": created_at,
        "reset_applied": False,
    }
    write_json_atomic(state_file, state)

    try:
        run_git(["reset", "--mixed", fork_point], cwd=repo_root)
        tree_after_reset = compute_worktree_tree(repo_root)
        if tree_after_reset != desired_tree:
            run_git(["reset", "--mixed", original_head], cwd=repo_root, check=False)
            raise ReviewableCommitsError(
                "The mixed reset changed the captured final tree. The original branch pointer was restored; use the safety backup for inspection."
            )
    except Exception:
        state["reset_applied"] = False
        state["prepare_failed"] = True
        write_json_atomic(state_file, state)
        raise

    state["reset_applied"] = True
    write_json_atomic(state_file, state)

    print("PREPARED")
    print(f"STATE_FILE={state_file}")
    print(f"BACKUP_BRANCH={backup_branch}")
    print(f"MERGE_BASE={fork_point}")
    print(f"EXPECTED_TREE={desired_tree}")
    print(f"ORIGINAL_HEAD={original_head}")
    return 0


def load_state(path: Path) -> dict[str, object]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ReviewableCommitsError(f"State file does not exist: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReviewableCommitsError(f"State file is not valid JSON: {path}") from exc

    required = {
        "script_version",
        "repo_root",
        "branch",
        "merge_base",
        "desired_tree",
        "snapshot_commit",
        "backup_branch",
    }
    missing = sorted(required.difference(raw))
    if missing:
        raise ReviewableCommitsError(
            "State file is missing required fields: " + ", ".join(missing)
        )
    if raw["script_version"] != SCRIPT_VERSION:
        raise ReviewableCommitsError(
            f"Unsupported state version: {raw['script_version']}"
        )
    return raw


def commit_subject(repo_root: Path, commit: str) -> str:
    return run_git(["show", "-s", "--format=%s", commit], cwd=repo_root).stdout


def verify(args: argparse.Namespace) -> int:
    state_path = Path(args.state).expanduser().resolve()
    state = load_state(state_path)
    repo_root = repo_root_from(Path.cwd())

    expected_repo = Path(str(state["repo_root"])).resolve()
    if repo_root != expected_repo:
        raise ReviewableCommitsError(
            f"State belongs to a different repository: {expected_repo}"
        )

    assert_safe_repository_state(repo_root)
    branch = current_branch(repo_root)
    if branch != state["branch"]:
        raise ReviewableCommitsError(
            f"State was prepared for branch '{state['branch']}', but current branch is '{branch}'."
        )

    expected_tree = str(state["desired_tree"])
    fork_point = str(state["merge_base"])
    snapshot_commit = str(state["snapshot_commit"])
    backup_branch = str(state["backup_branch"])

    issues: list[str] = []
    warnings: list[str] = []

    status = repository_status(repo_root)
    if status:
        issues.append("Working tree is not clean.")

    head = resolve_commit(repo_root, "HEAD")
    head_tree = tree_for_commit(repo_root, head)
    if head_tree != expected_tree:
        diff_stat = run_git(
            ["diff", "--stat", snapshot_commit, "HEAD"],
            cwd=repo_root,
            check=False,
        ).stdout
        message = "HEAD tree does not match the captured final tree."
        if diff_stat:
            message += " Difference:\n" + diff_stat
        issues.append(message)

    ancestor = run_git(
        ["merge-base", "--is-ancestor", fork_point, "HEAD"],
        cwd=repo_root,
        check=False,
    )
    if ancestor.returncode != 0:
        issues.append("The recorded merge base is not an ancestor of rebuilt HEAD.")

    commits_output = run_git(
        ["rev-list", "--reverse", f"{fork_point}..HEAD"], cwd=repo_root
    ).stdout
    commits = [line for line in commits_output.splitlines() if line]
    if not commits and head_tree != tree_for_commit(repo_root, fork_point):
        issues.append("No rebuilt commits exist above the merge base.")

    commit_summaries: list[dict[str, str]] = []
    for commit in commits:
        parents = run_git(
            ["rev-list", "--parents", "-n", "1", commit], cwd=repo_root
        ).stdout.split()
        if len(parents) > 2:
            issues.append(f"Merge commit remains in rebuilt history: {commit[:12]}")
        elif len(parents) == 2:
            parent_tree = tree_for_commit(repo_root, parents[1])
            if parent_tree == tree_for_commit(repo_root, commit):
                issues.append(f"Empty commit found: {commit[:12]}")

        subject = commit_subject(repo_root, commit)
        if DISALLOWED_SUBJECT_RE.search(subject):
            issues.append(
                f"Temporary/fixup commit subject remains: {commit[:12]} {subject}"
            )
        commit_summaries.append({"sha": commit[:12], "subject": subject})

    diff_check = run_git(
        ["diff", "--check", f"{fork_point}..HEAD"],
        cwd=repo_root,
        check=False,
    )
    if diff_check.returncode != 0:
        issues.append(
            "Whitespace errors detected in rebuilt diff:\n"
            + (diff_check.stdout or diff_check.stderr)
        )

    if not ref_exists(repo_root, f"refs/heads/{backup_branch}"):
        warnings.append(f"Safety backup branch no longer exists: {backup_branch}")
    else:
        backup_tip = resolve_commit(repo_root, backup_branch)
        if backup_tip != snapshot_commit:
            warnings.append(
                f"Safety backup branch moved from snapshot {snapshot_commit[:12]}."
            )

    result = {
        "verified": not issues,
        "branch": branch,
        "head": head,
        "expected_tree": expected_tree,
        "head_tree": head_tree,
        "merge_base": fork_point,
        "commit_count": len(commits),
        "commits": commit_summaries,
        "backup_branch": backup_branch,
        "issues": issues,
        "warnings": warnings,
    }

    if issues:
        print("VERIFICATION_FAILED", file=sys.stderr)
        print(json.dumps(result, indent=2, sort_keys=True), file=sys.stderr)
        return 1

    print("VERIFIED")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Safely prepare and verify a branch-history rebuild."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    prepare_parser = subparsers.add_parser(
        "prepare",
        help="Capture a safety snapshot and optionally mixed-reset to the merge base.",
    )
    prepare_parser.add_argument(
        "--base",
        required=True,
        help="Base branch or commit used to calculate the merge base.",
    )
    prepare_parser.add_argument(
        "--apply",
        action="store_true",
        help="Create the snapshot and perform the mixed reset. Without this flag, run a dry check only.",
    )
    prepare_parser.set_defaults(func=prepare)

    verify_parser = subparsers.add_parser(
        "verify",
        help="Verify that rebuilt HEAD exactly matches a prepared safety snapshot.",
    )
    verify_parser.add_argument(
        "--state", required=True, help="State file emitted by the prepare command."
    )
    verify_parser.set_defaults(func=verify)

    return parser


def main(argv: Iterable[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)
    try:
        return int(args.func(args))
    except ReviewableCommitsError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("ERROR: interrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
