#!/usr/bin/env bash
# Log Archiver: compress logs under a directory into a timestamped tar.gz
# Usage:
#   log-archive <log-directory> [--out <archive-dir>] [--retain <days>]
#
# Examples:
#   log-archive /var/log
#   log-archive /var/log --out /var/log/archives --retain 14
#
# Notes:
# - Use sudo when archiving system logs (e.g., /var/log).
# - Writes a history file: <archive-dir>/archive_history.log

set -euo pipefail

# ---- helpers ----
print_usage() {
  sed -n '2,20p' "$0"
}

err() { printf "Error: %s\n" "$*" >&2; exit 1; }

# Portable file size (Linux/macOS)
filesize() {
  local f="$1"
  if command -v stat >/dev/null 2>&1; then
    # macOS: stat -f%z, GNU: stat -c%s
    if stat -f%z "$f" >/dev/null 2>&1; then
      stat -f%z "$f"
    else
      stat -c%s "$f"
    fi
  else
    # Fallback: bytes via wc -c (prefix trimmed)
    wc -c <"$f" | tr -d ' '
  fi
}

# ---- parse args ----
[[ $# -lt 1 ]] && { print_usage; exit 1; }

LOG_DIR=""
OUT_DIR=""
RETAIN_DAYS=""

LOG_DIR="$1"; shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      shift; OUT_DIR="${1:-}"; [[ -z "${OUT_DIR}" ]] && err "--out needs a directory"
      ;;
    --retain)
      shift; RETAIN_DAYS="${1:-}"; [[ -z "${RETAIN_DAYS}" ]] && err "--retain needs a number"
      [[ "${RETAIN_DAYS}" =~ ^[0-9]+$ ]] || err "--retain must be an integer (days)"
      ;;
    -h|--help)
      print_usage; exit 0;;
    *)
      err "Unknown argument: $1"
      ;;
  esac
  shift || true
done

# ---- validate & prepare ----
[[ -d "$LOG_DIR" ]] || err "Log directory not found: $LOG_DIR"
LOG_DIR="$(cd "$LOG_DIR" && pwd -P)"

if [[ -z "${OUT_DIR}" ]]; then
  OUT_DIR="$LOG_DIR/archives"
fi
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd -P)"

TS="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_NAME="logs_archive_${TS}.tar.gz"
ARCHIVE_PATH="$OUT_DIR/$ARCHIVE_NAME"
HISTORY_FILE="$OUT_DIR/archive_history.log"

# ---- create archive ----
# Exclude the archive directory itself and pre-existing tarballs to avoid recursion.
# Use -C to archive relative paths (cleaner structure when extracting).
tar -czf "$ARCHIVE_PATH" \
  -C "$LOG_DIR" \
  --exclude='./archives' \
  --exclude='*.tar.gz' \
  .

# ---- log history ----
BYTES="$(filesize "$ARCHIVE_PATH")"
HUMAN_SIZE="$(du -h "$ARCHIVE_PATH" | awk '{print $1}')"

{
  echo "timestamp=${TS}"
  echo "source=${LOG_DIR}"
  echo "archive=${ARCHIVE_PATH}"
  echo "size_bytes=${BYTES}"
  echo "size_human=${HUMAN_SIZE}"
  echo "----"
} >> "$HISTORY_FILE"

printf "Created: %s (%s)\n" "$ARCHIVE_PATH" "$HUMAN_SIZE"
printf "Logged to: %s\n" "$HISTORY_FILE"

# ---- optional retention cleanup ----
if [[ -n "${RETAIN_DAYS}" ]]; then
  # Delete archives older than RETAIN_DAYS, log deletions
  # -mindepth to avoid touching OUT_DIR itself
  while IFS= read -r oldfile; do
    printf "🗑️  Deleting old archive (> %sd): %s\n" "$RETAIN_DAYS" "$oldfile"
    {
      echo "timestamp=${TS}"
      echo "action=delete_old_archive"
      echo "file=${oldfile}"
      echo "retain_days=${RETAIN_DAYS}"
      echo "----"
    } >> "$HISTORY_FILE"
    rm -f -- "$oldfile"
  done < <(find "$OUT_DIR" -mindepth 1 -maxdepth 1 -name 'logs_archive_*.tar.gz' -type f -mtime +"$RETAIN_DAYS")
fi
