#!/bin/zsh -f
# =============================================================================
#  TermAwake 移除程式
#    termawake uninstall     （安裝後任何地方都能執行）
#    或在 TermAwake 資料夾裡：./uninstall.sh
#
#  會做的事：停止監視程式 → 確認睡眠設定已恢復 → 刪除所有檔案 → 刪除免密碼規則
# =============================================================================
emulate -R zsh
setopt no_unset pipe_fail extended_glob

typeset -r LABEL=io.github.jhongwe1.termawake
typeset -r APP_DIR="$HOME/Library/Application Support/TermAwake"
typeset -r BIN="$APP_DIR/termawake"
typeset -r MARKER="$APP_DIR/engaged"
typeset -r LOCK_FILE="$APP_DIR/watcher.lock"
typeset -r LINK="$HOME/.local/bin/termawake"
typeset -r PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
typeset -r LOG_DIR="$HOME/Library/Logs/TermAwake"
typeset -r SUDOERS_FILE=/etc/sudoers.d/termawake
typeset -r DOMAIN=gui/$UID
zmodload zsh/system

step() { print -r -- ""; print -r -- "【$1】$2"; }
ok()   { print -r -- "   ✅ $*"; }
info() { print -r -- "   ・$*"; }
warn() { print -r -- "   ⚠️  $*"; }

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

watcher_gone() {
  local fd
  [[ -e $LOCK_FILE ]] || return 0
  zsystem flock -t 0 -f fd $LOCK_FILE 2>/dev/null || return 1
  zsystem flock -u $fd
  return 0
}

print -r -- "TermAwake 移除程式"

# ---- 1. 停止監視程式 ------------------------------------------------------------
step 1 "停止監視程式（它結束前會先把睡眠設定改回來）"
if /bin/launchctl print $DOMAIN/$LABEL >/dev/null 2>&1; then
  /bin/launchctl bootout $DOMAIN/$LABEL 2>/dev/null
  for i in {1..50}; do /bin/launchctl print $DOMAIN/$LABEL >/dev/null 2>&1 || break; /bin/sleep 0.2; done
fi
for i in {1..50}; do watcher_gone && break; /bin/sleep 0.2; done
if watcher_gone; then ok "監視程式已停止"; else warn "監視程式好像還在執行（可能是手動執行的 termawake run），請先把它關掉"; fi

# ---- 2. 確認睡眠設定 ------------------------------------------------------------
step 2 "確認睡眠設定已經恢復"
NEED_ROOT_RESTORE=0
if [[ -e $MARKER ]]; then
  # 標記檔還在 = TermAwake 設的 SleepDisabled=1 還沒改回來
  if /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 >/dev/null 2>&1; then
    /bin/rm -f -- $MARKER
    ok "已把 SleepDisabled 改回 0"
  else
    NEED_ROOT_RESTORE=1
    warn "免密碼規則無法使用，等一下輸入密碼時會一起改回來"
  fi
fi
if (( ! NEED_ROOT_RESTORE )); then
  case $(current_sd) in
    (0) ok "SleepDisabled = 0（macOS 預設：正常睡眠）" ;;
    (*) info "SleepDisabled = 1，但這不是 TermAwake 設的（安裝前就是這樣，或是你自己設的）→ 保持原樣不動" ;;
  esac
fi

# ---- 3. 刪除檔案 ----------------------------------------------------------------
step 3 "刪除 TermAwake 的檔案"
/bin/rm -f -- $PLIST && info "已刪除 ~/Library/LaunchAgents/$LABEL.plist"
if [[ -L $LINK && $(/usr/bin/readlink $LINK) == $BIN ]]; then
  /bin/rm -f -- $LINK && info "已刪除 ~/.local/bin/termawake"
fi
/bin/rm -rf -- $APP_DIR && info "已刪除 ~/Library/Application Support/TermAwake/"
/bin/rm -rf -- $LOG_DIR && info "已刪除 ~/Library/Logs/TermAwake/"
ok "檔案都刪除了"

# ---- 4. 刪除免密碼規則 ----------------------------------------------------------
step 4 "刪除免密碼規則（需要輸入密碼）"
ROOT_CMD="/bin/rm -f $SUDOERS_FILE /etc/sudoers.d/.termawake.tmp"
(( NEED_ROOT_RESTORE )) && ROOT_CMD="/usr/bin/pmset -a disablesleep 0; $ROOT_CMD"
if [[ -e $SUDOERS_FILE ]] || (( NEED_ROOT_RESTORE )); then
  if run_as_root "$ROOT_CMD" "TermAwake 要刪除它建立的免密碼規則（/etc/sudoers.d/termawake）。"; then
    (( NEED_ROOT_RESTORE )) && ok "已把 SleepDisabled 改回 0"
  else
    warn "沒有完成（可能是取消了密碼視窗）。之後可以手動執行："
    (( NEED_ROOT_RESTORE )) && info "    sudo pmset -a disablesleep 0"
    info "    sudo rm $SUDOERS_FILE"
  fi
fi
if [[ -e $SUDOERS_FILE ]]; then
  warn "$SUDOERS_FILE 還在"
else
  ok "免密碼規則已刪除（sudo 回到原本的樣子）"
fi

# ---- 完成 ----------------------------------------------------------------------
print -r -- ""
if [[ ! -e $SUDOERS_FILE && ! -e $PLIST && ! -e $APP_DIR ]]; then
  print -r -- "🧹 TermAwake 已完全移除。目前的 SleepDisabled = $(current_sd)。"
else
  print -r -- "⚠️  大部分已移除，但有上面標示 ⚠️ 的項目需要你手動處理。"
fi
