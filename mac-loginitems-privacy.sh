#!/bin/zsh
# mac-loginitems-privacy.sh
# 版本: 1.3.0
# 说明: 备份 / 还原 / 重置 登录项(含后台项清单) 与 TCC(隐私) 状态；生成 com.apple.servicemanagement 与 PPPC 草案。
# 用法: sudo zsh mac-loginitems-privacy.sh [backup|restore|reset|status] [--dry-run]

set -Eeuo pipefail

SCRIPT_VERSION="1.3.0"
DRY_RUN=0
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=1

# ---------- 日志&运行工具 ----------
ts(){ date '+%F %T'; }
log(){ printf '[%s] %s\n' "$(ts)" "$*"; }
info(){ log "INFO: $*"; }
warn(){ log "WARN: $*"; }
err(){ log "ERROR: $*" >&2; }
die(){ err "$*"; exit 1; }
step(){ printf '\n%s\n' "==== $* ===="; }

require_cmd(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }

# 以控制台用户上下文运行（避免 sudo 导致 HOME=/var/root）
console_user(){ /usr/bin/stat -f%Su /dev/console; }
console_uid(){ /usr/bin/id -u "$(console_user)"; }
run_as_user(){ local uid="$(console_uid)" u="$(console_user)"; 
  if [[ $DRY_RUN -eq 1 ]]; then info "DRY-RUN launchctl asuser $uid sudo -u $u $*"; return 0; fi
  /bin/launchctl asuser "$uid" sudo -u "$u" "$@"
}

# ---------- 动态解析路径 ----------
user_home(){
  local u="$(console_user)"
  /usr/bin/dscl -q . -read "/Users/${u}" NFSHomeDirectory 2>/dev/null \
    | /usr/bin/awk -F': ' '/NFSHomeDirectory/{print $2; exit}'
}

icloud_base(){
  local home="$(user_home)"
  local p="${home}/Library/Mobile Documents/com~apple~CloudDocs"
  if [[ -d "$p" ]]; then printf '%s\n' "$p"; return 0; fi
  # 兜底：mdfind（File Provider 环境下也能定位）
  local q; q=$(/usr/bin/mdfind "kMDItemFSName == 'com~apple~CloudDocs' && kMDItemContentType == 'public.folder'" \
         -onlyin "${home}/Library/Mobile Documents" | /usr/bin/head -n1)
  [[ -n "$q" ]] && { printf '%s\n' "$q"; return 0; }
  return 1
}

computer_name_slug(){
  # 原始函数保留，用于兼容旧逻辑。该函数基于计算机名生成安全化 slug。
  local name; name=$(/usr/sbin/scutil --get ComputerName 2>/dev/null || true)
  [[ -z "$name" ]] && name=$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || true)
  [[ -z "$name" ]] && name="$(/usr/bin/hostname -s 2>/dev/null || echo Mac)"
  echo "$name" | /usr/bin/tr '[:space:]' '-' | /usr/bin/sed -E 's/[^[:alnum:]\-]+/-/g; s/-+/-/g; s/^-|-$//g'
}

# 生成设备标识符，格式为“型号名称-芯片名称-序列号”。
# - 型号名称取自 system_profiler SPHardwareDataType 的 Model Name 字段，去除首尾空白并删除所有空格；
# - 芯片名称取自 sysctl machdep.cpu.brand_string，去掉 "Apple" 前缀并删除所有空格和首尾空白；
# - 序列号取自 system_profiler 的 Serial Number 字段，去除首尾空白；
# 生成的 slug 使用连字符连接，合并连续连字符，并去除开头结尾的连字符。
device_identifier_slug(){
  # 获取型号名称并清理
  local model_raw; model_raw=$(/usr/sbin/system_profiler SPHardwareDataType 2>/dev/null | /usr/bin/awk -F':' '/Model Name/{print $2; exit}' || true)
  local model_clean; model_clean=$(echo "${model_raw}" | /usr/bin/sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | /usr/bin/tr -d '[:space:]')
  # 获取芯片品牌并去除 "Apple" 前缀及空白
  local cpu_raw; cpu_raw=$(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || true)
  local cpu_trim; cpu_trim=$(echo "${cpu_raw}" | /usr/bin/sed -e 's/^Apple[[:space:]]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local cpu_clean; cpu_clean=$(echo "${cpu_trim}" | /usr/bin/tr -d '[:space:]')
  # 获取序列号并清理
  local serial_raw; serial_raw=$(/usr/sbin/system_profiler SPHardwareDataType 2>/dev/null | /usr/bin/awk -F':' '/Serial Number/{print $2; exit}' || true)
  local serial_clean; serial_clean=$(echo "${serial_raw}" | /usr/bin/sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  # 拼接为 slug
  local slug="${model_clean}-${cpu_clean}-${serial_clean}"
  slug=$(echo "$slug" | /usr/bin/sed -E 's/-{2,}/-/g; s/^-|-$//g')
  printf '%s\n' "$slug"
}

user_display_slug(){
  local u="$(console_user)"
  local rn
  rn=$(/usr/bin/dscl -q . -read "/Users/${u}" RealName 2>/dev/null \
      | /usr/bin/tail -n +2 | /usr/bin/tr '\n' ' ' | /usr/bin/sed -E 's/^\s+|\s+$//g')
  [[ -z "$rn" ]] && rn="$u"
  rn=$(echo "$rn" | /usr/bin/tr -d '[:space:]' | /usr/bin/sed -E 's/[^[:alnum:]]+//g')
  [[ -z "$rn" ]] && rn="$u"
  printf '%s\n' "$rn"
}

build_backup_root(){
  local base; base="$(icloud_base)" || { 
    err "未发现 iCloud Drive 路径。请在『系统设置 > Apple ID > iCloud > iCloud Drive』开启。"; return 1; }
  # 使用新的设备标识符代替电脑名，格式为“型号-芯片-序列号”
  local host; host="$(device_identifier_slug)"
  local userseg; userseg="$(user_display_slug)"
  printf '%s\n' "${base}/BACKUP/${host}/${userseg}/Loginitems-Privacy"
}

BACKUP_ROOT="${BACKUP_ROOT:-$(build_backup_root)}" || exit 1

timestamp(){ date +%Y%m%d-%H%M%S; }

# ---------- 公用小工具 ----------
xml_escape(){ /usr/bin/sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/'/\&apos;/g" -e 's/"/\&quot;/g'; }

check_prereq(){
  require_cmd osascript
  require_cmd sqlite3
  require_cmd plutil
  command -v sfltool >/dev/null 2>&1 || warn "未发现 sfltool（老系统或路径差异），后台项 dump/reset 将跳过"
  command -v pluginkit >/dev/null 2>&1 || warn "未发现 pluginkit（老系统或路径差异），扩展清单将跳过"
  command -v systemextensionsctl >/dev/null 2>&1 || warn "未发现 systemextensionsctl，系统扩展清单将跳过"
}

# ---------- 生成配置文件（后台 + PPPC 草案） ----------
generate_mobileconfigs(){
  local dir="$1"; local profdir="$dir/profiles"
  [[ $DRY_RUN -eq 0 ]] && /bin/mkdir -p "$profdir"

  step "生成 com.apple.servicemanagement（后台项目管理）草案"
  # 收集可能的 Label
  local labels=()
  for plist in /Library/LaunchAgents/*.plist "$HOME/Library/LaunchAgents"/*.plist /Library/LaunchDaemons/*.plist ; do
    [[ -r "$plist" ]] || continue
    local lbl; lbl=$(/usr/bin/plutil -extract Label raw -o - "$plist" 2>/dev/null || true)
    [[ -n "${lbl:-}" ]] && labels+=("$lbl")
  done
  local uuid; uuid=$(/usr/bin/uuidgen)
  local smc="$profdir/ManagedLoginItems-$uuid.mobileconfig"

  if [[ $DRY_RUN -eq 1 ]]; then
    info "DRY-RUN 将写入: $smc（规则数量: ${#labels[@]}）"
  else
    {
      cat <<PL1
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>PayloadDisplayName</key><string>Managed Login & Background Items (auto-generated)</string>
  <key>PayloadIdentifier</key><string>local.generated.servicemanagement</string>
  <key>PayloadRemovalDisallowed</key><false/>
  <key>PayloadType</key><string>Configuration</string>
  <key>PayloadUUID</key><string>$uuid</string>
  <key>PayloadVersion</key><integer>1</integer>
  <key>PayloadOrganization</key><string>local</string>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key><string>com.apple.servicemanagement</string>
      <key>PayloadVersion</key><integer>1</integer>
      <key>PayloadIdentifier</key><string>local.generated.servicemanagement.payload</string>
      <key>PayloadDisplayName</key><string>Service Management - Managed Login Items</string>
      <key>Rules</key><array>
PL1
      for lbl in "${labels[@]}"; do
        esc=$(printf '%s' "$lbl" | xml_escape)
        printf '        <dict>\n          <key>RuleType</key><string>Label</string>\n          <key>RuleValue</key><string>%s</string>\n        </dict>\n' "$esc"
      done
      cat <<'PL2'
      </array>
    </dict>
  </array>
</dict></plist>
PL2
    } > "$smc"
    info "已生成: $smc"
  fi

  step "生成 PPPC（com.apple.TCC.configuration-profile-policy）草案"
  local pppc="$profdir/PPPC-draft-$uuid.mobileconfig"
  if [[ $DRY_RUN -eq 0 ]]; then
    cat > "$pppc" <<PP
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>PayloadDisplayName</key><string>PPPC (draft)</string>
  <key>PayloadIdentifier</key><string>local.generated.pppc</string>
  <key>PayloadRemovalDisallowed</key><false/>
  <key>PayloadType</key><string>Configuration</string>
  <key>PayloadUUID</key><string>PPPC-$uuid</string>
  <key>PayloadVersion</key><integer>1</integer>
  <key>PayloadContent</key><array>
    <dict>
      <key>PayloadType</key><string>com.apple.TCC.configuration-profile-policy</string>
      <key>PayloadVersion</key><integer>1</integer>
      <key>PayloadIdentifier</key><string>local.generated.pppc.payload</string>
      <key>Services</key><dict>
        <!-- 在 MDM 或 Apple Configurator 里补齐各 App 的 BundleID 与 CodeRequirement；
             例如 Accessibility / SystemPolicyAllFiles / ScreenCapture 等 -->
      </dict>
    </dict>
  </array>
</dict></plist>
PP
    info "已生成: $pppc"
  else
    info "DRY-RUN 将写入: $pppc"
  fi
}

# ---------- 备份 ----------
backup(){
  check_prereq
  local dir="$BACKUP_ROOT/$(timestamp)"
  step "解析路径"
  info "控制台用户: $(console_user)"
  # 显示设备标识符，基于型号、芯片和序列号构成，用于路径命名
  info "设备标识(安全化): $(device_identifier_slug)"
  info "用户显示名(安全化): $(user_display_slug)"
  info "iCloud 基路径: $(icloud_base || echo '未找到')"
  info "备份根目录: $dir"

  [[ $DRY_RUN -eq 0 ]] && /bin/mkdir -p "$dir"/{loginitems,launchd,extensions,tcc,profiles,logs}

  step "记录系统信息"
  /usr/bin/sw_vers            > "$dir/logs/sw_vers.txt"           2>&1 || true
  /usr/sbin/system_profiler SPHardwareDataType > "$dir/logs/hw.txt" 2>&1 || true

  step "导出 登录项&后台项（sfltool dumpbtm）"
  if command -v sfltool >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 0 ]]; then
      sudo /usr/bin/sfltool dumpbtm > "$dir/loginitems/btm_dump.txt" 2>&1 || true
      info "btm_dump.txt 已保存"
    else
      info "DRY-RUN: sudo sfltool dumpbtm > $dir/loginitems/btm_dump.txt"
    fi
  else
    warn "sfltool 不可用，跳过 dumpbtm"
  fi

  step "导出 “登录时打开”（Open at Login）清单（JXA）"
  local jxa='var se=Application("System Events");
var arr=se.loginItems().map(li=>({name:li.name(),path:li.path(),hidden:li.hidden()}));
JSON.stringify(arr,null,2);'
  if [[ $DRY_RUN -eq 0 ]]; then
    run_as_user /usr/bin/osascript -l JavaScript -e "$jxa" > "$dir/loginitems/open_at_login.json" || true
    info "open_at_login.json 已保存"
  else
    info "DRY-RUN: osascript(JXA) dump -> $dir/loginitems/open_at_login.json"
  fi

  step "枚举 launchd 项（作为后台规则参考）"
  /bin/ls -1 /Library/LaunchAgents              > "$dir/launchd/Library_LaunchAgents.txt" 2>/dev/null || true
  /bin/ls -1 "$HOME/Library/LaunchAgents"       > "$dir/launchd/User_LaunchAgents.txt"    2>/dev/null || true
  /bin/ls -1 /Library/LaunchDaemons             > "$dir/launchd/Library_LaunchDaemons.txt" 2>/dev/null || true

  step "导出扩展清单（pluginkit / systemextensionsctl / kmutil）"
  command -v pluginkit >/dev/null 2>&1 && /usr/bin/pluginkit -mAvvv > "$dir/extensions/pluginkit.txt" 2>&1 || true
  command -v systemextensionsctl >/dev/null 2>&1 && /usr/bin/systemextensionsctl list > "$dir/extensions/systemextensions.txt" 2>&1 || true
  command -v kmutil >/dev/null 2>&1 && /usr/bin/kmutil showloaded --list-only > "$dir/extensions/kexts.txt" 2>&1 || true

  step "备份 TCC 数据库（并生成 CSV 摘要）"
  if [[ $DRY_RUN -eq 0 ]]; then
    /bin/cp -v "$HOME/Library/Application Support/com.apple.TCC/TCC.db"* "$dir/tcc/" 2>/dev/null || warn "用户 TCC.db 拷贝失败（需要给 Terminal 完全磁盘访问）"
    sudo /bin/cp -v "/Library/Application Support/com.apple.TCC/TCC.db"* "$dir/tcc/" 2>/dev/null || warn "系统 TCC.db 拷贝失败（SIP/权限限制）"
    for f in "$dir/tcc"/TCC.db* ; do
      [[ -f "$f" && "$f" != *".wal" && "$f" != *".shm" ]] || continue
      /usr/bin/sqlite3 "$f" "SELECT name FROM sqlite_master WHERE type='table' AND name='access';" | /usr/bin/grep -q '^access$' && \
        /usr/bin/sqlite3 "$f" "SELECT client,service,auth_value,auth_reason FROM access" > "$dir/tcc/access_$(basename "$f").csv" 2>/dev/null || true
      /usr/bin/sqlite3 "$f" ".schema access" > "$dir/tcc/schema_$(basename "$f").txt" 2>/dev/null || true
    done
    info "TCC 备份完成（仅用于本机回滚，不建议跨机覆盖）"
  else
    info "DRY-RUN: 复制 TCC.db* -> $dir/tcc/"
  fi

  generate_mobileconfigs "$dir"
  step "备份结束：$dir"
}

# ---------- 还原 ----------
restore(){
  check_prereq
  local latest="$(/bin/ls -1dt "$BACKUP_ROOT"/* 2>/dev/null | /usr/bin/head -n1 || true)"
  [[ -z "$latest" ]] && die "未找到备份目录：$BACKUP_ROOT/*，请先执行 backup"
  step "使用最近备份: $latest"

  step "重建 “登录时打开” 列表"
  local json="$latest/loginitems/open_at_login.json"
  if [[ -f "$json" ]]; then
    local jxa='ObjC.import("Foundation");var se=Application("System Events");
function fileStr(p){var s=$.NSString.stringWithContentsOfFileEncodingError($(p),4,null);return ObjC.unwrap(s)}
var items=JSON.parse(fileStr($.getenv("LOGIN_JSON")));
var existing=se.loginItems().map(li=>li.name());
items.forEach(function(i){
  try{
    if(existing.indexOf(i.name)===-1 && i.path){
      se.make({new:"login item", withProperties:{name:i.name, path:i.path, hidden:i.hidden}});
      delay(0.05);
    }
  }catch(e){}
});'
    if [[ $DRY_RUN -eq 0 ]]; then
      LOGIN_JSON="$json" run_as_user /usr/bin/osascript -l JavaScript -e "$jxa" || true
      info "已尝试按备份清单重建登录项"
    else
      info "DRY-RUN: 依据 open_at_login.json 重建登录项"
    fi
  else
    warn "未发现 $json，跳过"
  fi

  step "安装/引导安装 后台项目管理 & PPPC 配置"
  local mg="$latest/profiles"/ManagedLoginItems-*.mobileconfig
  local pppc="$latest/profiles"/PPPC-draft-*.mobileconfig
  if command -v profiles >/dev/null 2>&1; then
    for f in $mg $pppc; do
      [[ -f "$f" ]] || continue
      if [[ $DRY_RUN -eq 0 ]]; then
        info "尝试安装: $f"
        /usr/bin/profiles -I -F "$f" || warn "profiles 安装失败，可能需要手动在『系统设置 > 通用 > 设备管理』中安装"
      else
        info "DRY-RUN: profiles -I -F \"$f\""
      fi
    done
  else
    warn "未发现 profiles 命令，请双击上述 .mobileconfig 手动安装"
  fi

  step "打开『登录项』设置页，便于核对“允许在后台”"
  run_as_user /usr/bin/open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension" || true

  step "关于 TCC：如需清空后重新触发授权对话，可执行：sudo tccutil reset All"
  info "（更推荐在 MDM/Configurator 里完善 PPPC 并安装）"
}

# ---------- 重置 ----------
reset_all(){
  check_prereq
  step "重置 后台项目/登录项 & TCC"
  if [[ $DRY_RUN -eq 0 ]]; then
    command -v sfltool >/dev/null 2>&1 && { info "执行: sfltool resetbtm"; sudo /usr/bin/sfltool resetbtm || true; }
    info "执行: tccutil reset All"
    /usr/bin/tccutil reset All || true
  else
    info "DRY-RUN: sfltool resetbtm"
    info "DRY-RUN: tccutil reset All"
  fi
  warn "建议重启后检查『系统设置 > 通用 > 登录项』与『隐私与安全性』"
}

# ---------- 状态摘要 ----------
status(){
  check_prereq
  step "路径&环境"
  info "控制台用户: $(console_user)"
  info "备份根目录: $BACKUP_ROOT"
  step "登录项/后台项（前 200 行）"
  command -v sfltool >/dev/null 2>&1 && sudo /usr/bin/sfltool dumpbtm | /usr/bin/head -n 200 || warn "sfltool 不可用或权限不足"
  step "当前『登录时打开』列表（JXA）"
  run_as_user /usr/bin/osascript -l JavaScript -e 'var se=Application("System Events");JSON.stringify(se.loginItems().map(li=>({name:li.name(),path:li.path(),hidden:li.hidden()})),null,2)'
  step "TCC 用户库（前 20 条）"
  /usr/bin/sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" "SELECT client,service,auth_value FROM access LIMIT 20" 2>/dev/null || warn "读取失败（给终端完全磁盘访问后再试）"
}

# ---------- 主入口 ----------
main(){
  case "${1:-}" in
    backup)  backup ;;
    restore) restore ;;
    reset)   reset_all ;;
    status)  status ;;
    *) echo "用法: sudo zsh $0 [backup|restore|reset|status] [--dry-run]"; exit 1 ;;
  esac
  info "脚本完成，版本 $SCRIPT_VERSION"
}
main "$@"