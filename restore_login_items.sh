#!/bin/zsh
# restore_login_items.sh
# 在当前目录（Loginitems-Privacy）下查找最新的日期备份目录，读取 loginitems/open_at_login.json
# 对其中以 .app 结尾的项目，使用 AppleScript (System Events) 添加到“登录时打开”列表。
# 需要在用户会话中运行，并确保终端应用有“辅助功能”权限。
# 用法: zsh restore_login_items.sh 或 sudo -u <user> zsh restore_login_items.sh

set -euo pipefail

# 找到当前目录下的最新备份目录
latest=""
orig_ifs=$IFS
IFS=$'\n'
for d in $(/bin/ls -1dt -- */ 2>/dev/null); do
  if [[ -d "$d" ]]; then
    latest="${d%/}"
    break
  fi
done
IFS=$orig_ifs

if [[ -z "$latest" ]]; then
  echo "No backup directory found. Run this script in the Loginitems-Privacy directory." >&2
  exit 1
fi

json_path="$latest/loginitems/open_at_login.json"
if [[ ! -f "$json_path" ]]; then
  echo "Could not find $json_path" >&2
  exit 1
fi

echo "Using backup directory: $latest"
echo "Restoring login items (applications)..."

/usr/bin/python3 - "$json_path" <<'PY'
import json, os, sys, subprocess

json_file = sys.argv[1]
with open(json_file) as f:
    data = json.load(f)

def esc(s: str) -> str:
    return s.replace('"', '\\"')

for item in data:
    name = item.get('name') or ''
    path = item.get('path') or ''
    hidden = bool(item.get('hidden', False))
    if not name or not path:
        continue
    path = path.rstrip('/')
    if not path.endswith('.app'):
        continue
    script = f'tell application "System Events" to make new login item at end of login items with properties {{name:"{esc(name)}", path:"{esc(path)}", hidden:{str(hidden).lower()}}}'
    print(f"Adding login item: {name} -> {path}")
    subprocess.run(['/usr/bin/osascript', '-e', script], check=False)
PY

echo "Login items restoration completed. Please check them in System Settings > General > Login Items."