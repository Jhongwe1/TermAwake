# TermAwake 使用指南

> 這份是給一般使用者的一步一步說明。想知道它為什麼這樣設計、怎麼證明它是對的，請看 [README](../README.md)。

- [這是什麼？](#這是什麼)
- [安裝（3 步驟）](#安裝)
- [日常使用](#日常使用)
- [使用前一定要知道的事](#使用前一定要知道的事)
- [怎麼確認它有效？](#怎麼確認它有效)
- [設定](#設定)
- [移除](#移除)
- [遇到問題怎麼辦](#遇到問題怎麼辦)
- [常見問題](#常見問題)

---

## 這是什麼？

MacBook 有個習慣：**蓋子一合上就去睡覺**。
睡著的時候，所有程式都會暫停：Claude Code 寫到一半的程式、正在下載的檔案、跑到一半的編譯，全部停住，網路也會斷。

TermAwake 是一個在背景幫你顧門的小幫手：

- 👀 **Terminal 有沒有開著？** macOS 一有變化就會通知它，它不用一直去問，所以幾乎不耗電。
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
| Mac 太熱 | 🌡 恢復正常；蓋子合著就**馬上**睡；降溫 5 分鐘後自動恢復 |
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

> 💡 如果跳出「需要安裝命令列開發者工具」的視窗：按「安裝」，等它裝完（幾分鐘），再貼一次上面四行。TermAwake 需要這個免費工具，在你的電腦上編譯一個小程式（感測小幫手 `tawatch`）。
>
> 💡 不想用 git？在 GitHub 網頁按綠色的 **Code → Download ZIP**，解壓縮後在 Terminal 輸入：
> `cd ~/Downloads/TermAwake-main && zsh install.sh`
> 沒有命令列開發者工具的話，安裝程式會告訴你怎麼裝，而且在那之前什麼都不會改。

### 第 3 步：輸入密碼

安裝到一半會請你輸入 **Mac 的登入密碼**（就是開機時輸入的那組）。

- 在 Terminal 裡打密碼時，**畫面不會出現任何字**。這是正常的，打完按 Enter 就好。
- 為什麼需要密碼？要讓 Mac 合上蓋子也不睡，必須用管理員權限執行 `pmset`。安裝程式會建立一條規則，**只允許兩條一字不差的指令**免密碼（`pmset -a disablesleep 1` 和 `0`），其他所有 sudo 指令照樣要密碼。只有安裝和移除時需要輸入密碼。

看到 `🎉 安裝完成！` 就好了。以後**什麼都不用做**：打開 Terminal 就會自動生效。

> 用 iTerm2 的話：`./install.sh --app iTerm2`（安裝程式通常會自動判斷）。
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

  監視程式    執行中（PID 73708；登入時自動啟動，當掉會自動重開）
  感測小幫手  正常（等 macOS 的事件通知，平常不佔 CPU）
  監視對象    Terminal：開著
  電源        電池 90%，使用電池中（低於 20% 會自動恢復睡眠）
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
| `termawake log` | 看最近的紀錄（什麼時候啟用、什麼時候恢復、為什麼）；`termawake log -f` 持續顯示 |
| `termawake config` | 看目前的設定，以及哪些值被自動修正過 |
| `termawake doctor` | **健康檢查**：一次檢查所有東西是否正常（只讀取，不會改任何設定） |
| `termawake restore` | 緊急：立刻恢復正常睡眠，並暫停 |
| `termawake uninstall` | 完全移除 |

### 想讓 Mac 睡覺，但不想關掉 Terminal？

```bash
termawake pause
```

然後合上蓋子，Mac 就會正常睡。暫停會在 Terminal 完全結束或重新開機後自動解除；想馬上恢復就輸入 `termawake resume`。

---

## 使用前一定要知道的事

1. **收進包包前，先 `termawake pause`，或把 Terminal 完全結束（`⌘Q`）。**
   Terminal 開著時 Mac 不會睡，放在包包裡會一直耗電、發熱。TermAwake 有過熱保護（太熱就讓 Mac 睡），但包包裡散熱很差，MacBook Air 又沒有風扇，最好不要依賴它。常把 Mac 放包包的話，可以打開[合蓋閒置](#設定)：`IDLE_MINUTES=30`。
2. **只關視窗不等於關掉 Terminal。**
   按視窗左上角紅色的 ✕ 只會關掉視窗，Terminal 其實還開著（Dock 上的圖示下面還有一個小點）。要按 `⌘Q` 才是完全結束。
3. **Terminal 開著的時候，蘋果選單裡的「睡眠」沒有作用。**
   這是 macOS 的設計：這個開關是整台電腦共用的。想睡就先 `termawake pause`。
4. **合上蓋子時，螢幕由 TermAwake 負責關掉。** 擋住睡眠時，macOS 自己不會在合蓋時關螢幕，所以 TermAwake 一收到「蓋子合上」的通知就關螢幕（實測 0.06 秒）。接著外接螢幕時不會去動螢幕。
5. **合上蓋子後，多久會鎖定？** 平常合蓋時 Mac 會睡，打開要輸入密碼。擋住睡眠以後，鎖定改由「螢幕關閉後多久要求密碼」決定：如果設成 5 分鐘，合蓋後 5 分鐘內打開就**不用密碼**。建議改成「立即」：**系統設定 → 鎖定畫面 →「螢幕保護程式啟動或顯示器關閉後要求密碼」→ 立即**（實際名稱以你系統上的中文為準）。`termawake doctor` 會檢查這一項。

---

## 怎麼確認它有效？

### 測試 1：健康檢查（最快）

```bash
termawake doctor
```

會逐項檢查：監視程式、感測小幫手、免密碼規則、睡眠設定是否一致、有沒有其他同類工具在搶同一個開關、溫度、螢幕鎖定、FileVault、最近的錯誤。最後一行是 `結果：全部正常。` 就對了；有 ⚠️ 的項目會告訴你怎麼處理。

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
2. 再打開 Terminal，輸入 `termawake log`，應該會看到這兩行（第一行的時間就是你按 `⌘Q` 的那一秒）：
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

### 測試 6：別人改掉設定時，TermAwake 會讓步

1. Terminal 開著時執行（這條在免密碼規則裡，不用輸入密碼）：
   ```bash
   sudo pmset -a disablesleep 0
   ```
2. 一秒內會跳出 TermAwake 的通知，`termawake` 顯示 `⏸ 暫停中`。TermAwake 把這當成「你想讓 Mac 睡」，所以不跟你搶。
3. 輸入 `termawake resume` 恢復。

### 過熱保護怎麼測？

沒辦法安全地測：要讓 Mac 真的過熱，就得讓它長時間高溫運轉。在你的 Mac 上能確認的是「讀得到溫度等級」：`termawake` 的「溫度」那一列，或 `termawake doctor`。觸發流程由自動測試驗證。

---

## 設定

設定檔在 `~/Library/Application Support/TermAwake/config`。用「文字編輯」打開：

```bash
open -e ~/Library/Application\ Support/TermAwake/config
```

改完存檔就**立刻生效**，不用重新開機。設定檔裡每一項都寫了意思、範圍、預設值和建議值。填錯的值會被忽略（改用預設值），超出範圍的數字會被調到最近的合法值；`termawake config` 會列出哪些值被改了。

**常見的調整**

| 我想要… | 改這個 |
|---|---|
| 用 iTerm2，或 Terminal 和 iTerm2 都要 | `APPS=iTerm2` 或 `APPS=Terminal iTerm2` |
| Claude Code 跑在 Cursor 的終端機裡 | `APPS=Terminal Cursor` |
| 常把 Mac 放包包，怕忘了關 | `IDLE_MINUTES=30`：合蓋＋用電池＋30 分鐘沒有程式在工作，就讓 Mac 睡 |
| 只有 Claude Code 在做事時才不睡（最省電） | `MODE=work`。注意：Claude 做完後，合著蓋子的 Mac 會睡著，**手機遠端控制會斷** |
| 電池老化了，想早一點恢復睡眠 | `BATTERY_MIN=30` |
| 開低耗電模式時也要繼續不睡 | `LOW_POWER=ignore` |
| 合蓋時不要關螢幕 | `LID_DISPLAY_OFF=0` |
| 不要跳通知 | `NOTIFY=0` |

**全部設定**

| 設定 | 預設 | 範圍 | 意思 |
|---|---|---|---|
| `APPS` | `Terminal` | 程序名稱 | 要監視的 App，多個用空白隔開 |
| `MODE` | `app` | `app`／`work` | `app` = App 開著就不睡；`work` = 有程式要求保持清醒時才不睡 |
| `IDLE_MINUTES` | `0`（關） | 0～1440 | 合蓋＋用電池＋沒接外接螢幕時，幾分鐘沒有工作就睡（只在 `MODE=app` 有效） |
| `WORK_GRACE` | `60` | 10～3600 秒 | `MODE=work` 時，工作結束後再等幾秒 |
| `BATTERY_MIN` | `20` | 5～100 % | 用電池時，低於這個電量就恢復睡眠（不能低於 5） |
| `THERMAL_LIMIT` | `2` | 1～3 | 溫度壓力達到這個等級就恢復睡眠（不能關掉） |
| `THERMAL_COOLDOWN` | `300` | 60～3600 秒 | 過熱後要冷卻多久才重新啟用 |
| `LOW_POWER` | `release` | `release`／`ignore` | 用電池又開低耗電模式時：恢復睡眠／照樣不睡 |
| `LID_DISPLAY_OFF` | `1` | 0／1 | 合蓋時關螢幕 |
| `NOTIFY` | `1` | 0／1 | 發通知 |
| `HEARTBEAT` | `60` | 10～600 秒 | 安全網：每幾秒把全部狀態重新讀一次 |
| `NOTIFY_COOLDOWN` | `600` | 0～86400 秒 | 同一種通知最短間隔 |
| `RETRY_SECONDS` | `30` | 5～3600 秒 | 失敗後隔幾秒重試 |
| `CMD_TIMEOUT` | `5` | 1～60 秒 | `sudo`、`pmset` 最多等幾秒 |
| `LOG_MAX_KB` | `1024` | 64～102400 KB | 紀錄檔超過多大就換新檔 |

---

## 移除

```bash
termawake uninstall
```

它會依序：停止監視程式 → 確認睡眠設定已經改回來 → 刪除所有檔案 → 刪除免密碼規則（會問一次密碼）。

確認移除乾淨：

```bash
pmset -g | grep SleepDisabled    # 出現 0 或沒有輸出 = 正常睡眠
ls /etc/sudoers.d/                # 裡面不應該有 termawake
```

> 📝 **唯一的小痕跡**：只要執行過一次 `pmset -a disablesleep`，macOS 就會在系統的電源設定檔裡記下 `SleepDisabled` 這個項目。移除後它的值是 `false`（= macOS 預設的正常睡眠），所以 `pmset -g` 會多顯示一行 `SleepDisabled 0`，但**行為和從來沒裝過完全一樣**。

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
| `~/Library/Application Support/TermAwake/` | 程式本體 `termawake`、感測小幫手 `tawatch`、設定檔、狀態檔 |
| `~/.local/bin/termawake` | 捷徑，讓你可以直接輸入 `termawake` |
| `~/Library/LaunchAgents/io.github.jhongwe1.termawake.plist` | 讓 macOS 登入時自動啟動監視程式 |
| `~/Library/Logs/TermAwake/` | 紀錄檔 |
| `/etc/sudoers.d/termawake` | 免密碼規則（只允許兩條指令） |

**不會**修改你的 `~/.zshrc`、`~/.claude/settings.json` 或其他任何設定檔。

---

## 遇到問題怎麼辦

1. 先執行 `termawake doctor`，照 ⚠️／❌ 旁邊的建議處理。
2. 看最近發生了什麼：`termawake log 50`。
3. Mac 一直不睡、想立刻恢復：`termawake restore`（或手動 `sudo pmset -a disablesleep 0`）。
4. 還是不行：重新執行 `./install.sh`；或把 `termawake doctor` 和 `termawake log 50` 的輸出貼到 GitHub Issues（貼之前看一下有沒有你不想公開的資訊，例如路徑裡的帳號名稱）。

---

## 常見問題

**Q：會很耗電嗎？**
TermAwake 自己幾乎不耗電：實測每秒只用 0.056 毫秒 CPU，約 4 µW（整台 Mac 約 1～3 W）。真正耗電的是「Mac 不睡覺」本身：合著蓋子、沒在做事的 Mac 大約還是會用掉 1 W。所以不用的時候請按 `⌘Q` 關掉 Terminal，或執行 `termawake pause`；常放包包就打開 `IDLE_MINUTES`。

**Q：可以用在 iTerm2 嗎？**
可以。安裝時會自動判斷，也可以直接指定：`./install.sh --app iTerm2`。

**Q：Claude Code 跑在 Cursor 或其他編輯器的終端機裡呢？**
把那個 App 的程序名稱加進 `APPS`（例如 `APPS=Terminal Cursor`），或改用 `MODE=work`：它看的是「有沒有程式要求保持清醒」，不管 Claude Code 跑在哪裡。

**Q：合上蓋子後，網路會斷嗎？**
不會。Mac 沒有睡著，Wi-Fi 會保持連線。可以用[測試 2](#測試-2合上蓋子測試最重要的一個)自己確認。

**Q：我會用手機遠端控制 Claude Code，要注意什麼？**
用預設的 `MODE=app` 就好：Terminal 開著時 Mac 一直醒著，手機隨時連得到。不要用 `MODE=work`：Claude 做完之後，合著蓋子的 Mac 會睡著，手機就連不到了。

**Q：螢幕會一直亮著嗎？**
不會。蓋子打開時，螢幕照你原本的設定自動關掉；蓋子合上時，TermAwake 一收到通知就關螢幕。

**Q：接外接螢幕（合蓋使用）會受影響嗎？**
不會。偵測到外接螢幕時，TermAwake 不會關螢幕，也不會主動讓 Mac 睡。

**Q：重新開機之後還有效嗎？**
有。登入後會自動啟動。

**Q：我之前自己設過 `sudo pmset -a disablesleep 1`，會被改掉嗎？**
不會。TermAwake 會發現這不是它設的，完全不碰，Terminal 關掉時也不會把它改回 0。

**Q：Terminal 開著，我自己執行了 `sudo pmset -a disablesleep 0`，會怎樣？**
TermAwake 會在一秒內發現，當成你想讓 Mac 睡，所以進入暫停並發通知，不會跟你搶。要恢復就輸入 `termawake resume`。

**Q：`kill` 掉監視程式之後，為什麼它又跑回來了？**
這是故意的：它由 launchd 管理，當掉或被砍掉都會自動重開，以確保設定一定會被正確處理。真的想停掉就用 `termawake uninstall`。

**Q：會讀我的程式碼、prompt 或終端機內容嗎？**
不會。TermAwake 只看程式名稱、電源和溫度等系統狀態，不連網、不收集任何資料。
