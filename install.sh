#!/bin/zsh -f
# =============================================================================
#  TermAwake 安裝程式
#
#    ./install.sh                 自動判斷你用 Terminal 還是 iTerm2
#    ./install.sh --app iTerm2    指定要監視的 App
#    ./install.sh --battery 30    用電池時低於 30% 就恢復睡眠（預設 20）
#
#  重複執行沒關係：會更新程式，並保留你原本的設定。
# =============================================================================
emulate -R zsh
setopt no_unset pipe_fail extended_glob

typeset -r LABEL=io.github.jhongwe1.termawake
typeset -r SRC_DIR=${0:A:h}
typeset -r APP_DIR="$HOME/Library/Application Support/TermAwake"
typeset -r BIN="$APP_DIR/termawake"
typeset -r CONFIG="$APP_DIR/config"
typeset -r STATE_FILE="$APP_DIR/state"
typeset -r LINK="$HOME/.local/bin/termawake"
typeset -r PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
typeset -r LOG_DIR="$HOME/Library/Logs/TermAwake"
typeset -r SUDOERS_FILE=/etc/sudoers.d/termawake
typeset -r DOMAIN=gui/$UID

step() { print -r -- ""; print -r -- "【$1】$2"; }
ok()   { print -r -- "   ✅ $*"; }
info() { print -r -- "   ・$*"; }
warn() { print -r -- "   ⚠️  $*"; }
die()  { print -r -- "" >&2; print -r -- "❌ $*" >&2; exit 1; }

usage() {
  print -r -- "用法：./install.sh [--app Terminal|iTerm2] [--battery 0-100]

  --app       要監視的終端機 App（不指定就自動判斷）
  --battery   用電池時，電量低於幾 % 就恢復正常睡眠（預設 20；0 = 關閉）"
}

# 用 root 身分執行一段 sh 指令：
#   在終端機裡執行 → 用 sudo（會在終端機問密碼）
#   沒有終端機時（例如被其他程式呼叫）→ 跳出 macOS 標準的密碼視窗
run_as_root() {  # $1 = sh 指令；$2 = 密碼視窗上的說明文字
  if [[ -t 0 && -t 1 ]]; then
    info "請輸入你的 Mac 登入密碼（打字時畫面不會出現任何東西，這是正常的，打完按 Enter）"
    /usr/bin/sudo -p "   Mac 登入密碼：" /bin/sh -c "$1"
  else
    info "請在跳出來的 macOS 視窗輸入你的 Mac 登入密碼"
    /usr/bin/osascript \
      -e 'on run argv' \
      -e 'do shell script (item 1 of argv) with prompt (item 2 of argv) with administrator privileges' \
      -e 'end run' "$1" "$2" >/dev/null
  fi
}

current_sd() {
  local line
  for line in ${(f)"$(/usr/bin/pmset -g 2>/dev/null)"}; do
    [[ $line =~ '^[[:space:]]*SleepDisabled[[:space:]]+([0-9]+)' ]] && { print -r -- $match[1]; return; }
  done
  print 0
}

# 免密碼規則能不能用？用「目前的值」再設一次來測試 → 不會改變任何東西
sudoers_works() {
  /usr/bin/sudo -k 2>/dev/null   # 先清掉密碼快取，避免剛輸入過密碼造成誤判
  /usr/bin/sudo -n /usr/bin/pmset -a disablesleep $(current_sd) >/dev/null 2>&1
}

normalize_app() {
  case ${(L)1} in
    (terminal|terminal.app|apple_terminal) print Terminal ;;
    (iterm|iterm2|iterm.app|iterm2.app)    print iTerm2 ;;
    (*) [[ $1 == [[:alnum:]._-]## ]] || return 1; print -r -- $1 ;;
  esac
}

# 讀出舊設定檔裡某個 key 的值（重新安裝時保留使用者的設定）
config_value() {
  [[ -r $CONFIG ]] || return 0
  local line
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%\#*}
    [[ ${${line%%=*}//[[:space:]]/} == $1 ]] || continue
    line=${line#*=}
    line=${${line##[[:space:]]#}%%[[:space:]]#}
    print -r -- ${${line#[\"\']}%[\"\']}
    return 0
  done < $CONFIG
}

xml_escape() { local s=$1; s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}; print -r -- $s; }

# 原子化地安裝檔案：先寫暫存檔再改名。正在執行的舊版監視程式不會讀到寫到一半的檔案。
install_file() {  # 來源 目的地 權限
  local tmp="$2.tmp.$$"
  /bin/cp -X -- $1 $tmp && /bin/chmod $3 $tmp && /bin/mv -f -- $tmp $2 || { /bin/rm -f -- $tmp; return 1; }
}

# ---- 參數 ----------------------------------------------------------------------
APP_ARG= BATT_ARG=
while (( $# )); do
  case $1 in
    (--app)       (( $# >= 2 )) || die "--app 後面要接 App 名稱，例如：--app iTerm2"; APP_ARG=$2; shift 2 ;;
    (--app=*)     APP_ARG=${1#*=}; shift ;;
    (--battery)   (( $# >= 2 )) || die "--battery 後面要接數字，例如：--battery 20"; BATT_ARG=$2; shift 2 ;;
    (--battery=*) BATT_ARG=${1#*=}; shift ;;
    (-h|--help)   usage; exit 0 ;;
    (*)           usage >&2; die "看不懂的參數：$1" ;;
  esac
done

print -r -- "TermAwake 安裝程式 —— 只要 Terminal 開著，Mac 就不會睡（合上蓋子也照跑）"

# ---- 0. 檢查環境 ---------------------------------------------------------------
step 0 "檢查環境"
[[ $OSTYPE == darwin* ]] || die "TermAwake 只支援 macOS。"
(( EUID != 0 )) || die "請不要用 sudo 執行。直接執行 ./install.sh 就好，需要密碼時會再問你。"
typeset -r ME=$(/usr/bin/id -un)
# 帳號名稱會寫進 sudoers，必須是單純的字元，避免被插入其他規則
[[ $ME == [A-Za-z_][A-Za-z0-9_.-]# ]] || die "帳號名稱「$ME」含有特殊字元，無法安全地寫進 sudoers。"
[[ " $(/usr/bin/id -Gn) " == *" admin "* ]] || die "你的帳號不是管理員（admin），無法設定 sudo 規則。"
[[ -x /usr/bin/pmset && -x /usr/sbin/visudo ]] || die "找不到 pmset 或 visudo。"
[[ -r $SRC_DIR/bin/termawake && -r $SRC_DIR/uninstall.sh ]] || die "找不到程式檔。請在 TermAwake 資料夾裡執行 ./install.sh"
/bin/zsh -n $SRC_DIR/bin/termawake || die "bin/termawake 有語法錯誤，請重新下載。"
ok "macOS $(/usr/bin/sw_vers -productVersion)，帳號 $ME（管理員）"

# ---- 1. 判斷要監視哪個 App ------------------------------------------------------
step 1 "判斷你用的是哪個終端機 App"
APPS= WHY=
if [[ -n $APP_ARG ]]; then
  for a in ${=APP_ARG}; do
    n=$(normalize_app $a) || die "看不懂的 App 名稱：$a（可用 Terminal 或 iTerm2）"
    APPS+="${APPS:+ }$n"
  done
  WHY="你用 --app 指定的"
elif [[ -n $(config_value APPS) ]]; then
  APPS=$(config_value APPS); WHY="沿用你之前的設定"
else
  case ${TERM_PROGRAM-} in
    (Apple_Terminal) APPS=Terminal; WHY="你現在就是在 Terminal.app 裡執行安裝" ;;
    (iTerm.app)      APPS=iTerm2;   WHY="你現在就是在 iTerm2 裡執行安裝" ;;
    (*)
      if   /usr/bin/pgrep -q -a -x -u $UID iTerm2;   then APPS=iTerm2;   WHY="iTerm2 正在執行"
      elif /usr/bin/pgrep -q -a -x -u $UID Terminal; then APPS=Terminal; WHY="Terminal 正在執行"
      elif [[ -d /Applications/iTerm.app || -d $HOME/Applications/iTerm.app ]]; then APPS=iTerm2; WHY="電腦裡有安裝 iTerm2"
      else APPS=Terminal; WHY="預設使用 macOS 內建的 Terminal"
      fi ;;
  esac
fi
ok "監視：$APPS（$WHY）"
[[ -z $APP_ARG ]] && info "想改成別的 App：./install.sh --app iTerm2"

if [[ -n $BATT_ARG ]]; then
  [[ $BATT_ARG == <0-100> ]] || die "--battery 要是 0 到 100 的數字"
  BATTERY_MIN=$(( 10#$BATT_ARG ))
else
  BATTERY_MIN=$(config_value BATTERY_MIN)
  [[ $BATTERY_MIN == <0-100> ]] || BATTERY_MIN=20
fi
INTERVAL=$(config_value INTERVAL)
[[ $INTERVAL == <1-300> ]] || INTERVAL=5

# ---- 2. 免密碼規則（唯一需要密碼的步驟，所以放最前面）-----------------------
step 2 "設定「只有兩條指令」可以免密碼"
info "要讓 Mac 合上蓋子也不睡，需要用管理員權限執行 pmset。"
info "TermAwake 只會開放下面這兩條「一字不差」的指令免密碼，其他所有 sudo 指令照樣要密碼："
info "    /usr/bin/pmset -a disablesleep 1    （禁止系統睡眠）"
info "    /usr/bin/pmset -a disablesleep 0    （恢復系統睡眠）"
if sudoers_works; then
  ok "規則已經存在而且可以用（$SUDOERS_FILE），這次不用輸入密碼"
else
  ROOT_SCRIPT=$(cat <<EOF
set -e
umask 077
/bin/mkdir -p /etc/sudoers.d
t=/etc/sudoers.d/.termawake.tmp
/bin/cat > "\$t" <<'SUDOERS'
# TermAwake - https://github.com/Jhongwe1/TermAwake
# Lets user "$ME" run EXACTLY these two commands as root without a password.
# Nothing else is allowed: sudo matches the full command line, arguments included.
#   /usr/bin/pmset -a disablesleep 1   -> prevent system sleep (even with the lid closed)
#   /usr/bin/pmset -a disablesleep 0   -> allow system sleep again (the macOS default)
# Remove with:  termawake uninstall    (or: sudo rm /etc/sudoers.d/termawake)
Cmnd_Alias TERMAWAKE_PMSET = /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
$ME ALL = (root) NOPASSWD: TERMAWAKE_PMSET
SUDOERS
/usr/sbin/chown root:wheel "\$t"
/bin/chmod 0440 "\$t"
if ! /usr/sbin/visudo -cf "\$t" >/dev/null; then /bin/rm -f "\$t"; echo "sudoers syntax check failed" >&2; exit 1; fi
/bin/mv -f "\$t" $SUDOERS_FILE
if ! /usr/sbin/visudo -c >/dev/null; then /bin/rm -f $SUDOERS_FILE; echo "full sudoers check failed, rolled back" >&2; exit 1; fi
EOF
)
  # 檔名刻意不含「.」：macOS 的 sudo 會「忽略」sudoers.d 裡檔名有點的檔案（例如 termawake.conf）
  run_as_root "$ROOT_SCRIPT" "TermAwake 要建立免密碼規則：只允許 pmset -a disablesleep 0 和 1 這兩條指令。" ||
    die "沒有完成（可能是取消了密碼視窗，或密碼錯誤）。到目前為止沒有任何東西被修改，可以再執行一次 ./install.sh。"
  sudoers_works || die "規則寫進去了，但測試時還是需要密碼。請把畫面上的訊息貼到 GitHub Issues。"
  ok "已建立 $SUDOERS_FILE（擁有者 root:wheel、權限 0440、通過 visudo 語法檢查）"
fi
/usr/bin/sudo -k 2>/dev/null
if /usr/bin/sudo -n /usr/bin/pmset -g >/dev/null 2>&1; then
  warn "其他 pmset 指令竟然也不用密碼——你的 sudo 設定裡可能本來就有其他免密碼規則。"
else
  ok "確認：其他指令（例如 sudo pmset -g）仍然需要密碼"
fi

# ---- 3. 安裝檔案 ----------------------------------------------------------------
step 3 "安裝程式檔案"
/bin/mkdir -p -- $APP_DIR $LOG_DIR ${LINK:h} ${PLIST:h} || die "無法建立資料夾。"
install_file $SRC_DIR/bin/termawake $BIN 755 || die "無法複製程式到 $APP_DIR"
install_file $SRC_DIR/uninstall.sh "$APP_DIR/uninstall.sh" 755 || die "無法複製移除程式。"
ok "程式：~/Library/Application Support/TermAwake/termawake"
info "（不放在桌面或「文件」：macOS 會擋背景程式讀取那些資料夾）"

# 蓋子事件小幫手（src/lidwatch.c）：合上蓋子會立刻關螢幕，平常完全不用輪詢。
# 需要 Xcode 命令列工具才能編譯；沒有的話退回「每 INTERVAL 秒檢查一次蓋子」。
# 先用 xcode-select -p 檢查：直接呼叫 cc 在沒裝工具的電腦上會跳出安裝視窗。
LIDWATCH="$APP_DIR/lidwatch"
LW_LOG="$LOG_DIR/lidwatch-build.log"
if [[ ! -r $SRC_DIR/src/lidwatch.c ]]; then
  /bin/rm -f -- $LIDWATCH
  warn "找不到 src/lidwatch.c → 合上蓋子後最多 ${INTERVAL} 秒才關螢幕"
elif ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  /bin/rm -f -- $LIDWATCH
  warn "沒有 Xcode 命令列工具 → 合上蓋子後最多 ${INTERVAL} 秒才關螢幕"
  info "想要合蓋立刻關螢幕：執行 xcode-select --install，裝好後重新執行 ./install.sh"
else
  LW_TMP="$LIDWATCH.tmp.$$"
  if /usr/bin/xcrun cc -O2 -Wall -Wextra -framework IOKit -framework CoreFoundation \
       -o $LW_TMP $SRC_DIR/src/lidwatch.c 2>$LW_LOG; then
    # 自我測試：要能成功向系統登記並持續等待（登記失敗的話會馬上自己結束）
    $LW_TMP >/dev/null 2>>$LW_LOG &
    lw_pid=$!
    /bin/sleep 1
    if kill -0 $lw_pid 2>/dev/null; then
      kill $lw_pid 2>/dev/null; wait $lw_pid 2>/dev/null
      /bin/mv -f -- $LW_TMP $LIDWATCH
      ok "蓋子事件小幫手：已編譯並通過自我測試（合上蓋子會立刻關螢幕，平常不用輪詢）"
    else
      wait $lw_pid 2>/dev/null
      /bin/rm -f -- $LW_TMP $LIDWATCH
      warn "蓋子事件小幫手無法啟動 → 合上蓋子後最多 ${INTERVAL} 秒才關螢幕（原因見 ~/Library/Logs/TermAwake/lidwatch-build.log）"
    fi
  else
    /bin/rm -f -- $LW_TMP $LIDWATCH
    warn "蓋子事件小幫手編譯失敗 → 合上蓋子後最多 ${INTERVAL} 秒才關螢幕（原因見 ~/Library/Logs/TermAwake/lidwatch-build.log）"
  fi
fi

if [[ -e $LINK && ! -L $LINK ]]; then
  warn "$LINK 已經有別的檔案，不覆蓋它。請改用完整路徑執行 termawake。"
else
  /bin/ln -sfn -- $BIN $LINK && ok "指令：termawake（捷徑在 ~/.local/bin/termawake）"
fi

CONFIG_TMP="$CONFIG.tmp.$$"
cat > $CONFIG_TMP <<EOF
# TermAwake 設定檔 —— 改完存檔，幾秒內就會自動生效（不用重開機）
# 以 # 開頭的是說明文字，不會被讀取。

# 要監視的終端機 App（程序名稱）：Terminal 或 iTerm2；兩個都要就寫成 Terminal iTerm2
APPS=$APPS

# 用電池時，電量「低於」這個百分比就恢復正常睡眠（0 到 100；0 = 關閉低電量保護）
BATTERY_MIN=$BATTERY_MIN

# 每幾秒檢查一次（1 到 300）
INTERVAL=$INTERVAL
EOF
/bin/mv -f -- $CONFIG_TMP $CONFIG || die "無法寫入設定檔。"
ok "設定：監視 $APPS、電池低於 ${BATTERY_MIN}% 恢復睡眠、每 ${INTERVAL} 秒檢查"

# ---- 4. 設定登入時自動啟動（launchd）--------------------------------------------
step 4 "設定監視程式（登入時自動啟動、當掉自動重開）"
PLIST_TMP="$PLIST.tmp.$$"
cat > $PLIST_TMP <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>-f</string>
		<string>$(xml_escape $BIN)</string>
		<string>run</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>10</integer>
	<key>ProcessType</key>
	<string>Background</string>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
	<key>StandardOutPath</key>
	<string>$(xml_escape $LOG_DIR/launchd.log)</string>
	<key>StandardErrorPath</key>
	<string>$(xml_escape $LOG_DIR/launchd.log)</string>
</dict>
</plist>
EOF
/usr/bin/plutil -lint -s $PLIST_TMP || { /bin/rm -f $PLIST_TMP; die "launchd 設定檔格式錯誤。"; }
/bin/mv -f -- $PLIST_TMP $PLIST

if /bin/launchctl print $DOMAIN/$LABEL >/dev/null 2>&1; then
  info "發現舊版監視程式 → 先停止它（它會先把睡眠設定改回來）"
  /bin/launchctl bootout $DOMAIN/$LABEL 2>/dev/null
  for i in {1..50}; do /bin/launchctl print $DOMAIN/$LABEL >/dev/null 2>&1 || break; /bin/sleep 0.2; done
fi
/bin/rm -f -- $STATE_FILE
/bin/launchctl enable $DOMAIN/$LABEL 2>/dev/null
loaded=0
for i in {1..5}; do
  if /bin/launchctl bootstrap $DOMAIN $PLIST 2>/dev/null; then loaded=1; break; fi
  /bin/sleep 1
done
(( loaded )) || die "無法載入 launchd 服務（launchctl bootstrap 失敗）。可以登出再登入後重新執行 ./install.sh。"
ok "已載入 launchd 服務：$LABEL"

# ---- 5. 確認 --------------------------------------------------------------------
step 5 "確認是否生效"
for i in {1..40}; do
  [[ -r $STATE_FILE && $(<$STATE_FILE) != "" ]] && break
  /bin/sleep 0.25
done
/bin/zsh -f $BIN status

print -r -- "🎉 安裝完成！以後什麼都不用做："
print -r -- "   打開 $APPS → 幾秒內自動防睡眠；完全結束 $APPS（⌘Q）→ 自動恢復原本的睡眠設定。"
print -r -- ""
print -r -- "   常用指令：termawake（看狀態）、termawake pause（暫停）、termawake resume（恢復）"
print -r -- "   完全移除：termawake uninstall"
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  print -r -- ""
  warn "~/.local/bin 不在你的 PATH 裡，所以暫時無法直接輸入 termawake。"
  info "解法：執行  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc  然後開一個新的 Terminal 視窗"
fi
