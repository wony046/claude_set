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

# 저장소 쪽 파일이 홈에 같은 내용으로 있는지만 본다. 홈에만 있는 파일은 따지지 않는다
same_as_src() {
  python3 - "$1" "$2" <<'PY'
import sys, os, filecmp
src, dst = sys.argv[1], sys.argv[2]
if not os.path.exists(dst):
    sys.exit(1)
if os.path.isdir(src):
    for root, _, files in os.walk(src):
        for f in files:
            a = os.path.join(root, f)
            b = os.path.join(dst, os.path.relpath(a, src))
            if not os.path.exists(b) or not filecmp.cmp(a, b, shallow=False):
                sys.exit(1)
    sys.exit(0)
sys.exit(0 if filecmp.cmp(src, dst, shallow=False) else 1)
PY
}

# 홈에만 있는 파일을 나열한다
list_extras() {
  local src="$1" dst="$2"
  [ -d "$src" ] && [ -d "$dst" ] || return 0
  ( cd "$dst" && find . -type f 2>/dev/null | sed 's|^\./||' ) | while read -r f; do
    [ -e "$src/$f" ] || echo "$f"
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
changed = {k: v for k, v in shared.items() if current.get(k) != v}
if not changed:
    print("  settings already up to date")
    sys.exit(0)
# 바뀔 항목이 있을 때만 사본을 남긴다
if os.path.exists(dst):
    shutil.copy2(dst, f"{dst}.backup-{stamp}")
current.update(shared)
with open(dst, "w") as f:
    json.dump(current, f, indent=2, ensure_ascii=False)
    f.write("\n")
for k, v in changed.items():
    print(f"  merged: {k} = {v!r}")
PY
}

do_install() {
  echo "Installing from $SRC"
  while read -r name; do
    src="$SRC/$name"; dst="$DEST/$name"
    # 내용이 다를 때만 백업을 남긴다
    if [ -e "$dst" ] && ! same_as_src "$src" "$dst"; then
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
    elif same_as_src "$src" "$dst"; then
      echo "  [ok  ] $name"
    else
      echo "  [DIFF] $name"
    fi
    list_extras "$src" "$dst" | sed 's/^/         extra in home: /'
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
    if [ ! -e "$dst" ]; then
      echo "  skipped: $name"
    elif same_as_src "$src" "$dst"; then
      echo "  unchanged: $name"
    else
      if [ -d "$dst" ]; then cp -a "$dst/." "$src/"; else cp -a "$dst" "$src"; fi
      echo "  pulled: $name"
    fi
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
