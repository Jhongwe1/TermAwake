#!/bin/zsh -f
# =============================================================================
#  TermAwake 自動測試
#    用假的 pmset / sudo / 感測小幫手 / 通知程式模擬各種情況。
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
typeset -gA SENS

cleanup() {
  [[ -n $W_PID ]] && kill -9 $W_PID 2>/dev/null
  pkill -f -- "$T/bin/" 2>/dev/null
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
  ('-g assertions')
    print 'Listed by owning process:'
    print '   pid 999(caffeinate): [0x1] 00:00:01 PreventUserIdleSystemSleep named: "caffeinate command-line tool"' ;;
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
[[ -e $T/sudo_hang ]] && { print -r -- "HANG sudo $*" >> $T/calls; exec /bin/sleep 30; }
if [[ $# == 5 && $1 == -n && $2 == $T/bin/pmset && $3 == -a && $4 == disablesleep && ( $5 == 0 || $5 == 1 ) ]]; then
  FAKE_ROOT=1 exec $T/bin/pmset -a disablesleep $5
fi
print -r -- "DENIED sudo $*" >> $T/calls
exit 1
EOF

# ---- 假的感測小幫手：把 $T/sensors 當成目前狀態，內容一變就印一行（模擬事件）---------
#      sd 欄位讀 $T/sd（= 假 pmset 存的值），就像真的小幫手讀核心的 SleepDisabled
cat > $T/bin/tawatch <<'EOF'
#!/bin/zsh -f
T=${0:A:h:h}
zmodload zsh/datetime zsh/zselect
gen=0 parent=0 tick=60 once=0 cfg=/dev/null
print -r -- "$*" >> $T/helper_args
while (( $# )); do
  case $1 in
    (--gen) gen=$2; shift 2 ;; (--parent) parent=$2; shift 2 ;; (--tick) tick=$2; shift 2 ;;
    (--config) cfg=$2; shift 2 ;; (--apps) shift 2 ;; (--once) once=1; shift ;; (*) shift ;;
  esac
done
line() { print -r -- "S1 gen=$gen pid=$$ why=$1 seq=0 $(<$T/sensors) sd=$(<$T/sd)"; }
if (( once )); then line once; exit 0; fi
[[ -e $T/helper_crash ]] && exit 3
force=1
trap 'force=1' USR1
last= next=$(( EPOCHREALTIME + tick )) lastcfg=$(<$cfg 2>/dev/null)
while true; do
  kill -0 $parent 2>/dev/null && kill -0 $PPID 2>/dev/null || exit 0
  # 和真的小幫手一樣：設定檔一改就通知（why=config）
  curcfg=$(<$cfg 2>/dev/null)
  if [[ $curcfg != $lastcfg ]]; then lastcfg=$curcfg; [[ -e $T/helper_mute ]] || line config || exit 0; fi
  cur="$(<$T/sensors) sd=$(<$T/sd)"
  if [[ ! -e $T/helper_mute ]] && [[ $cur != $last ]] || (( force || EPOCHREALTIME >= next )); then
    if [[ ! -e $T/helper_mute ]]; then
      line event || exit 0
      last=$cur
    fi
    force=0
    (( EPOCHREALTIME >= next )) && next=$(( EPOCHREALTIME + tick ))
  fi
  zselect -t 3
done
EOF

# ---- 假的通知程式：把訊息記下來 -------------------------------------------------------
cat > $T/bin/notifier <<'EOF'
#!/bin/zsh -f
T=${0:A:h:h}
print -r -- "NOTIFY ${@[-1]}" >> $T/notified
EOF
chmod +x $T/bin/*

ENVV=(
  TERMAWAKE_STATE_DIR=$T/state TERMAWAKE_LOG_DIR=$T/logs
  TERMAWAKE_PMSET=$T/bin/pmset TERMAWAKE_SUDO=$T/bin/sudo
  TERMAWAKE_TAWATCH=$T/bin/tawatch TERMAWAKE_NOTIFIER=$T/bin/notifier
  TERMAWAKE_TIME_SCALE=0.05
)
BASE_CONFIG=(APPS=FakeTermApp HEARTBEAT=10 THERMAL_COOLDOWN=60 WORK_GRACE=10 RETRY_SECONDS=30)
ta()            { env $ENVV /bin/zsh -f $TA "$@"; }
start_watcher() { env $ENVV "$@" /bin/zsh -f $TA run >> $T/watcher.out 2>&1 & W_PID=$!; }
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
state()     { local -a l; [[ -r $T/state/state ]] && l=("${(@f)$(<$T/state/state)}") && print -r -- "${l[1]-}"; }
# 計算 $T/calls 裡「整行等於 $1」的次數
count()     { local n=0; [[ -e $T/calls ]] && n=$(grep -c -x -- "$1" $T/calls); print -r -- ${n:-0}; }
grepc()     { local n=0; [[ -e $T/calls ]] && n=$(grep -c -- "$1" $T/calls); print -r -- ${n:-0}; }
notified()  { local n=0; [[ -e $T/notified ]] && n=$(grep -c -- "$1" $T/notified); print -r -- ${n:-0}; }
logged()    { grep -q -- "$1" $T/logs/termawake.log 2>/dev/null; }
logcount()  { local n=0; [[ -e $T/logs/termawake.log ]] && n=$(grep -c -- "$1" $T/logs/termawake.log); print -r -- ${n:-0}; }
config()    { print -l -- $BASE_CONFIG "$@" >| $T/state/config; }
# 改變模擬的系統狀態，例如：sense app=FakeTermApp lid=1 batt=1 pct=15
# 監視程式在跑的話，會等它真的收到新狀態才繼續（避免測試本身的時間差）
sense() {
  local kv want
  for kv in "$@"; do SENS[${kv%%=*}]=${kv#*=}; done
  want="app=$SENS[app] batt=$SENS[batt] pct=$SENS[pct] lid=$SENS[lid] ext=$SENS[ext] therm=$SENS[therm] lpm=$SENS[lpm]"
  print -r -- "$want work=$SENS[work]" >| $T/sensors.tmp
  mv -f $T/sensors.tmp $T/sensors
  [[ -n $W_PID ]] && alive $W_PID || return 0
  wait_for 1.5 '[[ -r $T/state/state && "$(<$T/state/state)" == *"$want "* ]]' 2>/dev/null
  return 0
}
app_on()    { sense app=FakeTermApp; }
app_off()   { sense app=-; }
reset_world() {
  stop_watcher KILL
  pkill -f -- "$T/bin/tawatch" 2>/dev/null
  rm -rf $T/state/* $T/logs/* $T/calls $T/notified $T/helper_args $T/sudo_broken $T/sudo_hang $T/helper_crash $T/helper_mute
  print 0 >| $T/sd
  SENS=(app - batt 0 pct 80 lid 0 ext 0 therm 0 lpm 0 work 0)
  sense
  config
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
check() { local d=$1; shift; if wait_for 3 "$*"; then pass "$d"; else fail "$d   〔條件：$*｜sd=$(sd) state=$(state)〕"; fi; }
# stays 說明 秒數 條件：這段時間內一直成立
stays() {
  local d=$1 secs=$2; shift 2
  local deadline=$(( EPOCHREALTIME + secs ))
  while (( EPOCHREALTIME < deadline )); do
    eval "$*" || { fail "$d   〔中途不成立：$*｜sd=$(sd) state=$(state)〕"; return; }
    sleep 0.05
  done
  pass "$d"
}
section() { print; print -r -- "▌$*"; }

print "TermAwake 自動測試（暫存目錄：$T）"

section "1. Terminal 沒開 → 什麼都不做"
reset_world; start_watcher
check "感測小幫手送來資料後，狀態是「沒開」" '[[ $(state) == app-not-running ]]'
stays "SleepDisabled 維持 0、沒有標記檔" 0.6 '[[ $(sd) == 0 ]] && ! marker'

section "2. 打開 Terminal → 禁止睡眠"
app_on
check "SleepDisabled 變成 1" '[[ $(sd) == 1 ]]'
check "寫了標記檔" 'marker'
check "status 回報生效中" '[[ $(state) == engaged ]]'

section "3. 開很多個 Terminal 視窗也只會有一個監視程式"
env $ENVV /bin/zsh -f $TA run > $T/second.out 2>&1 &
p2=$!
wait_for 3 '! alive $p2'
if alive $p2; then kill -9 $p2; rc=999; else wait $p2; rc=$?; fi
check "第二個監視程式拒絕啟動（exit 75）" '(( rc == 75 ))'
check "而且沒有動到第一個的狀態" '[[ $(sd) == 1 ]] && marker'

section "4. 用電池、電量低於 20% → 恢復睡眠"
sense batt=1 pct=19
check "SleepDisabled 回到 0" '[[ $(sd) == 0 ]]'
check "標記檔刪掉" '! marker'
check "蓋子開著 → 不會強制睡眠" '(( $(count sleepnow) == 0 ))'
check "status 回報低電量" '[[ $(state) == low-battery ]]'
check "發了通知" '(( $(notified 電量) == 1 ))'

section "5. 低電量鎖定：還在用電池就不會再啟用，接上電源才會"
sense batt=1 pct=25
stays "電量變 25%（仍用電池）→ 維持 0" 0.8 '[[ $(sd) == 0 ]]'
sense batt=0 pct=25
check "接上電源 → 重新禁止睡眠" '[[ $(sd) == 1 ]]'
sense batt=1 pct=30
stays "拔掉電源、電量 30%（≥ 20%）→ 繼續禁止睡眠" 0.8 '[[ $(sd) == 1 ]]'
sense batt=0 pct=19
stays "插著電源時就算 19% 也繼續" 0.8 '[[ $(sd) == 1 ]]'

section "6. 蓋子合著 + 低電量 + 沒接外接螢幕 → 立刻讓 Mac 睡"
sense lid=1 ext=0 batt=1 pct=15
check "SleepDisabled 回到 0" '[[ $(sd) == 0 ]]'
check "呼叫了 pmset sleepnow" '(( $(count sleepnow) == 1 ))'

section "7. 蓋子合著 + 有外接螢幕（桌面模式）→ 不強制睡眠"
sense batt=0 pct=80
check "（接電源 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
sense ext=1; app_off
check "Terminal 結束 → SleepDisabled 回到 0" '[[ $(sd) == 0 ]]'
stays "有外接螢幕 → 沒有呼叫 sleepnow" 0.6 '(( $(count sleepnow) == 1 ))'

section "8. 蓋子合著 + 沒外接螢幕 + Terminal 結束 → 立刻睡"
sense ext=0; app_on
check "（Terminal 開 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
app_off
check "SleepDisabled 回到 0" '[[ $(sd) == 0 ]]'
check "呼叫了 pmset sleepnow" '(( $(count sleepnow) == 2 ))'
sense lid=0

section "9. 暫停 / 恢復（由監視程式動手，指令只送請求）"
app_on
check "（Terminal 開 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
out=$(ta pause)
check "termawake pause → 馬上恢復睡眠" '[[ $(sd) == 0 ]] && ! marker'
check "是監視程式改的（指令沒有自己動手）" '! logged "由 pause 指令直接恢復睡眠" && grep -q "\[$W_PID\] RELEASE: 你按了暫停" $T/logs/termawake.log'
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
sense pct=81   # 隨便一個事件，讓監視程式重新判斷
check "舊的暫停被清掉" '[[ ! -e $T/state/paused ]]'
stays "繼續禁止睡眠" 0.6 '[[ $(sd) == 1 ]]'

section "11. 正常結束（登出/關機/停止服務的 TERM 訊號）→ 一定先恢復"
sense lid=1
before=$(count sleepnow)
stop_watcher TERM
check "SleepDisabled 回到 0" '[[ $(sd) == 0 ]]'
check "標記檔刪掉" '! marker'
check "結束時不會強制睡眠（可能正在關機）" '(( $(count sleepnow) == before ))'
check "感測小幫手也一起結束" '! pgrep -f "$T/bin/tawatch" >/dev/null'
sense lid=0

section "12. HUP 訊號也一樣會恢復"
start_watcher
check "（先禁止睡眠）" '[[ $(sd) == 1 ]]'
stop_watcher HUP
check "收到 HUP → SleepDisabled 回到 0" '[[ $(sd) == 0 ]] && ! marker'

section "13. kill -9（無法攔截）→ 重新啟動後自動收拾"
start_watcher
check "（先禁止睡眠）" '[[ $(sd) == 1 ]]'
stop_watcher KILL
check "被 kill -9 後設定還是 1、標記還在（這是預期的）" '[[ $(sd) == 1 ]] && marker'
check "感測小幫手發現監視程式不見了，自己結束（不會變孤兒）" '! pgrep -f "$T/bin/tawatch" >/dev/null'
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
check "接手後狀態是「生效中」" '[[ $(state) == engaged ]]'
stays "只接手一次（不會一直重複接手）" 0.6 '(( $(logcount ADOPT) == 1 ))'
stays "維持 1，而且沒有多呼叫 pmset" 0.8 '[[ $(sd) == 1 ]] && (( $(count "disablesleep 1") == n1 && $(count "disablesleep 0") == n0 ))'

section "15. SleepDisabled 原本就是 1（不是我們設的）→ 完全不碰"
reset_world
print 1 >| $T/sd
app_on; start_watcher
check "紀錄檔說明不是 TermAwake 設的" 'logged "不是 TermAwake 設的"'
check "status 回報 foreign" '[[ $(state) == foreign ]]'
app_off
stays "Terminal 關掉也維持 1、沒有任何 pmset 呼叫" 0.8 '[[ $(sd) == 1 ]] && (( $(count "disablesleep 0") + $(count "disablesleep 1") == 0 ))'

section "16. 免密碼規則壞掉 → 不留標記、不亂改，修好後自動恢復運作"
reset_world
: > $T/sudo_broken
app_on; start_watcher
stays "SleepDisabled 一直維持 0" 0.8 '[[ $(sd) == 0 ]]'
check "失敗後不會留下標記檔" '! marker'
n1=$(grepc "^BROKEN"); sleep 1.0; n2=$(grepc "^BROKEN")
check "失敗後會退避：1 秒內最多重試 1 次（RETRY_SECONDS）" '(( n2 - n1 <= 1 ))'
check "紀錄檔有錯誤說明" 'logged "免密碼規則"'
check "status 回報啟用失敗" '[[ $(state) == error-engage ]]'
check "持續失敗 → 發通知" '(( $(notified 無法防止睡眠) == 1 ))'
rm -f $T/sudo_broken
check "規則修好 → 自動禁止睡眠（不必等使用者操作）" 'wait_for 3 "[[ \$(sd) == 1 ]]"'

section "17. 設定檔改了立刻生效；亂寫的值會被忽略，超出範圍會被夾住"
config BATTERY_MIN=90
sense batt=1 pct=85
check "門檻改成 90% → 85% 用電池就恢復睡眠" '[[ $(sd) == 0 ]]'
config BATTERY_MIN=20
check "門檻改回 20%（仍用電池）→ 立刻用新門檻重新判斷" '[[ $(sd) == 1 ]]'
config BATTERY_MIN=abc
check "看不懂的值 → 紀錄檔說明、改用預設值" 'logged "BATTERY_MIN=abc 看不懂"'
config BATTERY_MIN=0
check "BATTERY_MIN=0 → 夾到最低 5（低電量保護不能關掉）" 'logged "BATTERY_MIN=0 超出範圍（5～100）→ 改用 5"'
sense pct=4
check "電量 4% 用電池 → 一定恢復睡眠" '[[ $(sd) == 0 ]]'
sense batt=0 pct=80
config "APPS=FakeTermApp; touch $T/pwned"
check "想夾帶指令的 APPS 被拒絕" 'logged "看不懂"'
stays "夾帶的指令沒有被執行" 0.4 '[[ ! -e $T/pwned ]]'
config INTERVAL=5
check "舊版的 INTERVAL 會提示已經不用" 'logged "INTERVAL 已經不用了"'
config
check "（恢復正常設定）" '[[ $(sd) == 1 ]]'

section "18. 防睡眠時合上蓋子 → 主動關螢幕"
reset_world
app_on; start_watcher
check "（Terminal 開 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
sense lid=1
check "合上蓋子 → 呼叫 pmset displaysleepnow 關螢幕" '(( $(count displaysleepnow) == 1 ))'
stays "蓋子一直合著 → 只關一次，不會一直呼叫" 0.8 '(( $(count displaysleepnow) == 1 ))'
check "Mac 仍然不睡（SleepDisabled 維持 1）" '[[ $(sd) == 1 ]]'
sense lid=0; sleep 0.2; sense lid=1
check "打開再合上 → 再關一次" '(( $(count displaysleepnow) == 2 ))'
sense lid=0 ext=1; sleep 0.2; sense lid=1
stays "接著外接螢幕時合上（桌面模式）→ 不關螢幕" 0.6 '(( $(count displaysleepnow) == 2 ))'
sense lid=0 ext=-1; sleep 0.2; sense lid=1
stays "判斷不出有沒有外接螢幕 → 保守起見不關" 0.6 '(( $(count displaysleepnow) == 2 ))'
sense lid=0 ext=0; sleep 0.2
out=$(ta pause); sense lid=1
stays "暫停時合上蓋子 → 不插手（交給 macOS 正常睡眠）" 0.6 '(( $(count displaysleepnow) == 2 ))'
sense lid=0; out=$(ta resume)
check "（取消暫停 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
config LID_DISPLAY_OFF=0
sleep 0.3; sense lid=1
stays "LID_DISPLAY_OFF=0 → 合蓋不關螢幕" 0.6 '(( $(count displaysleepnow) == 2 ))'
sense lid=0; config

section "19. 事件驅動：平常完全不執行外部指令，有事件才立刻反應"
reset_world
config HEARTBEAT=600   # 心跳拉長到 30 秒（測試倍率下），證明反應來自事件而不是定時檢查
app_on; start_watcher
check "（禁止睡眠）" '[[ $(sd) == 1 ]]'
sleep 0.4; c0=$(wc -l < $T/calls)
stays "沒有事件的 1.5 秒內，沒有呼叫任何 pmset / sudo" 1.5 '(( $(wc -l < $T/calls) == c0 ))'
t0=$EPOCHREALTIME; sense lid=1
if wait_for 0.8 '(( $(count displaysleepnow) == 1 ))'; then
  pass "合上蓋子 → $(printf %.2f $(( EPOCHREALTIME - t0 ))) 秒內就關螢幕（不用等心跳）"
else
  fail "合上蓋子後 0.8 秒內沒有關螢幕"
fi
t0=$EPOCHREALTIME; app_off
if wait_for 0.8 '[[ $(sd) == 0 ]]'; then
  pass "Terminal 結束 → $(printf %.2f $(( EPOCHREALTIME - t0 ))) 秒內就恢復睡眠"
else
  fail "Terminal 結束後 0.8 秒內沒有恢復睡眠"
fi
sense lid=0

section "20. 過熱保護（溫度壓力等級，預設門檻 2）"
reset_world
app_on; start_watcher
check "（禁止睡眠）" '[[ $(sd) == 1 ]]'
sense therm=1
stays "等級 1（中度）→ 繼續禁止睡眠" 0.6 '[[ $(sd) == 1 ]]'
sense therm=2
check "等級 2（重度）→ 恢復睡眠" '[[ $(sd) == 0 ]]'
check "status 回報過熱保護" '[[ $(state) == thermal ]]'
check "發了通知" '(( $(notified 溫度偏高) == 1 ))'
sense therm=0
stays "降溫了，但還沒滿冷卻時間 → 維持恢復睡眠" 1.5 '[[ $(sd) == 0 ]]'
check "冷卻時間（60 秒 × 測試倍率 = 3 秒）到了 → 自動重新禁止睡眠" 'wait_for 3 "[[ \$(sd) == 1 ]]"'
sense lid=1 therm=3
check "合蓋中過熱 → 恢復睡眠並立刻讓 Mac 睡" '[[ $(sd) == 0 ]] && (( $(count sleepnow) == 1 ))'
sense lid=0 therm=0
config THERMAL_LIMIT=3 THERMAL_COOLDOWN=60
check "（改門檻後重新判斷 → 禁止睡眠）" '[[ $(sd) == 1 ]]'
sense therm=2
stays "THERMAL_LIMIT=3 → 等級 2 繼續禁止睡眠" 0.6 '[[ $(sd) == 1 ]]'
sense therm=3
check "THERMAL_LIMIT=3 → 等級 3 恢復睡眠" '[[ $(sd) == 0 ]]'
sense therm=0; config

section "21. 低耗電模式（預設：用電池時開啟就恢復睡眠）"
reset_world
app_on; start_watcher
check "（禁止睡眠）" '[[ $(sd) == 1 ]]'
sense lpm=1
stays "接電源時開低耗電 → 繼續禁止睡眠" 0.6 '[[ $(sd) == 1 ]]'
sense batt=1
check "用電池 + 低耗電 → 恢復睡眠" '[[ $(sd) == 0 ]] && [[ $(state) == low-power ]]'
sense lpm=0
check "關掉低耗電 → 重新禁止睡眠" '[[ $(sd) == 1 ]]'
config LOW_POWER=ignore
sense lpm=1
stays "LOW_POWER=ignore → 用電池 + 低耗電也繼續禁止睡眠" 0.8 '[[ $(sd) == 1 ]]'
sense lpm=0 batt=0; config

section "22. SleepDisabled 被別人改回 0 → 當成你手動覆寫，進入暫停（不跟人搶）"
reset_world
app_on; start_watcher
check "（禁止睡眠）" '[[ $(sd) == 1 ]]'
sleep 0.4
print 0 >| $T/sd    # 模擬：別的工具或你自己執行了 sudo pmset -a disablesleep 0
check "紀錄檔有 DRIFT" 'logged DRIFT'
check "進入暫停、標記檔刪掉" '[[ $(state) == paused && -e $T/state/paused ]] && ! marker'
check "發了通知" '(( $(notified "被別的程式") == 1 ))'
stays "不會再自己改回 1" 0.8 '[[ $(sd) == 0 ]]'
out=$(ta resume)
check "termawake resume → 重新禁止睡眠" '[[ $(sd) == 1 ]]'

section "23. 感測小幫手出問題 → 自動重啟；一直失敗就恢復正常睡眠（不確定時選安全的一邊）"
reset_world
app_on; start_watcher
check "（禁止睡眠）" '[[ $(sd) == 1 ]]'
hp=$(pgrep -f "$T/bin/tawatch" | head -1)
kill -9 $hp
if wait_for 0.5 'logged "感測小幫手結束了" && logged "重新啟動（第 1 次）"'; then
  pass "小幫手被 kill -9 → 監視程式 0.5 秒內就發現並重新啟動（不用等心跳逾時）"
else
  fail "小幫手被 kill -9 後 0.5 秒內沒有發現"
fi
stays "重新啟動期間不會亂切換（維持 1）" 0.6 '[[ $(sd) == 1 ]]'
n1=$(count 'disablesleep 1'); n0=$(count 'disablesleep 0')
config HEARTBEAT=20
check "改了心跳設定 → 用新設定重新啟動小幫手" 'logged "用新設定重新啟動感測小幫手"'
stays "重新啟動小幫手時不會亂切換睡眠設定" 0.8 '[[ $(sd) == 1 ]] && (( $(count "disablesleep 1") == n1 && $(count "disablesleep 0") == n0 ))'
config
: > $T/helper_crash
kill -9 $(pgrep -f "$T/bin/tawatch" | head -1) 2>/dev/null
check "一直失敗 → 恢復正常睡眠" '[[ $(sd) == 0 ]] && [[ $(state) == sensor-error ]]'
check "發了通知" '(( $(notified "感測小幫手一直失敗") == 1 ))'
rm -f $T/helper_crash
check "小幫手恢復正常 → 自動重新禁止睡眠" 'wait_for 3 "[[ \$(sd) == 1 && \$(state) == engaged ]]"'
: > $T/helper_mute
check "小幫手卡住（活著但不回報）→ 叫它沒反應就重新啟動" 'wait_for 4 "logged \"感測小幫手沒有反應\""'
rm -f $T/helper_mute
check "（恢復正常）" 'wait_for 4 "[[ \$(state) == engaged ]]"'
stop_watcher TERM
reset_world
app_on; start_watcher TERMAWAKE_TAWATCH=$T/bin/no-such-helper
check "找不到感測小幫手 → 不禁止睡眠，並說明原因" '[[ $(state) == sensor-error ]] && logged "找不到感測小幫手"'
stays "SleepDisabled 維持 0" 0.4 '[[ $(sd) == 0 ]]'

section "24. 外部指令卡住 → 有時間上限，不會拖住監視程式"
reset_world
config CMD_TIMEOUT=1
: > $T/sudo_hang
app_on; start_watcher
check "sudo 卡住 → 1 秒後放棄（狀態：啟用失敗）" 'wait_for 4 "[[ \$(state) == error-engage ]]"'
check "沒有留下標記檔" '! marker'
rm -f $T/sudo_hang
check "sudo 恢復正常 → 自動禁止睡眠" 'wait_for 4 "[[ \$(sd) == 1 ]]"'
check "沒有殘留卡住的 sleep 程序" '! pgrep -f "/bin/sleep 30" >/dev/null'

section "25. termawake restore：監視程式卡住時也能用，而且不會留下沒人收拾的狀態"
reset_world
app_on; start_watcher
check "（禁止睡眠）" '[[ $(sd) == 1 ]]'
kill -STOP $W_PID
out=$(ta restore)
check "監視程式卡住 → restore 直接把 SleepDisabled 改回 0" '[[ $(sd) == 0 ]]'
check "但保留標記檔（交給監視程式恢復後收拾）" 'marker'
kill -CONT $W_PID
check "監視程式恢復 → 看到暫停，收拾標記檔" '! marker && [[ $(state) == paused ]]'
stays "維持 0" 0.4 '[[ $(sd) == 0 ]]'

section "26. MODE=work：只有程式要求保持清醒時才不睡"
reset_world
config MODE=work
app_on; start_watcher
check "沒有工作 → 不禁止睡眠" '[[ $(state) == no-work && $(sd) == 0 ]]'
check "小幫手有被要求追蹤「保持清醒的請求」（--work）" 'grep -q -- "--work" $T/helper_args'
sense work=1
check "Claude Code 開始工作（caffeinate）→ 立刻禁止睡眠" '[[ $(sd) == 1 ]]'
sense lid=1
check "合蓋 → 關螢幕" '(( $(count displaysleepnow) == 1 ))'
sense work=0
stays "工作結束，寬限期內（10 秒 × 倍率 = 0.5 秒）維持" 0.3 '[[ $(sd) == 1 ]]'
check "寬限期過後 → 恢復睡眠，蓋子合著就讓 Mac 睡" '[[ $(sd) == 0 ]] && (( $(count sleepnow) == 1 ))'
sense lid=0 work=-1
check "判斷不出有沒有在工作 → 當成在工作（安全網照樣有效）" '[[ $(sd) == 1 ]]'
sense work=0; config

section "27. IDLE_MINUTES：合蓋用電池太久沒工作 → 讓 Mac 睡（MODE=app）"
reset_world
config IDLE_MINUTES=1    # 1 分鐘 × 測試倍率 = 3 秒
app_on; start_watcher
check "（禁止睡眠）" '[[ $(sd) == 1 ]]'
check "小幫手有被要求追蹤「保持清醒的請求」（--work）" 'grep -q -- "--work" $T/helper_args'
sense lid=1 batt=1 work=1
stays "合蓋用電池但 Claude 在工作 → 不會睡" 3.5 '[[ $(sd) == 1 ]]'
sense work=0
stays "沒在工作，還沒滿 1 分鐘 → 繼續" 2.0 '[[ $(sd) == 1 ]]'
check "滿 1 分鐘 → 恢復睡眠並讓 Mac 睡" 'wait_for 3 "[[ \$(sd) == 0 ]]" && (( $(count sleepnow) == 1 )) && [[ $(state) == idle ]]'
sense lid=0
check "打開蓋子 → 重新禁止睡眠" '[[ $(sd) == 1 ]]'
sense lid=1 batt=0
stays "接著電源合蓋 → 不會因為閒置而睡（手機遠端控制不受影響）" 3.5 '[[ $(sd) == 1 ]]'
config

section "28. 通知可以關掉"
reset_world
config NOTIFY=0
app_on; start_watcher
check "（禁止睡眠）" '[[ $(sd) == 1 ]]'
sense batt=1 pct=10
check "低電量恢復睡眠" '[[ $(sd) == 0 ]]'
stays "NOTIFY=0 → 沒有發通知" 0.6 '(( $(notified "") == 0 ))'

section "29. 真的感測小幫手（這台電腦有編譯器才測）"
stop_watcher TERM
if /usr/bin/xcode-select -p >/dev/null 2>&1 &&
   /usr/bin/xcrun cc -O2 -Wall -Wextra -Werror -fobjc-arc -framework AppKit -framework IOKit -framework CoreGraphics \
     -o $T/tawatch-real $ROOT/src/tawatch.m 2>$T/cc.err; then
  pass "src/tawatch.m 編譯成功，而且沒有任何警告（-Wall -Wextra -Werror）"
  one=$($T/tawatch-real --once --apps "Terminal")
  check "--once 印出一行格式正確的狀態" '[[ $one =~ "^S1 gen=0 pid=[0-9]+ why=once seq=1 app=[^ ]+ batt=[01] pct=-?[0-9]+ lid=-?[01] ext=-?[0-9]+ therm=-?[0-4] lpm=[01] sd=-?[01] work=-1$" ]]'
  print "     （這台 Mac 現在：${one#* why=once seq=1 }）"
  print 'APPS=x' >| $T/cfg-real
  : >| $T/real.out
  # 一個簡單的父程式：在背景啟動小幫手，然後等著（模擬監視程式）
  print -r -- "$T/tawatch-real --parent \$\$ --apps sleep --tick 1 --config $T/cfg-real > $T/real.out 2>&1 & wait" >| $T/parent.zsh
  /bin/zsh -f $T/parent.zsh & rp_shell=$!
  check "啟動時印出第一行（why=start）" 'grep -q "why=start" $T/real.out'
  print 'APPS=y' >> $T/cfg-real
  check "設定檔一改就通知（why=config）" 'grep -q "why=config" $T/real.out'
  /bin/sleep 2.5 & sp=$!
  check "非 App 的程序（sleep）在下一次心跳被找到" 'grep -q "app=sleep" $T/real.out'
  wait $sp
  check "程序一結束就立刻通知（why=app，不用等心跳）" 'grep "why=app" $T/real.out | grep -q "app=-"'
  kill -USR1 $(pgrep -x tawatch-real) 2>/dev/null
  check "收到 SIGUSR1 → 立刻回報（why=ping）" 'grep -q "why=ping" $T/real.out'
  kill -9 $rp_shell 2>/dev/null
  check "父程式被 kill -9 → 小幫手也立刻結束（不會變孤兒）" '! pgrep -x tawatch-real >/dev/null'
  reset_world; app_off
  start_watcher TERMAWAKE_TAWATCH=$T/tawatch-real
  check "監視程式用真的小幫手也能正常運作（收到資料並做出判斷）" 'wait_for 4 "[[ \$(state) == app-not-running ]]"'
  stop_watcher TERM
  check "監視程式結束時，真的小幫手也一起結束" '! pgrep -x tawatch-real >/dev/null'
else
  print "  （這台電腦沒有編譯器，略過；錯誤訊息：$(<$T/cc.err 2>/dev/null)）"
fi

section "30. 安全檢查"
check "全程只用過允許的兩條 sudo 指令" '(( $(grepc "^DENIED") == 0 ))'
check "沒有呼叫任何預期外的 pmset 指令" '(( $(grepc "^UNEXPECTED") == 0 ))'

section "31. 各個指令都能正常執行"
reset_world; app_on; start_watcher
check "（禁止睡眠）" '[[ $(sd) == 1 ]]'
for c in status config version help log; do
  ta $c > $T/cmd.out 2>&1; rc=$?
  check "termawake $c" '(( rc == 0 ))'
done
out=$(ta status)
check "status 顯示溫度、蓋子、感測小幫手" '[[ $out == *溫度* && $out == *蓋子* && $out == *感測小幫手* ]]'
ta doctor > $T/doctor.out 2>&1; rc=$?
check "termawake doctor 跑完並給出結果（結束碼 0/1/2）" '(( rc <= 2 )) && grep -q "結果：" $T/doctor.out'
ta nonsense > /dev/null 2>&1; rc=$?
check "不認識的指令會回報錯誤" '(( rc == 64 ))'
stop_watcher TERM

print
print -r -- "結果：通過 $PASS 項，失敗 $FAIL 項"
(( FAIL == 0 ))
