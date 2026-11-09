#!/bin/zsh -f
# =============================================================================
#  TermAwake 自動測試
#    用假的 pmset / sudo / pgrep / ioreg / system_profiler 模擬各種情況。
#    完全不會動到你真正的睡眠設定，也不需要密碼。
#    執行：zsh tests/run-tests.zsh
# =============================================================================
emulate -R zsh
setopt no_unset pipe_fail
zmodload zsh/datetime

ROOT=${0:A:h:h}
TA=$ROOT/bin/termawake
T=$(mktemp -d "${TMPDIR:-/tmp}/termawake-test.XXXXXX") || exit 1
T=${T:A}
typeset -g PASS=0 FAIL=0 W_PID= rc=0

cleanup() {
  [[ -n $W_PID ]] && kill -9 $W_PID 2>/dev/null
  rm -rf -- $T
}
trap cleanup EXIT

mkdir -p $T/bin $T/state $T/logs

# ---- 假的 pmset：把 SleepDisabled 存在 $T/sd，所有呼叫記在 $T/calls ----------
cat > $T/bin/pmset <<'EOF'
#!/bin/zsh -f
T=${0:A:h:h}
case "$*" in
  ('-g')
    print 'System-wide power settings:'
    [[ $(<$T/sd) == 1 ]] && print ' SleepDisabled\t\t1'
    print 'Currently in use:'
    print ' sleep                1' ;;
  ('-g batt') print -r -- "$(<$T/batt)" ;;
  ('-a disablesleep 0'|'-a disablesleep 1')
    [[ ${FAKE_ROOT-} == 1 ]] || { print -u2 'pmset: must be run as root'; exit 1; }
    print -r -- $3 >| $T/sd
    print -r -- "disablesleep $3" >> $T/calls ;;
  ('sleepnow') print sleepnow >> $T/calls ;;
  ('displaysleepnow') print displaysleepnow >> $T/calls ;;
  (*) print -r -- "UNEXPECTED pmset $*" >> $T/calls; exit 1 ;;
esac
EOF

# ---- 假的 sudo：模擬 sudoers，只放行「剛好」這兩條指令 ---------------------------
cat > $T/bin/sudo <<'EOF'
#!/bin/zsh -f
T=${0:A:h:h}
[[ -e $T/sudo_broken ]] && { print -r -- "BROKEN sudo $*" >> $T/calls; print -u2 'sudo: a password is required'; exit 1; }
if [[ $# == 5 && $1 == -n && $2 == $T/bin/pmset && $3 == -a && $4 == disablesleep && ( $5 == 0 || $5 == 1 ) ]]; then
  FAKE_ROOT=1 exec $T/bin/pmset -a disablesleep $5
fi
print -r -- "DENIED sudo $*" >> $T/calls
exit 1
EOF

# ---- 假的 pgrep：$T/app_running 存在 = Terminal 開著；同時檢查旗標 -a -x -u -----
cat > $T/bin/pgrep <<'EOF'
#!/bin/zsh -f
T=${0:A:h:h}
typeset a=0 x=0 u=0 name=
for arg in "$@"; do
  case $arg in (-a) a=1;; (-x) x=1;; (-u) u=1;; (-*) ;; (*) name=$arg;; esac
done
(( a && x && u )) || { print -r -- "BADFLAGS pgrep $*" >> $T/calls; exit 2; }
[[ $name == FakeTermApp && -e $T/app_running ]] && exit 0
exit 1
EOF

# ---- 假的 ioreg：蓋子狀態放在 $T/lid（Yes/No）-----------------------------------
cat > $T/bin/ioreg <<'EOF'
#!/bin/zsh -f
T=${0:A:h:h}
print '+-o IOPMrootDomain  <class IOPMrootDomain>'
print '    {'
print '      "AppleClamshellCausesSleep" = No'
print "      \"AppleClamshellState\" = $(<$T/lid)"
print '    }'
EOF

# ---- 假的 system_profiler：螢幕清單放在 $T/displays.json --------------------------
cat > $T/bin/system_profiler <<'EOF'
#!/bin/zsh -f
T=${0:A:h:h}
print -r -- "$(<$T/displays.json)"
EOF
chmod +x $T/bin/*

INTERNAL_ONLY='{"SPDisplaysDataType":[{"_name":"Apple M5","spdisplays_ndrvs":[{"_name":"Color LCD","spdisplays_connection_type":"spdisplays_internal","spdisplays_main":"spdisplays_yes"}]}]}'
WITH_EXTERNAL='{"SPDisplaysDataType":[{"_name":"Apple M5","spdisplays_ndrvs":[{"_name":"Color LCD","spdisplays_connection_type":"spdisplays_internal"},{"_name":"DELL U2720Q","spdisplays_online":"spdisplays_yes"}]}]}'

ENVV=(
  TERMAWAKE_STATE_DIR=$T/state TERMAWAKE_LOG_DIR=$T/logs
  TERMAWAKE_PMSET=$T/bin/pmset TERMAWAKE_SUDO=$T/bin/sudo TERMAWAKE_PGREP=$T/bin/pgrep
  TERMAWAKE_IOREG=$T/bin/ioreg TERMAWAKE_SYSTEM_PROFILER=$T/bin/system_profiler
  TERMAWAKE_TICK=0.2
)
ta()            { env $ENVV /bin/zsh -f $TA "$@"; }
start_watcher() { env $ENVV /bin/zsh -f $TA run >> $T/watcher.out 2>&1 & W_PID=$!; }
# 活著（而且不是 zombie）嗎？kill -0 對還沒被回收的 zombie 也會回報成功，不能用
alive()         { local s; s=$(ps -o stat= -p $1 2>/dev/null) || return 1; [[ $s != Z* ]]; }
stop_watcher()  {
  [[ -n $W_PID ]] || return 0
  kill -${1:-TERM} $W_PID 2>/dev/null
  local deadline=$(( EPOCHREALTIME + 5 ))
  while alive $W_PID && (( EPOCHREALTIME < deadline )); do sleep 0.05; done
  if alive $W_PID; then fail "監視程式收到 ${1:-TERM} 後 5 秒內沒有結束"; kill -9 $W_PID 2>/dev/null; fi
  wait $W_PID 2>/dev/null
  W_PID=
}

sd()        { print -r -- "$(<$T/sd)"; }
marker()    { [[ -e $T/state/engaged ]]; }
# 計算 $T/calls 裡「整行等於 $1」的次數（grep 沒找到時 exit 1，但仍會印出 0）
count()     { local n=0; [[ -e $T/calls ]] && n=$(grep -c -x -- "$1" $T/calls); print -r -- ${n:-0}; }
grepc()     { local n=0; [[ -e $T/calls ]] && n=$(grep -c -- "$1" $T/calls); print -r -- ${n:-0}; }
logged()    { grep -q -- "$1" $T/logs/termawake.log 2>/dev/null; }
app_on()    { : > $T/app_running; }
app_off()   { rm -f $T/app_running; }
lid()       { print -r -- $1 >| $T/lid; }
displays()  { print -r -- $1 >| $T/displays.json; }
set_batt()  { # 百分比 狀態 來源
  print -r -- "Now drawing from '$3'
 -InternalBattery-0 (id=1234)	$1%; $2; 3:00 remaining present: true" >| $T/batt
}
reset_world() {
  stop_watcher KILL
  rm -rf $T/state/* $T/logs/* $T/calls $T/sudo_broken $T/app_running
  print 0 >| $T/sd; lid No; displays $INTERNAL_ONLY
  set_batt 80 charging 'AC Power'
  print -l 'APPS=FakeTermApp' 'BATTERY_MIN=20' 'INTERVAL=1' >| $T/state/config
}

# 在 $1 秒內等到條件成立
wait_for() {
  local deadline=$(( EPOCHREALTIME + $1 )); shift
  while (( EPOCHREALTIME < deadline )); do eval "$*" && return 0; sleep 0.05; done
  eval "$*"
}
pass() { PASS=$(( PASS + 1 )); print -r -- "  ✅ $1"; }
fail() { FAIL=$(( FAIL + 1 )); print -r -- "  ❌ $1"; }
# check 說明 條件：3 秒內要成立
check() { local d=$1; shift; if wait_for 3 "$*"; then pass "$d"; else fail "$d   〔條件：$*｜sd=$(sd)〕"; fi; }
# stays 說明 秒數 條件：這段時間內一直成立
stays() {
  local d=$1 secs=$2; shift 2
  local deadline=$(( EPOCHREALTIME + secs ))
  while (( EPOCHREALTIME < deadline )); do
    eval "$*" || { fail "$d   〔中途不成立：$*｜sd=$(sd)〕"; return; }
    sleep 0.05
  done
  pass "$d"
}
section() { print; print -r -- "▌$*"; }

print "TermAwake 自動測試（暫存目錄：$T）"

section "1. Terminal 沒開 → 什麼都不做"
reset_world; start_watcher
stays "SleepDisabled 維持 0、沒有標記檔" 1 '[[ $(sd) == 0 ]] && ! marker'

section "2. 打開 Terminal → 禁止睡眠"
app_on
check "SleepDisabled 變成 1" '[[ $(sd) == 1 ]]'
check "寫了標記檔" 'marker'
check "status 回報生效中" '[[ $(<$T/state/state) == engaged ]]'

section "3. 開很多個 Terminal 視窗也只會有一個監視程式"
env $ENVV /bin/zsh -f $TA run > $T/second.out 2>&1 &
p2=$!
wait_for 3 '! alive $p2'
if alive $p2; then kill -9 $p2; rc=999; else wait $p2; rc=$?; fi
check "第二個監視程式拒絕啟動（exit 75）" '(( rc == 75 ))'
check "而且沒有動到第一個的狀態" '[[ $(sd) == 1 ]] && marker'

section "4. 用電池、電量低於 20% → 恢復睡眠"
set_batt 19 discharging 'Battery Power'
check "SleepDisabled 回到 0" '[[ $(sd) == 0 ]]'
check "標記檔刪掉" '! marker'
check "蓋子開著 → 不會強制睡眠" '(( $(count sleepnow) == 0 ))'
check "status 回報低電量" '[[ $(<$T/state/state) == low-battery ]]'

section "5. 低電量鎖定：還在用電池就不會再啟用，接上電源才會"
set_batt 25 discharging 'Battery Power'
stays "電量變 25%（仍用電池）→ 維持 0" 1 '[[ $(sd) == 0 ]]'
set_batt 25 charging 'AC Power'
check "接上電源 → 重新禁止睡眠" '[[ $(sd) == 1 ]]'
set_batt 30 discharging 'Battery Power'
stays "拔掉電源、電量 30%（≥ 20%）→ 繼續禁止睡眠" 1 '[[ $(sd) == 1 ]]'
set_batt 19 charging 'AC Power'
stays "插著電源時就算 19% 也繼續（不會耗電）" 1 '[[ $(sd) == 1 ]]'
set_batt 19 discharging 'AC Power'
check "插著電但還在掉電（充電器瓦數不夠）+ 19% → 恢復睡眠" '[[ $(sd) == 0 ]]'

section "6. 蓋子合著 + 低電量 + 沒接外接螢幕 → 立刻讓 Mac 睡"
set_batt 80 charging 'AC Power'
check "（先接電源恢復禁止睡眠）" '[[ $(sd) == 1 ]]'
lid Yes; displays $INTERNAL_ONLY
set_batt 15 discharging 'Battery Power'
check "SleepDisabled 回到 0" '[[ $(sd) == 0 ]]'
check "呼叫了 pmset sleepnow" '(( $(count sleepnow) == 1 ))'

section "7. 蓋子合著 + 有外接螢幕（桌面模式）→ 不強制睡眠"
set_batt 80 charging 'AC Power'
check "（接電源 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
displays $WITH_EXTERNAL
app_off
check "Terminal 結束 → SleepDisabled 回到 0" '[[ $(sd) == 0 ]]'
stays "有外接螢幕 → 沒有呼叫 sleepnow" 0.6 '(( $(count sleepnow) == 1 ))'

section "8. 蓋子合著 + 沒外接螢幕 + Terminal 結束 → 立刻睡"
displays $INTERNAL_ONLY; app_on
check "（Terminal 開 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
app_off
check "SleepDisabled 回到 0" '[[ $(sd) == 0 ]]'
check "呼叫了 pmset sleepnow" '(( $(count sleepnow) == 2 ))'
lid No

section "9. 暫停 / 恢復"
app_on
check "（Terminal 開 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
out=$(ta pause)
check "termawake pause → 馬上恢復睡眠" '[[ $(sd) == 0 ]] && ! marker'
stays "暫停期間不會被改回去" 0.8 '[[ $(sd) == 0 ]]'
out=$(ta resume)
check "termawake resume → 馬上再禁止睡眠" '[[ $(sd) == 1 ]]'
out=$(ta pause)
check "（再暫停一次）" '[[ $(sd) == 0 ]]'
app_off
check "Terminal 結束 → 暫停自動解除" '[[ ! -e $T/state/paused ]]'
app_on
check "重新打開 Terminal → 自動禁止睡眠" '[[ $(sd) == 1 ]]'

section "10. 上一次開機留下的暫停 → 自動失效"
print 'boot=1' >| $T/state/paused
check "舊的暫停被清掉" '[[ ! -e $T/state/paused ]]'
stays "繼續禁止睡眠" 0.6 '[[ $(sd) == 1 ]]'

section "11. 正常結束（登出/關機/停止服務的 TERM 訊號）→ 一定先恢復"
lid Yes
before=$(count sleepnow)
stop_watcher TERM
check "SleepDisabled 回到 0" '[[ $(sd) == 0 ]]'
check "標記檔刪掉" '! marker'
check "結束時不會強制睡眠（可能正在關機）" '(( $(count sleepnow) == before ))'
lid No

section "12. HUP 訊號（例如終端機斷線）也一樣會恢復"
# 註：INT/QUIT 無法在這裡測——從 script 用 & 放到背景的程式，POSIX 規定會忽略這兩個訊號。
#     launchd 啟動的監視程式不受影響，trap 一樣有設。
start_watcher
check "（先禁止睡眠）" '[[ $(sd) == 1 ]]'
stop_watcher HUP
check "收到 HUP → SleepDisabled 回到 0" '[[ $(sd) == 0 ]] && ! marker'

section "13. kill -9（無法攔截）→ 重新啟動後自動收拾"
start_watcher
check "（先禁止睡眠）" '[[ $(sd) == 1 ]]'
stop_watcher KILL
check "被 kill -9 後設定還是 1、標記還在（這是預期的）" '[[ $(sd) == 1 ]] && marker'
app_off
start_watcher
check "重新啟動時 Terminal 已關 → 自動改回 0" '[[ $(sd) == 0 ]] && ! marker'
check "紀錄檔有 RECOVER" 'logged RECOVER'

section "14. kill -9 後 Terminal 還開著 → 直接接手，不會多切換一次"
app_on
check "（先禁止睡眠）" '[[ $(sd) == 1 ]]'
n1=$(count 'disablesleep 1'); n0=$(count 'disablesleep 0')
stop_watcher KILL
start_watcher
check "紀錄檔有 ADOPT" 'logged ADOPT'
stays "維持 1，而且沒有多呼叫 pmset" 0.8 '[[ $(sd) == 1 ]] && (( $(count "disablesleep 1") == n1 && $(count "disablesleep 0") == n0 ))'

section "15. SleepDisabled 原本就是 1（不是我們設的）→ 完全不碰"
reset_world
print 1 >| $T/sd
app_on; start_watcher
check "紀錄檔說明不是 TermAwake 設的" 'logged "不是 TermAwake 設的"'
app_off
stays "Terminal 關掉也維持 1、沒有任何 pmset 呼叫" 0.8 '[[ $(sd) == 1 ]] && (( $(count "disablesleep 0") + $(count "disablesleep 1") == 0 ))'

section "16. 免密碼規則壞掉 → 不留標記、不亂改，修好後自動恢復運作"
reset_world
: > $T/sudo_broken
app_on; start_watcher
# 註：每次嘗試時標記檔會「先寫、失敗再刪」，存在幾毫秒是設計（當機安全的順序），所以只檢查最後結果
stays "SleepDisabled 一直維持 0" 0.8 '[[ $(sd) == 0 ]]'
check "失敗後不會留下標記檔" '! marker'
n1=$(grepc "^BROKEN"); sleep 1.0; n2=$(grepc "^BROKEN")
check "失敗後會退避：1 秒內最多重試 1 次（沒退避的話會是 5 次）" '(( n2 - n1 <= 1 ))'
check "紀錄檔有錯誤說明" 'logged "免密碼規則"'
check "status 回報啟用失敗" '[[ $(<$T/state/state) == error-engage ]]'
rm -f $T/sudo_broken
check "規則修好 → 自動禁止睡眠" '[[ $(sd) == 1 ]]'

section "17. 設定檔改了不用重開，而且亂寫的值會被忽略"
print -l 'APPS=FakeTermApp' 'BATTERY_MIN=90' 'INTERVAL=1' >| $T/state/config
set_batt 85 discharging 'Battery Power'
check "門檻改成 90% → 85% 用電池就恢復睡眠" '[[ $(sd) == 0 ]]'
print -l 'APPS=FakeTermApp' 'BATTERY_MIN=20' 'INTERVAL=1' >| $T/state/config
check "門檻改回 20%（仍用電池）→ 立刻用新門檻重新判斷，不必等接電源" '[[ $(sd) == 1 ]]'
print -l 'APPS=FakeTermApp' 'BATTERY_MIN=abc' 'INTERVAL=0' >| $T/state/config
set_batt 85 charging 'AC Power'
check "錯誤的值被忽略，改用預設值繼續運作" '[[ $(sd) == 1 ]] && logged "電池門檻 20%"'
print -l "APPS=FakeTermApp; touch $T/pwned" 'BATTERY_MIN=20' >| $T/state/config
check "想夾帶指令的 APPS 被拒絕，退回預設的 Terminal" 'logged "監視 Terminal、"'
stays "夾帶的指令沒有被執行" 0.6 '[[ ! -e $T/pwned ]]'
print -l 'APPS=FakeTermApp' 'BATTERY_MIN=20' >| $T/state/config
check "（恢復正常設定）" '[[ $(sd) == 1 ]]'

section "18. 防睡眠時合上蓋子 → 主動關螢幕（這時 macOS 不會自己關）"
reset_world
app_on; start_watcher
check "（Terminal 開 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
lid Yes
check "合上蓋子 → 呼叫 pmset displaysleepnow 關螢幕" '(( $(count displaysleepnow) == 1 ))'
stays "蓋子一直合著 → 只關一次，不會一直呼叫" 0.8 '(( $(count displaysleepnow) == 1 ))'
check "Mac 仍然不睡（SleepDisabled 維持 1）" '[[ $(sd) == 1 ]]'
lid No; sleep 0.5; lid Yes
check "打開再合上 → 再關一次" '(( $(count displaysleepnow) == 2 ))'
lid No; displays $WITH_EXTERNAL; sleep 0.5; lid Yes
stays "接著外接螢幕時合上（桌面模式）→ 不關螢幕" 0.8 '(( $(count displaysleepnow) == 2 ))'
lid No; displays $INTERNAL_ONLY; sleep 0.5
out=$(ta pause); lid Yes
stays "暫停時合上蓋子 → 不插手（交給 macOS 正常睡眠）" 0.8 '(( $(count displaysleepnow) == 2 ))'
lid No; out=$(ta resume)
check "（取消暫停 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
stop_watcher TERM
# 用 3 秒的完整檢查間隔，確認蓋子是「每秒」檢查，而不是等到下一次完整檢查
env $ENVV TERMAWAKE_TICK=3 /bin/zsh -f $TA run >> $T/watcher.out 2>&1 & W_PID=$!
check "（完整檢查間隔 3 秒的監視程式：禁止睡眠）" '[[ $(sd) == 1 ]]'
sleep 0.3; n=$(count displaysleepnow); lid Yes
if wait_for 1.8 '(( $(count displaysleepnow) == n + 1 ))'; then
  pass "合上蓋子 1.8 秒內就關螢幕（不用等 3 秒一次的完整檢查）"
else
  fail "合上蓋子 1.8 秒內沒有關螢幕（蓋子沒有每秒檢查）"
fi
lid No
stop_watcher TERM

section "19. 安全檢查"
stop_watcher TERM
check "全程只用過允許的兩條 sudo 指令" '(( $(grepc "^DENIED") == 0 ))'
check "pgrep 每次都有帶 -a -x -u" '(( $(grepc "^BADFLAGS") == 0 ))'
check "沒有呼叫任何預期外的 pmset 指令" '(( $(grepc "^UNEXPECTED") == 0 ))'

section "20. 各個指令都能正常執行"
for c in status config version help log; do
  ta $c > /dev/null 2>&1; rc=$?
  check "termawake $c" '(( rc == 0 ))'
done
ta nonsense > /dev/null 2>&1; rc=$?
check "不認識的指令會回報錯誤" '(( rc == 64 ))'

print
print -r -- "結果：通過 $PASS 項，失敗 $FAIL 項"
(( FAIL == 0 ))
