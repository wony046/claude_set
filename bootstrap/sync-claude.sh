#!/usr/bin/env bash
# claude_set/home 을 ~/.claude 로 설치한다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO/home"
DEST="$HOME/.claude"
STAMP="$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'USAGE'
Usage: sync-claude.sh [--status | --pull | --help]

  (no option)  Copy home/ into ~/.claude/ and merge shared settings
  --status     Compare both sides, change nothing
  --pull       Copy changes from ~/.claude/ back into home/
  --help       Show this message
USAGE
}

# settings.json 은 병합으로 따로 처리한다
list_items() {
  for entry in "$SRC"/*; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    [ "$name" = "settings.json" ] && continue
    echo "$name"
  done
}

# 공유 항목만 덮어쓰고 나머지 설정은 그대로 둔다
merge_settings() {
  python3 - "$SRC/settings.json" "$DEST/settings.json" "$STAMP" <<'PY'
import json, os, sys, shutil
src, dst, stamp = sys.argv[1], sys.argv[2], sys.argv[3]
shared = json.load(open(src))
current = {}
if os.path.exists(dst):
    current = json.load(open(dst))
    shutil.copy2(dst, f"{dst}.backup-{stamp}")
changed = {k: v for k, v in shared.items() if current.get(k) != v}
current.update(shared)
with open(dst, "w") as f:
    json.dump(current, f, indent=2, ensure_ascii=False)
    f.write("\n")
for k, v in changed.items():
    print(f"  merged: {k} = {v!r}")
if not changed:
    print("  settings already up to date")
PY
}

do_install() {
  echo "Installing from $SRC"
  while read -r name; do
    src="$SRC/$name"; dst="$DEST/$name"
    # 내용이 다르면 백업을 남긴다
    if [ -e "$dst" ] && ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
      cp -a "$dst" "$dst.backup-$STAMP"
      echo "  backed up: $name -> $name.backup-$STAMP"
    fi
    if [ -d "$src" ]; then
      mkdir -p "$dst"; cp -a "$src/." "$dst/"
    else
      cp -a "$src" "$dst"
    fi
    echo "  installed: $name"
  done < <(list_items)
  echo "Merging shared settings into $DEST/settings.json"
  merge_settings
}

do_status() {
  echo "Repo   : $SRC"
  echo "Target : $DEST"
  while read -r name; do
    src="$SRC/$name"; dst="$DEST/$name"
    if [ ! -e "$dst" ]; then
      echo "  [none] $name"
    elif diff -rq "$src" "$dst" >/dev/null 2>&1; then
      echo "  [ok  ] $name"
    else
      echo "  [DIFF] $name"
      diff -rq "$src" "$dst" 2>&1 | sed 's/^/         /'
    fi
  done < <(list_items)
  python3 - "$SRC/settings.json" "$DEST/settings.json" <<'PY'
import json, os, sys
src, dst = sys.argv[1], sys.argv[2]
shared = json.load(open(src))
current = json.load(open(dst)) if os.path.exists(dst) else {}
for k, v in shared.items():
    print(f"  [{'ok  ' if current.get(k) == v else 'DIFF'}] settings.{k} = {v!r}")
PY
}

# 홈에서 고친 것을 저장소로 되돌린다
do_pull() {
  echo "Collecting from $DEST"
  while read -r name; do
    src="$SRC/$name"; dst="$DEST/$name"
    [ -e "$dst" ] || { echo "  skipped: $name"; continue; }
    if diff -rq "$src" "$dst" >/dev/null 2>&1; then
      echo "  unchanged: $name"; continue
    fi
    if [ -d "$dst" ]; then cp -a "$dst/." "$src/"; else cp -a "$dst" "$src"; fi
    echo "  pulled: $name"
  done < <(list_items)
  echo "Review with: git -C \"$REPO\" diff"
}

[ -d "$SRC" ] || { echo "Not found: $SRC"; exit 1; }
mkdir -p "$DEST"

case "${1:-}" in
  --status) do_status ;;
  --pull)   do_pull ;;
  --help|-h) usage ;;
  "")       do_install; echo; do_status ;;
  *)        usage; exit 1 ;;
esac
