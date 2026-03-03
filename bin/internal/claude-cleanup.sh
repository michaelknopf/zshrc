#!/usr/bin/env zsh
set -euo pipefail

# Prune old Claude Code data to reclaim disk space and speed up startup.
#
# Claude Code accumulates conversation histories, debug logs, file backups, and
# session metadata in ~/.claude/. This script deletes files older than N days
# (default: 3) from the high-impact directories while preserving functional state
# (plugins, settings, caches, and recent sessions).
#
# Usage:
#   claude-cleanup.sh [--days N] [--dry-run]
#
# Flags:
#   --days N    Delete files older than N days (default: 3)
#   --dry-run   Show what would be deleted (with sizes) without deleting anything

DAYS=3
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)
      DAYS="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--days N] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

CLAUDE_DIR="${HOME}/.claude"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Print the total disk usage of a set of paths produced by a find command.
# Args: label, find_args...
preview_find() {
  local label="$1"
  shift
  # Collect matching paths into an array so we can stat them.
  local -a paths
  paths=("${(@f)$(find "$@" 2>/dev/null)}")
  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "  [nothing to delete] $label"
    return
  fi
  # du -sh on the list of paths; redirect stderr to suppress "no such file" races.
  local size
  size=$(du -sh "${paths[@]}" 2>/dev/null | tail -1 | awk '{print $1}')
  echo "  ${size}  $label (${#paths[@]} items)"
}

# Run a find+delete. In dry-run mode, preview only.
# Args: label, find_args_without_delete...
run_cleanup() {
  local label="$1"
  shift
  if [[ "$DRY_RUN" == true ]]; then
    preview_find "$label" "$@"
  else
    find "$@" -delete 2>/dev/null || true
  fi
}

# Run a find+-exec rm -rf. Used for directory trees where -delete won't recurse.
# Args: label, find_args_without_exec...
run_cleanup_dirs() {
  local label="$1"
  shift
  if [[ "$DRY_RUN" == true ]]; then
    preview_find "$label" "$@" -type d
  else
    find "$@" -type d -exec rm -rf {} + 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

SIZE_BEFORE=$(du -sh "$CLAUDE_DIR" 2>/dev/null | awk '{print $1}')

if [[ "$DRY_RUN" == true ]]; then
  echo "DRY RUN — showing what would be deleted (files older than ${DAYS} days):"
  echo ""
else
  echo "Cleaning up ~/.claude/ (files older than ${DAYS} days)..."
  echo ""
fi

# 1. projects/ — conversation JSONL files and UUID session directories
#    Preserve: sessions-index.json, CLAUDE.md, settings.json, project dirs themselves.
run_cleanup \
  "projects/*.jsonl conversation files" \
  "${CLAUDE_DIR}/projects/" -name '*.jsonl' -mtime "+${DAYS}"

run_cleanup_dirs \
  "projects/ UUID session directories" \
  "${CLAUDE_DIR}/projects/" -mindepth 2 -maxdepth 2 -mtime "+${DAYS}"

# 2. debug/ — verbose debug logs; the `latest` symlink is not a regular file so
#    `-type f` naturally excludes it.
run_cleanup \
  "debug/*.txt log files" \
  "${CLAUDE_DIR}/debug/" -type f -name '*.txt' -mtime "+${DAYS}"

# 3. file-history/ — per-session backup directories
run_cleanup_dirs \
  "file-history/ session directories" \
  "${CLAUDE_DIR}/file-history/" -mindepth 1 -maxdepth 1 -mtime "+${DAYS}"

# 4. todos/ — serialised todo lists
run_cleanup \
  "todos/*.json files" \
  "${CLAUDE_DIR}/todos/" -name '*.json' -mtime "+${DAYS}"

# 5. plans/ — markdown plan files
run_cleanup \
  "plans/*.md files" \
  "${CLAUDE_DIR}/plans/" -name '*.md' -mtime "+${DAYS}"

# 6. paste-cache/ — clipboard/paste snapshots
run_cleanup \
  "paste-cache/*.txt files" \
  "${CLAUDE_DIR}/paste-cache/" -name '*.txt' -mtime "+${DAYS}"

# 7. shell-snapshots/ — shell state dumps
run_cleanup \
  "shell-snapshots/*.sh files" \
  "${CLAUDE_DIR}/shell-snapshots/" -name '*.sh' -mtime "+${DAYS}"

# 8. session-env/ — empty session environment directories
#    Only delete directories that are empty (-empty) to avoid removing anything
#    that still contains data, regardless of mtime.
if [[ "$DRY_RUN" == true ]]; then
  preview_find \
    "session-env/ empty directories" \
    "${CLAUDE_DIR}/session-env/" -mindepth 1 -maxdepth 1 -type d -empty -mtime "+${DAYS}"
else
  find "${CLAUDE_DIR}/session-env/" -mindepth 1 -maxdepth 1 -type d -empty \
    -mtime "+${DAYS}" -delete 2>/dev/null || true
fi

echo ""

if [[ "$DRY_RUN" == true ]]; then
  echo "Current size: ${SIZE_BEFORE}"
  echo "Run without --dry-run to delete the above files."
else
  SIZE_AFTER=$(du -sh "$CLAUDE_DIR" 2>/dev/null | awk '{print $1}')
  echo "Before: ${SIZE_BEFORE}  →  After: ${SIZE_AFTER}"
fi
