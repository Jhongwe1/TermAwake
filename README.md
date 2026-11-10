# TermAwake

> **只要 Terminal 開著，MacBook 合上蓋子也不會睡著；Terminal 一關，一切自動恢復原狀。**
>
> Keep your Mac awake — even with the lid closed — while Terminal is open. Everything is restored automatically when Terminal quits. Event-driven (no polling), with battery, thermal and Low Power Mode safety nets.

- [這是什麼？](#這是什麼)
- [安裝（3 步驟）](#安裝)
- [日常使用](#日常使用)
- [使用前一定要知道的事](#使用前一定要知道的事)
- [怎麼確認它有效？](#怎麼確認它有效)
- [設定](#設定) ・ [移除](#移除) ・ [安全性](#安全性) ・ [運作原理](#運作原理)
- [開發過程：為什麼做、踩了哪些坑](#開發過程)
- [常見問題](#常見問題)

---

## 這是什麼？

MacBook 有個習慣：**蓋子一合上就去睡覺**。
睡著的時候，所有程式都會暫停：Claude Code 寫到一半的程式、正在下載的檔案、跑到一半的編譯，全部停住，網路也會斷。

TermAwake 就像一個「顧門的小幫手」，在背景幫你看著：

- 👀 **Terminal 有沒有開著？** macOS 一有變化就會通知它，它不用一直去問。
- ☕ 有開 → 叫 Mac 不准睡。合上蓋子也照樣跑，只是螢幕會關掉。
- 😴 Terminal **完全結束** → 立刻把設定改回原本的樣子，Mac 恢復正常睡覺。
- 🛟 **安全網**：遇到下面這些情況，不管 Terminal 有沒有開，都讓 Mac 正常睡覺：
  - 🪫 用電池而且電量**低於 20%**
  - 🌡 Mac **太熱**
  - 🔋 用電池而且開了**低耗電模式**

| 情況 | Mac 會怎樣 |
|---|---|
| Terminal 開著，合上蓋子 | ✅ 繼續跑：程式、網路照常，只有螢幕關掉 |
| Terminal 完全結束（按 `⌘Q`） | 😴 立刻恢復正常：合上蓋子就睡 |
| 用電池，電量低於 20% | 🪫 恢復正常；如果蓋子已經合著，會**馬上**讓 Mac 睡 |
| Mac 太熱（溫度壓力達到「重度」） | 🌡 恢復正常；蓋子合著就**馬上**睡；降溫 5 分鐘後自動恢復 |
| 用電池又開了低耗電模式 | 🔋 恢復正常；接上電源或關掉低耗電模式後自動恢復 |
| 輸入 `termawake pause` | ⏸ 暫停：Mac 正常睡，直到 Terminal 完全結束 |

---

## 安裝

### 第 1 步：打開 Terminal

按 `⌘ + 空白鍵`，輸入 `Terminal`，按 Enter。

### 第 2 步：下載並安裝

把下面四行**整段複製**，貼到 Terminal，按 Enter：

```bash
cd ~/Downloads
git clone https://github.com/Jhongwe1/TermAwake.git
cd TermAwake
./install.sh
```

> 💡 如果跳出「需要安裝命令列開發者工具」的視窗：按「安裝」，等它裝完（幾分鐘），再貼一次上面四行。
> TermAwake 需要這個免費工具，在你的電腦上編譯一個小程式（感測小幫手 `tawatch`）。
>
> 💡 不想用 git？在這個網頁按綠色的 **Code → Download ZIP**，解壓縮後在 Terminal 輸入：
> `cd ~/Downloads/TermAwake-main && zsh install.sh`
> （沒有命令列開發者工具的話，安裝程式會告訴你怎麼裝，而且在那之前什麼都不會改。）

### 第 3 步：輸入密碼

安裝到一半會請你輸入 **Mac 的登入密碼**（就是開機時輸入的那組）。

- 在 Terminal 裡打密碼時，**畫面不會出現任何字**。這是正常的，打完按 Enter 就好。
- 為什麼需要密碼？請看[安全性](#安全性)。只有安裝和移除時需要，平常不用。

看到 `🎉 安裝完成！` 就好了。以後**什麼都不用做**：打開 Terminal 就會自動生效。

> 安裝程式會自動判斷你用的是 Terminal 還是 iTerm2。用 iTerm2 的話也可以直接指定：`./install.sh --app iTerm2`
>
> 從舊版升級：一樣執行 `./install.sh`。你原本的設定會保留，新的設定項目會自動加上預設值和說明。

---

## 日常使用

基本上你什麼都不用做。想看看它現在在做什麼，就在 Terminal 輸入：

```bash
termawake
```

會看到類似這樣的畫面：

```
  ✅ 防睡眠生效中：Mac 不會進入系統睡眠，合上蓋子也會繼續跑（蓋子合上時螢幕會關掉）

  監視程式    執行中（PID 763；登入時自動啟動，當掉會自動重開）
  感測小幫手  正常（等 macOS 的事件通知，平常不佔 CPU）
  監視對象    Terminal：開著
  電源        電池 81%，使用電池中（低於 20% 會自動恢復睡眠）
  溫度        正常（等級 0；達到 2 會自動恢復睡眠）
  低耗電模式  關（用電池時開啟會恢復睡眠）
  蓋子        打開（外接螢幕 0 台）
  暫停        否
  系統設定    SleepDisabled = 1（TermAwake 設的；不需要時會自動改回 0）
  免密碼規則  已安裝（/etc/sudoers.d/termawake）
```

### 所有指令

| 指令 | 做什麼 |
|---|---|
| `termawake` | 看目前狀態 |
| `termawake pause` | **暫停**：讓 Mac 可以正常睡（例如要把電腦收進包包時） |
| `termawake resume` | 取消暫停 |
| `termawake log` | 看最近的紀錄（什麼時候啟用、什麼時候恢復、為什麼） |
| `termawake config` | 看目前的設定 |
| `termawake doctor` | **健康檢查**：一次檢查所有東西是否正常（只讀取，不會改任何設定） |
| `termawake restore` | 緊急：立刻恢復正常睡眠 |
| `termawake uninstall` | 完全移除 |

### 想讓 Mac 睡覺，但不想關掉 Terminal？

```bash
termawake pause
```

然後合上蓋子，Mac 就會正常睡。
暫停會在 Terminal 完全結束後自動解除；想馬上恢復就輸入 `termawake resume`。

---

## 使用前一定要知道的事

1. **收進包包前，先 `termawake pause`，或把 Terminal 完全結束（`⌘Q`）。**
   Terminal 開著時 Mac 不會睡，放在包包裡會一直耗電、發熱。1.3 版有過熱保護（太熱就讓 Mac 睡），但包包裡散熱很差，MacBook Air 又沒有風扇，最好不要依賴它。常把 Mac 放包包的話，可以在設定裡打開[合蓋閒置](#設定)（`IDLE_MINUTES=30`）。
2. **只關視窗不等於關掉 Terminal。**
   按視窗左上角紅色的 ✕ 只會關掉視窗，Terminal 其實還開著（Dock 上的圖示下面還有一個小點）。要按 `⌘Q` 才是完全結束。
3. **Terminal 開著的時候，蘋果選單裡的「睡眠」也會沒有作用。**
   這是 macOS 的設計：這個開關是整台電腦共用的。想睡就先 `termawake pause`。
4. **合上蓋子時，螢幕由 TermAwake 負責關掉。** 擋住睡眠的時候，macOS 自己**不會**在合蓋時關螢幕（詳見[開發過程第 10 點](#10-合上蓋子螢幕卻還亮著實際使用才發現)），所以 TermAwake 一收到「蓋子合上」的通知就關螢幕。接著外接螢幕（桌面模式）時不會去動螢幕。
5. **合上蓋子後，多久會鎖定？** 平常合蓋時 Mac 會睡，打開要輸入密碼；擋住睡眠以後，鎖定改由「螢幕關閉後多久要求密碼」這個設定決定。如果它是 5 分鐘，合蓋後 5 分鐘內打開就**不用密碼**。建議改成「立即」：**系統設定 → 鎖定畫面 →「螢幕保護程式啟動或顯示器關閉後要求密碼」→ 立即**（實際名稱以你系統上的中文為準）。`termawake doctor` 會幫你檢查這一項。

---

## 怎麼確認它有效？

### 測試 1：健康檢查（最快）

```bash
termawake doctor
```

會逐項檢查：監視程式、感測小幫手、免密碼規則、睡眠設定是否一致、有沒有其他同類工具在搶同一個開關、溫度、螢幕鎖定、FileVault、最近的錯誤。最後一行是 `結果：全部正常。` 就對了（有 ⚠️ 的項目會告訴你怎麼處理）。

### 測試 2：合上蓋子測試（最重要的一個）

1. 在 Terminal 貼上這行，它會每 5 秒印一次現在的時間：
   ```bash
   while true; do date '+%H:%M:%S'; sleep 5; done
   ```
2. 合上蓋子，等 2～3 分鐘。
3. 打開蓋子，看畫面上的時間：**每一行都應該相差大約 5 秒**。如果中間突然跳了好幾分鐘，就代表剛剛睡著了。
4. 按 `Ctrl + C` 停止。

也可以直接看系統的睡眠紀錄，確認剛剛那段時間沒有 `Sleep`：

```bash
pmset -g log | grep -E ' (Sleep|Wake) ' | tail -5
```

<details>
<summary><b>進階版：同時檢查「螢幕有沒有關」、網路、耗電</b>（整段貼進一個新的 Terminal 視窗）</summary>

貼上後按 Enter，看到「合蓋測試開始」就合上蓋子，大約 3 分鐘後打開；第 4 分鐘會自動顯示結果。想測久一點，把最後一行改成 `lidtest 10`（10 分鐘）。

```zsh
lidtest() {
  local end=$(( $(date +%s) + ${1:-4} * 60 )) last=$(date +%s) now gap lid scr net bat w slept=0 off=0 wsum=0 wn=0
  print "\n=== 合蓋測試開始 $(date +%H:%M:%S)：現在合上蓋子，約 3 分鐘後再打開，時間到會自動出結果 ===\n"
  while (( $(date +%s) < end )); do
    now=$(date +%s); gap=$(( now - last )); last=$now
    (( gap > 30 )) && { slept=1; print "⚠️  這裡中斷了 $gap 秒 → Mac 睡著過"; }
    ioreg -r -k AppleClamshellState -d 1 | grep -q '"AppleClamshellState" = Yes' && lid=合上 || lid=打開
    pmset -g assertions | grep -q 'Prevent sleep while display is on' && scr=亮 || { scr=關; off=1; }
    curl -fsm 3 -o /dev/null http://captive.apple.com/hotspot-detect.html && net=通 || net=斷
    bat=$(pmset -g batt | grep -oE '[0-9]+%' | head -1)
    w=$(ioreg -rn AppleSmartBattery | grep -oE '"SystemLoad"=[0-9]+' | cut -d= -f2)
    [[ $lid == 合上 && -n $w ]] && { wsum=$(( wsum + w )); wn=$(( wn + 1 )); }
    printf '%s  蓋子:%s  螢幕:%s  網路:%s  電池:%s  整台耗電:%.1fW\n' "$(date +%H:%M:%S)" $lid $scr $net $bat $(( ${w:-0} / 1000.0 ))
    sleep 5
  done
  print "\n=== 結果 ==="
  (( slept )) && print "❌ Mac 中途睡著了（看上面 ⚠️ 的地方）" || print "✅ Mac 全程沒有睡著（每 5 秒都有紀錄）"
  (( off )) && print "✅ 螢幕有自動關掉" || print "❓ 測試期間沒有偵測到螢幕關掉"
  (( wn )) && printf '🔋 合上蓋子時，整台 Mac 平均耗電：%.1f W\n' $(( wsum / wn / 1000.0 ))
  print "\n系統紀錄（最近的螢幕／睡眠事件）："
  pmset -g log | grep -E 'Display is turned|Entering Sleep|Wake from' | tail -6 | cut -c1-90
}
lidtest
```

合蓋期間每一行都應該是「蓋子:合上　螢幕:關　網路:通」，而且時間每 5 秒一行、沒有跳掉。

</details>

### 測試 3：關掉 Terminal 會恢復嗎？

1. 按 `⌘Q` 完全結束 Terminal（如果裡面有程式在跑，它會問你要不要結束）。
2. 再打開 Terminal。
3. 輸入 `termawake log`，應該會看到這兩行（第一行的時間就是你按 `⌘Q` 的那一秒）：
   ```
   RELEASE: Terminal 已經完全結束 → SleepDisabled=0（恢復正常睡眠）
   ENGAGE: Terminal 開著，… → SleepDisabled=1（不會睡眠，合上蓋子也照跑）
   ```

### 測試 4：低電量保護（拔掉電源時才能測）

1. 拔掉電源。
2. 暫時把門檻調到 99%（比現在的電量還高）：
   ```bash
   sed -i '' 's/^BATTERY_MIN=.*/BATTERY_MIN=99/' ~/Library/Application\ Support/TermAwake/config
   ```
3. 輸入 `termawake`，應該會看到 `🪫 電量低`（存檔後立刻生效）。
4. 記得改回來：
   ```bash
   sed -i '' 's/^BATTERY_MIN=.*/BATTERY_MIN=20/' ~/Library/Application\ Support/TermAwake/config
   ```

### 測試 5：低耗電模式（拔掉電源時才能測）

1. 拔掉電源，從「控制中心」或「系統設定 → 電池」打開「低耗電模式」。
2. 輸入 `termawake`，應該會看到 `🔋 使用電池又開了低耗電模式`。
3. 關掉低耗電模式，再輸入 `termawake`，會回到 `✅ 防睡眠生效中`。

### 測試 6：程式被強制砍掉，也會自己恢復

```bash
kill -9 $(cat ~/Library/Application\ Support/TermAwake/watcher.pid)
sleep 12; termawake log 5
```

會看到 `RECOVER` 和 `ADOPT`：macOS 自動把監視程式重新打開，而且接手原本的狀態。

### 過熱保護怎麼測？

沒辦法安全地測：要讓 Mac 真的過熱，就得讓它長時間高溫運轉。所以過熱保護的「觸發流程」只用自動測試驗證；在你的 Mac 上能確認的是「讀得到溫度等級」：`termawake` 的「溫度」那一列，或 `termawake doctor`。

### 給開發者：自動測試

```bash
zsh tests/run-tests.zsh
```

用假的 `pmset`、`sudo`、感測小幫手模擬 164 種情況（開關 Terminal、低電量、過熱、低耗電、合蓋關螢幕、外接螢幕、設定被別人改掉、`kill -9`、小幫手當掉或卡住、指令卡住、重複啟動、設定檔被亂寫……）。有編譯器的話，也會實際編譯並測試真的感測小幫手。**不會動到真正的設定，也不需要密碼。** 大約 1 分鐘跑完。

---

## 設定

設定檔在 `~/Library/Application Support/TermAwake/config`。用「文字編輯」打開：

```bash
open -e ~/Library/Application\ Support/TermAwake/config
```

改完存檔就**立刻生效**，不用重新開機。設定檔裡每一項都寫了意思、範圍、預設值和建議值；`termawake config` 可以看目前的值。填錯的值會被忽略（改用預設值），超出範圍的數字會被調到最近的合法值；`termawake config` 會列出哪些值被改了，紀錄檔（`termawake log`）裡也有。

**什麼時候不睡**

| 設定 | 預設 | 範圍 | 意思 | 建議 |
|---|---|---|---|---|
| `APPS` | `Terminal` | 程序名稱 | 要監視的 App，多個用空白隔開（例如 `Terminal iTerm2`）。App 打開或結束時立刻知道；不是 App 的程序（例如 `tmux`）也可以，結束時立刻知道、啟動時最多 `HEARTBEAT` 秒內發現 | 你實際跑 Claude Code 的終端機 |
| `MODE` | `app` | `app`／`work` | `app` = App 開著就不睡。`work` = 只有「有程式要求保持清醒」時才不睡：Claude Code 工作中（它會自己執行 `caffeinate`），或你用 `caffeinate -i` 包住的指令；做完後過 `WORK_GRACE` 秒恢復睡眠 | `app`。會用手機遠端控制的話一定要 `app`：`work` 模式下 Claude 做完後，合著蓋子的 Mac 會睡著，手機就連不到了 |
| `IDLE_MINUTES` | `0`（關） | 0～1440 | 只在 `MODE=app` 有效：合蓋＋用電池＋沒接外接螢幕時，連續這麼多分鐘沒有程式要求保持清醒，就讓 Mac 睡。接著電源時不受影響 | 常把 Mac 放包包就設 `30` |
| `WORK_GRACE` | `60` | 10～3600 秒 | `MODE=work` 時，最後一個「保持清醒」的請求結束後，再等幾秒才恢復睡眠 | `60` |

**安全網（任何模式都有效）**

| 設定 | 預設 | 範圍 | 意思 | 建議 |
|---|---|---|---|---|
| `BATTERY_MIN` | `20` | 5～100 % | 用電池時，電量低於這個百分比就恢復睡眠。不能低於 5：SleepDisabled 可能連 macOS 自己的低電量睡眠也擋掉 | `20`；電池老化後調到 `25`～`30` |
| `THERMAL_LIMIT` | `2` | 1～3 | 溫度壓力達到這個等級就恢復睡眠（1 中度、2 重度、3 嚴重）。**不能關掉**，原因見[開發過程第 15 點](#15-過熱保護為什麼不能關) | `2` |
| `THERMAL_COOLDOWN` | `300` | 60～3600 秒 | 過熱恢復睡眠後，要連續這麼久低於門檻才重新啟用 | `300` |
| `LOW_POWER` | `release` | `release`／`ignore` | 用電池又開了低耗電模式時：`release` = 恢復睡眠，`ignore` = 照樣不睡 | `release` |

**螢幕與通知**

| 設定 | 預設 | 意思 | 建議 |
|---|---|---|---|
| `LID_DISPLAY_OFF` | `1` | 防睡眠期間合上蓋子就立刻關螢幕（`0` = 不管，螢幕等閒置計時才關） | `1` |
| `NOTIFY` | `1` | 出問題、或因為安全網恢復睡眠時，發 macOS 通知（`0` = 不發） | `1` |

**進階（通常不用改）**

| 設定 | 預設 | 範圍 | 意思 | 建議 |
|---|---|---|---|---|
| `HEARTBEAT` | `60` | 10～600 秒 | 感測小幫手每幾秒把全部狀態重新讀一次。平常都靠事件通知，這只是安全網：萬一漏掉事件，最多這麼久會補上；也用來確認小幫手還活著。越小越即時、越耗電 | `60` |
| `NOTIFY_COOLDOWN` | `600` | 0～86400 秒 | 同一種通知最短間隔 | `600` |
| `RETRY_SECONDS` | `30` | 5～3600 秒 | 啟用或恢復睡眠失敗時，隔幾秒重試（太頻繁會在系統紀錄留下一大堆 sudo 失敗） | `30` |
| `CMD_TIMEOUT` | `5` | 1～60 秒 | 外部指令（`sudo`、`pmset`）最多等幾秒，超過就放棄 | `5` |
| `LOG_MAX_KB` | `1024` | 64～102400 KB | 紀錄檔超過這個大小就換新檔（舊的留一份 `termawake.log.1`） | `1024` |

> 從 1.2 版升級：`INTERVAL`（每幾秒檢查一次）已經不用了，因為 1.3 版改成等 macOS 的事件通知。安裝程式會自動移除它。

---

## 移除

```bash
termawake uninstall
```

它會依序：停止監視程式 → 確認睡眠設定已經改回來 → 刪除所有檔案 → 刪除免密碼規則（會問一次密碼）。

想確認移除乾淨：

```bash
pmset -g | grep SleepDisabled    # 出現 0 或沒有輸出 = 正常睡眠
ls /etc/sudoers.d/                # 裡面不應該有 termawake
```

> 📝 **唯一的小痕跡**：只要執行過一次 `pmset -a disablesleep`，macOS 就會在系統的電源設定檔裡記下 `SleepDisabled` 這個項目。移除後它的值是 `false`（= macOS 預設的「正常睡眠」），所以 `pmset -g` 會多顯示一行 `SleepDisabled 0`，但**行為和從來沒裝過完全一樣**。

<details>
<summary>如果 <code>termawake</code> 指令不見了，手動移除的方法</summary>

```bash
launchctl bootout gui/$(id -u)/io.github.jhongwe1.termawake
sudo pmset -a disablesleep 0
sudo rm /etc/sudoers.d/termawake
rm -f ~/Library/LaunchAgents/io.github.jhongwe1.termawake.plist ~/.local/bin/termawake
rm -rf ~/Library/Application\ Support/TermAwake ~/Library/Logs/TermAwake
```

</details>

### 安裝了哪些東西？

| 位置 | 是什麼 |
|---|---|
| `~/Library/Application Support/TermAwake/` | 程式本體 `termawake`、感測小幫手 `tawatch`（安裝時用你電腦上的編譯器編譯）、設定檔、狀態檔 |
| `~/.local/bin/termawake` | 捷徑，讓你可以直接輸入 `termawake` |
| `~/Library/LaunchAgents/io.github.jhongwe1.termawake.plist` | 讓 macOS 登入時自動啟動監視程式 |
| `~/Library/Logs/TermAwake/` | 紀錄檔 |
| `/etc/sudoers.d/termawake` | 免密碼規則（只允許兩條指令） |

**不會**修改你的 `~/.zshrc`、`~/.claude/settings.json` 或其他任何設定檔。

---

## 安全性

### 為什麼要密碼？

要讓 Mac「合上蓋子也不睡」，唯一可靠的方法是 `pmset -a disablesleep 1`，而這需要管理員權限。
如果每次都要你輸入密碼，就不可能自動化了。所以 TermAwake 在 `/etc/sudoers.d/termawake` 加了一條規則：

```
Cmnd_Alias TERMAWAKE_PMSET = /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
你的帳號 ALL = (root) NOPASSWD: TERMAWAKE_PMSET
```

### 會不會危險？

- 只有這**兩條一字不差**的指令可以免密碼。`sudo pmset -a sleep 0`、`sudo pmset disablesleep 1`（少了 `-a`）、`sudo whoami`……全部照樣要密碼，安裝時也會自動驗證這一點。
- 最壞的情況：就算電腦裡有惡意程式，它能做的也只有「讓你的 Mac 不睡覺」，拿不到其他權限。
- 規則寫入前會先用 `visudo` 檢查語法，失敗就整個取消。（sudoers 寫壞的話，整台電腦的 `sudo` 都會不能用，所以這一步很重要。）
- 感測小幫手 `tawatch` **沒有任何特殊權限**，而且只讀取狀態，從來不改設定。
- **零網路**：TermAwake 不連網、不收集任何資料、沒有自動更新。
- **不讀你的內容**：只看「程式名稱」和「有沒有程式在要求保持清醒」，不讀 prompt、不讀終端機裡的文字。

---

## 運作原理

```
 macOS 的事件通知：蓋子、電源和電量、溫度、低耗電模式、App 開關、外接螢幕、睡眠設定被改、睡醒
        │
        ▼
 tawatch（感測小幫手，src/tawatch.m）── 只負責「看」，平常停著等通知，不佔 CPU
        │ 有變化就寫一行「目前狀態」，例如：app=Terminal batt=1 pct=81 lid=1 therm=0 …
        ▼
 FIFO（具名管道，~/Library/Application Support/TermAwake/wake）
        │
        ▼
 監視程式（bin/termawake run）── 唯一做決定、唯一會改設定的程式；平常不開任何子程式
        ├─ 該禁止睡眠嗎？          → sudo -n pmset -a disablesleep 1 或 0（免密碼規則只允許這兩條）
        ├─ 蓋子剛合上？            → pmset displaysleepnow（關螢幕）
        └─ 恢復睡眠時蓋子合著？    → pmset sleepnow（立刻睡）
```

### 怎麼決定要不要禁止睡眠

```
 Terminal 開著嗎？ ───────────── 沒有 ──► 恢復睡眠
   │ 有
 暫停中嗎？ ───────────────────── 是 ───► 恢復睡眠
   │ 不是
 太熱嗎？（溫度壓力 ≥ 2）──────── 是 ───► 恢復睡眠（降溫 5 分鐘後才會再啟用）
   │ 不是
 用電池而且低於 20%？ ─────────── 是 ───► 恢復睡眠（接上電源後才會再啟用）
   │ 不是
 用電池又開了低耗電模式？ ─────── 是 ───► 恢復睡眠
   │ 不是
 禁止睡眠（SleepDisabled = 1）
   └─ 蓋子一合上：立刻關螢幕
「恢復睡眠」時如果蓋子合著、又沒接外接螢幕 → 立刻讓 Mac 睡
```

### 安全網：就算出事，也一定會改回來

| 發生什麼事 | TermAwake 怎麼處理 |
|---|---|
| 登出、關機、重新開機 | 收到系統的結束訊號 → 先改回來才結束 |
| 程式本身出錯 | 結束前的收尾程式（EXIT trap）→ 先改回來 |
| 被 `kill -9` 強制砍掉（這個沒辦法攔截） | launchd 自動重開 → 看到「標記檔」→ 收拾 |
| 當機、斷電 | 下次登入時自動啟動 → 看到標記檔 → 收拾 |
| 感測小幫手當掉或卡住 | 立刻重新啟動；一直失敗 → **恢復正常睡眠**（不確定的時候選安全的一邊）並發通知 |
| `sudo`、`pmset` 卡住 | 每個外部指令都有時間上限（預設 5 秒），不會拖住監視程式 |
| 別的程式或你自己把 SleepDisabled 改回 0 | 當成你手動覆寫 → 進入暫停、發通知，不會跟你搶 |
| 你自己原本就設了 `SleepDisabled = 1` | 完全不碰，也不會自作主張改回 0 |

「標記檔」的規則很簡單：**改設定之前先寫標記，改回來之後才刪標記**。只要看到標記，就代表上次可能沒收拾好。

### 感測小幫手看的是哪些通知

| 要知道的事 | 用的 macOS 通知（全部是公開介面，不需要特殊權限） |
|---|---|
| Terminal 開了、關了 | `NSWorkspace` 的 App 啟動／結束通知；結束另外用核心的程序結束通知 |
| 電源、電量 | `notify(3)`：`com.apple.system.powersources.source`、`.percent`、`.lowbattery` |
| 溫度 | `notify(3)`：`com.apple.system.thermalpressurelevel` |
| 低耗電模式 | `NSProcessInfoPowerStateDidChangeNotification` |
| 蓋子 | IOKit：`IOPMrootDomain` 的 `kIOPMMessageClamshellStateChange` |
| 外接螢幕 | CoreGraphics：`CGDisplayRegisterReconfigurationCallback` |
| SleepDisabled 被改 | `notify(3)`：`com.apple.system.powermanagement.prefschange`（`pmset` 改完設定一定會發） |
| 有沒有程式要求保持清醒（只在 `MODE=work` 或 `IDLE_MINUTES` 打開時） | `notify(3)`：`com.apple.system.powermanagement.assertions.anychange` |
| 設定檔被修改 | 核心的檔案變更通知（kqueue） |

另外每 60 秒（`HEARTBEAT`）會把全部重新讀一次當作安全網，也讓監視程式知道小幫手還活著。

---

## 開發過程

### 為什麼要做這個？

我用的是 **MacBook Air 13 吋（M5、24GB 記憶體、1TB）**，平常用 [Claude Code](https://claude.com/claude-code) 在 Terminal 裡寫程式。

Claude Code 常常一跑就是好幾分鐘、甚至更久。我希望它在做事的時候，**我可以直接把蓋子合上**，讓 Claude Code 和 Terminal 裡的其他程式繼續跑。
但 MacBook 合上蓋子就會睡，一睡就全部停了。

我想要的效果是：

1. 只要 Terminal 開著，合上蓋子也不睡（螢幕關掉沒關係）
2. Terminal 完全結束後，自動恢復原本的設定
3. 全自動，不用我手動打指令；開很多個視窗也只會有一個監視程式
4. 用電池而且電量低於 20% 時，自動恢復正常睡眠；就算程式異常結束，也要確保設定會改回來
5. 需要 `sudo` 的話，只開放那兩條指令免密碼

### 遇到的困難和解決方法

#### 1. `caffeinate` 擋不住「合上蓋子」

macOS 內建的 `caffeinate` 是最常見的防睡眠工具。用 `pmset -g assertions` 查看時還發現，**Claude Code 自己就會執行 `caffeinate`**。
但是 `caffeinate` 只能擋「閒置太久自動睡」，擋不住「合上蓋子就睡」，除非同時接著外接螢幕和電源。

**解法：** 改用 `pmset -a disablesleep 1`。這是系統層級的「禁止睡眠」開關，合上蓋子也有效。代價是需要管理員權限。

#### 2. 需要管理員權限，但不想每次都輸入密碼

**解法：** 在 `/etc/sudoers.d/` 加一條規則，只開放「剛好那兩條」指令。過程中注意到幾個陷阱：

- `sudoers.d` 資料夾裡，**檔名有「.」的檔案會被直接忽略**（例如 `termawake.conf` 根本不會生效），所以檔名取為 `termawake`。
- sudoers 寫壞會讓**整台電腦的 `sudo` 都不能用**，所以先用 `visudo -cf` 檢查，通過了才放進去，失敗就取消。
- 程式裡呼叫 sudo 一律加上 `-n`：規則萬一不見了，會直接失敗，而不是卡住等密碼。

#### 3. 在 Terminal 裡，找不到 Terminal（`pgrep` 的陷阱）

一開始用 `pgrep -x Terminal` 檢查 Terminal 有沒有開，結果 Terminal 明明開著，它卻說沒有。
原因是 macOS 的 `pgrep`（從 FreeBSD 來的）**預設會把自己的「祖先程序」排除掉**。在 Terminal 裡執行的指令，祖先就是 Terminal，所以怎麼找都找不到。

**解法：** 加上 `-a`（include ancestors）。1.3 版改由感測小幫手直接讀程序清單（規則和 `pgrep -a -x -u 你的帳號` 一樣），不再需要 `pgrep`。

#### 4. 「打開 Terminal 時才啟動」這個想法有很多漏洞

原本的構想是在 `~/.zshrc`（每次打開 Terminal 都會執行的設定檔）裡啟動監視程式，但仔細分析後發現：

- 監視程式會變成 Terminal 的子孫 → 又會踩到上面 `pgrep` 的陷阱。
- 關視窗時，Terminal 會跳出「要終止執行中的程序嗎？」的警告。
- 用 `.command` 檔或不是 zsh 的 shell 打開 Terminal 時，根本不會讀 `.zshrc`。
- 如果舊的監視程式正要結束、剛好又開了新視窗，可能會變成**沒有任何監視程式在跑**。

**解法：** 改用 macOS 內建的 **launchd**（LaunchAgent）。登入時就啟動，平常不耗電；它天生保證同一時間只會有一個，當掉還會自動重開。
對使用者來說體驗完全一樣：打開 Terminal 就生效，不用打任何指令，而且完全不用改 `.zshrc`。

#### 5. 這個開關會「寫進硬碟」，重開機之後還在

實測發現，`pmset -a disablesleep 1` 會寫進 `/Library/Preferences/com.apple.PowerManagement.plist`。Apple 開源的 powerd 原始碼也顯示，開機時會從這個檔案把設定重新套用（`PMSettings.m`）。（重開機後是否真的還在，目前還沒有用「先暫停、手動設定、再重開機」的方式完整實測過。）
也就是說，萬一監視程式被強制砍掉、當機或斷電，Mac 可能從此再也不睡覺。

**解法：** 「標記檔」加上多層安全網（見[運作原理](#運作原理)）。實測 `kill -9` 之後，launchd 在 **0.57 秒**內就重開了監視程式，而且直接接手，設定全程沒有中斷。

#### 6. 等待中收到「關機訊號」，竟然要 30 秒才反應

一開始用 zsh 內建的 `zselect -t` 來「等 5 秒」。實測發現：等待的途中收到 `TERM`（關機、登出時系統送的結束訊號），它不會馬上醒來，而是**等到時間到了才處理**。把等待時間設成 30 秒時，真的拖了 **30.02 秒**。這會拖慢關機。

**解法：** 改用 FIFO（具名管道）搭配 `read -t`：收到訊號後 **0.01 秒**內就處理。
這個 FIFO 後來變成整個程式的中樞：感測小幫手的資料、`termawake pause` 的請求，全部都從這裡送進來。

#### 7. 蓋子合著時電量變低，光把設定改回來還不夠

電量低於 20% 時把設定改回 0。但如果**蓋子本來就合著**，macOS 不會再收到一次「合上蓋子」的事件；再加上 Claude Code 的 `caffeinate` 擋住了閒置睡眠，Mac 就會一直醒著，直到沒電為止。（Apple 的核心原始碼也證實：改 SleepDisabled 只會設定一個變數，不會叫核心重新判斷要不要因為合蓋而睡。）

**解法：** 蓋子合著、又沒有接外接螢幕時，主動執行 `pmset sleepnow` 讓它睡。系統正在關機或登出時不會做這個動作，以免干擾關機。

#### 8. 第二個監視程式差點把第一個的工作關掉

「同時只能有一個監視程式」是用檔案鎖做的。但如果「結束前自動收拾」的程式碼放在「拿鎖」**之前**，第二個監視程式拿不到鎖、準備離開時，會**順手把第一個設好的防睡眠關掉**。

**解法：** 先拿到鎖，才設定收拾機制。自動測試裡有一項專門檢查這件事。

#### 9. 其他小坑

- **程式不能放在桌面**：桌面、文件、下載資料夾受 macOS 隱私保護，背景程式讀不到。所以安裝時會複製到 `~/Library/Application Support/`。
- **`pmset -g` 的顯示方式**：這個設定從來沒被改過時，`pmset -g` 根本不會列出 `SleepDisabled`；設定過一次之後才會一直出現。程式要把「沒出現」當成 0。
- **電量在 19%、20% 之間跳動**，會一直切換開關 → 加上「低電量鎖定」：觸發之後，要接上電源才會解除。
- **免密碼規則壞掉時一直重試**，會在系統紀錄留下一大堆 sudo 失敗 → 失敗後改成 30 秒才重試一次。
- **測試時不能用「複製的系統程式」假裝成 Terminal**：macOS 會直接把它砍掉（exit 137），因為系統程式有「啟動限制」（launch constraints）→ 改用假的感測資料來測試。

#### 10. 合上蓋子，螢幕卻還亮著（實際使用才發現）

裝好之後我實際使用時發現：**沒有 TermAwake 時，蓋子合到某個角度螢幕就會關；裝了 TermAwake 之後，合到那個角度螢幕不會關。**

說明文件一開始寫著「合上蓋子時螢幕一定是關的」，但這句話其實沒有經過實際測試。查系統紀錄（`pmset -g log`）才找到原因：

- 平常合上蓋子時，macOS 是在「讓 Mac 睡覺」的同時，**順便**把螢幕關掉。紀錄裡 `Clamshell Sleep`（合蓋睡眠）和 `Display is turned off`（螢幕關閉）會在同一秒出現。
- TermAwake 擋住了睡眠，這個「順便關螢幕」也就跟著不見了。螢幕要等閒置計時（用電池 2 分鐘、接電 10 分鐘）到了才會關。

**解法：** 蓋子一合上，就用 `pmset displaysleepnow` 關螢幕（這個指令不需要管理員權限）。「怎麼知道蓋子合上了」改了三次：

- **1.1 版：每秒檢查一次蓋子。** 做法簡單，但耗電偏高（見第 11 點）。
- **1.2 版：改成「等系統通知」。** 寫了一個 C 小程式 `lidwatch`，向 macOS 登記「蓋子狀態改變」的通知。實測合蓋後約 1.2 秒螢幕關掉，其中約 1 秒花在用 `system_profiler` 數外接螢幕。
- **1.3 版：併進感測小幫手 `tawatch`。** 外接螢幕改用 CoreGraphics 直接數（每次不到 1 毫秒，不再需要 `system_profiler`），而且蓋子一動就送出完整狀態。實機量測（2026-11-10 12:32，用電池、沒接外接螢幕）：核心在 37.024 秒記錄「蓋子合上」，TermAwake 在 37.082 秒送出關螢幕的請求，**只花 58 毫秒**（1.2 版是 1.22 秒）。

**學到的事：** 沒有實際測過的行為，不要寫成「一定」。

#### 11. 量耗電差點量錯：`ps` 沒有把子程式算進去

我問「裝了 TermAwake，正常使用時會多耗多少電？」，第一次的回答是「只佔一顆 CPU 核心的 0.08%」。這個數字是錯的：

- 那是用 `ps -S` 量的。照說明它應該會把「已經結束的子程式」也算進去，但在這台 macOS 上**實測並沒有**。TermAwake 1.x 的工作幾乎都交給子程式做（`pgrep`、`pmset`、`ioreg`），所以等於只量到冰山一角。
- 改用系統核心的資源統計（`proc_pid_rusage`，包含所有子程式）重新量，才得到正確的數字。

**學到的事：** 量測工具也要驗證。用兩種不同的方法交叉比對，才發現第一種方法漏算了。

#### 12. 1.3 版：從「每 5 秒檢查一次」變成「完全靠事件」

1.2 版的監視程式每 5 秒醒來一次，每次開兩個子程式（`pgrep` 看 Terminal、`pmset -g batt` 看電量）。1.3 版的目標是：**沒事的時候完全不動**。

做法是把「感測」和「決定」分開：

- **感測**交給新的感測小幫手 `tawatch`（Objective-C，大約 490 行）。它向 macOS 訂閱所有需要的通知（見[運作原理](#感測小幫手看的是哪些通知)），平常停在那裡等，有變化才送出一行狀態。
- **決定**留在原本的 zsh 監視程式裡（這部分有完整的自動測試）。它平常停在 FIFO 前面等，收到一行才重新判斷；連搬檔案、刪檔案都改用 zsh 內建的指令，所以平常**一個子程式都不開**。

過程中實際踩到、量到的事：

- **「有程式要求保持清醒」的通知，訂了卻完全收不到。** 實測 14 秒內開關了兩次 `caffeinate`，一個事件都沒有。讀 Apple 開源的 powerd 原始碼才發現：powerd 只有在「有程式先用另一個函式登記過」時才會發這個通知（`PMAssertions.c`）。登記之後就收得到了：閒置的 2 分鐘裡平均每秒 0.33 個，偶爾一口氣來好幾個，所以小幫手會把 0.25 秒內的事件合併成一次處理。
- **「任何電源變化」的通知太吵。** 接著電源、電量沒變的 5 分鐘裡，它還是觸發了 11 次；「電量百分比改變」和「電源來源改變」這兩個通知則是 0 次。所以只訂後面兩個。
- **SleepDisabled 被別人改掉，也能立刻知道。** `pmset` 改完設定後一定會發 `prefschange` 通知（Apple 原始碼 `IOPMEnergyPrefs.c`；實測就算設成一樣的值也會發）。但核心是 powerd 收到通知後才更新，所以小幫手會等 0.5 秒再讀。
- **小幫手當掉要怎麼馬上知道？** 原本想用 zsh 的 `CHLD` 訊號，實測發現在等待 FIFO 的時候它根本不會觸發。改成用一個小的子 shell 包住小幫手：小幫手不管怎麼結束（包括 `kill -9`），子 shell 都會馬上寫一行 `D` 進 FIFO。自動測試裡從 `kill -9` 到重新啟動不到 0.5 秒。
- **子 shell 會不會把收尾程式帶走？** 監視程式結束前會「改回睡眠設定」。如果子 shell 也帶著這段收尾程式，它一結束就會誤把設定改回來。實測 zsh 的子 shell 不會執行主程式的 EXIT 收尾，但保險起見，每個子 shell 開頭都明確清掉。
- **記憶體**：小幫手用了 AppKit（為了收到 App 開關的通知），實際佔用約 2.5 MB，比 1.2 版的 `lidwatch`（約 1.5 MB）多 1 MB。

#### 13. 一個從來沒有作用過的判斷

1.2 版判斷「用電池」的方式，除了看 `Battery Power`，還會看 `pmset -g batt` 的輸出有沒有 `discharging`，想抓「插著電、但充電器瓦數不夠，電量還在往下掉」的情況。這次讀了 `pmset` 的原始碼才發現：只要是插著電，它印的永遠是 `AC attached; not charging`，**根本不會印 `discharging`**。所以那個判斷從來沒有作用過，自動測試測的也是一個真實世界不會出現的輸出。

**解法：** 1.3 版直接讀電池的電流：插著電、沒在充電、電流卻是負的，就當成「用電池」。

#### 14. Claude Code 什麼時候會擋睡眠？

我想知道 Claude Code 自己的 `caffeinate` 什麼時候開、什麼時候關，所以讀了我電腦上 Claude Code（2.1.322）的程式碼：

- 只有在「正在工作」時才執行 `caffeinate -i -t 300`，每 240 秒換一個新的。
- 工作結束 30 秒後就把它關掉。

也就是說，`caffeinate` 本身就是一個「Claude 正在工作」的訊號，**不用安裝任何 hook、不用改 `~/.claude/settings.json`**。1.3 版用它做了兩個選項（預設都關閉）：`MODE=work`（只有在工作時才不睡）、`IDLE_MINUTES`（合蓋用電池時，太久沒工作就睡）。這個行為是 Claude Code 內部的設計，以後的版本可能會改；`termawake doctor` 會列出目前是誰在要求保持清醒。

#### 15. 過熱保護為什麼不能關

讀 Apple 的核心原始碼（xnu `IOPMrootDomain.cpp`）時發現：SleepDisabled 是「所有睡眠」的總開關，連 macOS **在過熱時為了自救而進入的緊急睡眠**也會被它擋掉。所以過熱保護不是加分功能，而是把 SleepDisabled 拿走的那道安全網補回來。

溫度壓力等級從 0（正常）到 4（即將緊急睡眠）。TermAwake 在等級 2（重度）就恢復睡眠；如果蓋子合著，會立刻讓 Mac 睡。之後要連續 5 分鐘低於門檻才會再啟用，避免在門檻附近一直切換。蓋子開著的時候「恢復睡眠」不會讓 Mac 馬上睡著，你正在做的事不會被打斷。

#### 16. 量耗電（1.3 版）

這次用的是核心的 `proc_pid_rusage`（第 6 版）。它除了 CPU 時間，還記錄每個程序的**喚醒次數**和 **CPU 能耗**（單位奈焦耳）。過程中又踩到一個坑：它的時間單位不是奈秒，而是 CPU 的計時刻度（Apple Silicon 每秒 2400 萬次），要乘上 125/3 才是奈秒。沒換算的話，數字會小 40 倍。

量法：同一台 Mac（MacBook Air M5，用電池），Terminal 開著、防睡眠生效中，每組量 180 秒。1.2 版是當時正在使用的那一份；1.3 版用一份測試用的實例（假的 `sudo`／`pmset`，不會動到真正的設定，設定檔是完整說明版），兩者都用背景優先權（和 launchd 的 `ProcessType=Background` 一樣）。

| 項目 | 1.2 版 | 1.3 版 |
|---|---|---|
| CPU 時間（監視程式＋所有子程式＋小幫手） | 每秒 6.48 毫秒 | **每秒 0.056 毫秒**（約 1/116） |
| 喚醒 CPU 的次數 | 每秒 0.64 次 | **每秒 0.02 次**（約 1/30） |
| 開啟的子程式 | 每 5 秒 2 個（`pgrep`、`pmset`） | **0 個** |
| CPU 能耗（核心的計數器） | 監視程式本身 78 µW，另外還有子程式的部分（計數器不含已結束的子程式；用同樣的比例估算約 0.5 mW） | **約 4 µW**（全部，沒有子程式） |

Terminal 沒開的時候也差不多：每秒 0.060 毫秒 CPU、每秒 0.02 次喚醒、約 7 µW（1.2 版這時還是每 5 秒開一次 `pgrep`）。事件驅動的程式，耗電不太會跟著狀態變。

**真正安裝之後才發現的問題：** 第一次量正式安裝的版本，CPU 是每秒 0.28 毫秒，比測試實例高 5 倍。追下去發現差別在設定檔：測試實例的設定檔只有 1 行，正式安裝的是附完整說明的版本（90 行、約 6 KB）。監視程式每次醒來都會重讀設定檔，而 zsh 的 `read` 一次只讀 **1 個位元組**（zsh 5.9 原始碼 `Src/builtin.c`：`read(readfd, &cc, 1)`），所以每醒來一次就要花 **14 毫秒**（背景優先權；前景實測一行一行讀 2.7 毫秒、一次讀進 0.16 毫秒）。改成一次讀進整個檔案之後是 4 毫秒；再改成「設定檔的指紋（inode、大小、修改時間）沒變就不重讀」（感測小幫手也會在設定檔被修改時通知），每次醒來只剩 **1.35 毫秒**。上表就是修正後的數字。在那之前，我用一個小測試量出「設定檔解析只要 1 毫秒」，後來才發現那個測試寫錯了：它根本沒有載入要測的函式。是正式安裝版的實測把這兩個錯誤一起揪出來的。

整台 Mac 使用中大約 3 W，合著蓋子、沒在做事時大約 1 W。1.3 版的 4 µW 只有整台的幾十萬分之一，等於量不出來。1.2 版 README 寫的「約 5 mW」是用整台耗電的放大實驗量的（誤差很大，可能差到一倍），包含了子程式和 powerd 回應查詢的成本，所以比上面的 CPU 能耗大，兩者並不矛盾。

**結論：** TermAwake 自己的耗電已經可以忽略；真正耗電的是「Mac 不睡覺」這件事本身。

### 怎麼驗證的？

- **自動測試 164 項**：用假的 `pmset`、`sudo`、感測小幫手模擬各種情況。假的 `sudo` 會像真的 sudoers 一樣，只放行那兩條指令，程式只要多呼叫了任何一條指令，測試就會失敗。也會實際編譯感測小幫手（`-Wall -Wextra -Werror`），測試它的事件、`--once`、父程式死掉就跟著結束。
- **突變測試**：故意把 10 個關鍵修正改回錯的寫法，看測試抓不抓得到。抓到 9 個：拿掉過熱保護、電量下限、設定被改的偵測、低電量鎖定、低耗電、失效時恢復睡眠、指令逾時、restore 保留標記、接手後的狀態。第一輪「接手後的狀態」其實沒抓到（測試只檢查設定沒變，沒檢查狀態），補強測試後才抓到。剩下 1 個抓不到：拿掉「小幫手結束時寫的 D 行」的處理。原因是 D 行本身就會叫醒監視程式，接著 `kill -0` 也會發現小幫手不在了；D 行處理只是為了消除兩者之間極小的時間差，測試沒辦法穩定重現那個瞬間。過程中也抓到一個測試本身的時間差：測試在「打開蓋子」後立刻下指令，監視程式還沒收到新狀態。已經改成每次改變狀態都等監視程式收到才繼續。
- **實機驗證（MacBook Air M5／macOS 26.6）**：感測小幫手在這台 Mac 上讀到的電量、電源、溫度、低耗電模式、蓋子、外接螢幕、核心的 SleepDisabled 都正確；App 開關、設定檔修改、`caffeinate` 開關、`pmset` 改設定的通知都收得到；用臨時的 launchd 服務（背景優先權，和正式安裝一樣）跑，也收得到 App 開關的通知。`termawake doctor` 在真實的系統上跑過一次。1.x 版的實測（`kill -9` 0.57 秒接手、暫停 1 秒內生效、只放行兩條 sudo 指令、移除乾淨）仍然適用。
- **實機合蓋**：1.3 版合上蓋子到送出關螢幕請求 58 毫秒（見第 10 點），合蓋期間 Mac 沒有睡著。
- **還沒在實機上測過的**（請用上面的測試 3～5 確認）：實際按 `⌘Q` 結束 Terminal 後多快恢復睡眠（App 結束的通知本身已經用 Calculator 驗證過）、用電池時的低耗電模式觸發、背景程式發的通知會不會顯示。過熱觸發無法安全地實測。

### 開發工具

這個專案是我和 [Claude Code](https://claude.com/claude-code)（Anthropic 的 AI 程式助手）一起完成的：我提出需求和想法，Claude Code 負責調查系統行為、設計架構、寫程式與測試，過程中一起討論取捨。

---

## 常見問題

**Q：會很耗電嗎？**
TermAwake 自己幾乎不耗電（數字見[開發過程第 16 點](#16-量耗電13-版)）。真正耗電的是「Mac 不睡覺」這件事本身：合著蓋子、沒在做事的 Mac 還是會用掉大約 1 W。所以不用的時候請按 `⌘Q` 關掉 Terminal，或執行 `termawake pause`；常放包包的話，打開 `IDLE_MINUTES`。

**Q：可以用在 iTerm2 嗎？**
可以。安裝時會自動判斷，也可以直接指定：`./install.sh --app iTerm2`。

**Q：Claude Code 跑在 Cursor 或其他編輯器的終端機裡呢？**
把那個 App 的程序名稱加進 `APPS`（例如 `APPS=Terminal Cursor`），或改用 `MODE=work`：它看的是「有沒有程式要求保持清醒」，不管 Claude Code 跑在哪裡。

**Q：合上蓋子後，網路會斷嗎？**
不會。Mac 沒有睡著，Wi-Fi 會保持連線。可以用[測試 2](#測試-2合上蓋子測試最重要的一個)自己確認。

**Q：我會用手機遠端控制 Claude Code，要注意什麼？**
用預設的 `MODE=app` 就好：Terminal 開著時 Mac 一直醒著，手機隨時連得到。不要用 `MODE=work`：Claude 做完之後，合著蓋子的 Mac 會睡著，手機就連不到了。

**Q：螢幕會一直亮著嗎？**
不會。蓋子打開時，螢幕照你原本的設定自動關掉；蓋子合上時，TermAwake 一收到通知就關螢幕。可以用[測試 2](#測試-2合上蓋子測試最重要的一個) 的進階版親自確認。

**Q：接外接螢幕（合蓋使用）會受影響嗎？**
不會。偵測到外接螢幕時，TermAwake 不會關螢幕，也不會主動讓 Mac 睡。

**Q：重新開機之後還有效嗎？**
有。登入後會自動啟動。

**Q：我之前自己設過 `sudo pmset -a disablesleep 1`，會被改掉嗎？**
不會。TermAwake 會發現這不是它設的，完全不碰，Terminal 關掉時也不會把它改回 0。

**Q：Terminal 開著，我自己執行了 `sudo pmset -a disablesleep 0`，會怎樣？**
TermAwake 會在幾秒內發現，當成你想讓 Mac 睡，所以進入暫停並發通知，不會跟你搶。要恢復就輸入 `termawake resume`。

**Q：`kill` 掉監視程式之後，為什麼它又跑回來了？**
這是故意的：它由 launchd 管理，當掉或被砍掉都會自動重開，以確保設定一定會被正確處理。真的想停掉就用 `termawake uninstall`。

---

## 系統需求

- macOS（在 macOS 26.6、MacBook Air M5 上測試；其他版本沒有測試過）
- 管理員帳號（安裝和移除時各輸入一次密碼）
- Xcode 命令列工具（用來在你的電腦上編譯感測小幫手；`git clone` 本身也需要它）。安裝方式：`xcode-select --install`
- Terminal.app 或 iTerm2

## 檔案結構

```
TermAwake/
├── README.md             說明文件（就是這份）
├── CHANGELOG.md          版本紀錄
├── LICENSE               授權（MIT）
├── install.sh            安裝程式
├── uninstall.sh          移除程式
├── bin/termawake         監視程式 + 所有指令（zsh）
├── src/tawatch.m         感測小幫手（Objective-C，安裝時編譯）
└── tests/run-tests.zsh   自動測試
```

## 授權

[MIT](LICENSE)
