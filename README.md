# TermAwake

> **只要 Terminal 開著，MacBook 合上蓋子也不會睡著；Terminal 一關，一切自動恢復原狀。**
>
> Keep your Mac awake — even with the lid closed — while Terminal is open. Everything is restored automatically when Terminal quits.

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

- 👀 每 5 秒看一次：**Terminal 有沒有開著？**
- ☕ 有開 → 叫 Mac 不准睡。合上蓋子也照樣跑，只是螢幕會關掉。
- 😴 Terminal **完全結束** → 把設定改回原本的樣子，Mac 恢復正常睡覺。
- 🪫 用電池而且電量**低於 20%** → 不管 Terminal 有沒有開，都讓 Mac 正常睡覺，保護電池。

| 情況 | Mac 會怎樣 |
|---|---|
| Terminal 開著，合上蓋子 | ✅ 繼續跑：程式、網路照常，只有螢幕關掉 |
| Terminal 完全結束（按 `⌘Q`） | 😴 恢復正常：合上蓋子就睡 |
| 用電池，電量低於 20% | 🪫 恢復正常；如果蓋子已經合著，會**馬上**讓 Mac 睡 |
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

> 💡 如果跳出「需要安裝命令列開發者工具」的視窗：按「安裝」，等它裝完，再貼一次上面四行。
>
> 💡 不想用 git？在這個網頁按綠色的 **Code → Download ZIP**，解壓縮後在 Terminal 輸入：
> `cd ~/Downloads/TermAwake-main && zsh install.sh`

### 第 3 步：輸入密碼

安裝到一半會請你輸入 **Mac 的登入密碼**（就是開機時輸入的那組）。

- 在 Terminal 裡打密碼時，**畫面不會出現任何字**。這是正常的，打完按 Enter 就好。
- 為什麼需要密碼？請看[安全性](#安全性)。只有安裝和移除時需要，平常不用。

看到 `🎉 安裝完成！` 就好了。以後**什麼都不用做**：打開 Terminal，幾秒內就會自動生效。

> 安裝程式會自動判斷你用的是 Terminal 還是 iTerm2。用 iTerm2 的話也可以直接指定：`./install.sh --app iTerm2`

---

## 日常使用

基本上你什麼都不用做。想看看它現在在做什麼，就在 Terminal 輸入：

```bash
termawake
```

會看到類似這樣的畫面：

```
  ✅ 防睡眠生效中：Mac 不會進入系統睡眠，合上蓋子也會繼續跑（蓋子合上時螢幕會關掉）

  監視程式    執行中（PID 68350；登入時自動啟動，當掉會自動重開）
  監視對象    Terminal：開著
  電源        電池 81%，使用電池中（低於 20% 會自動恢復睡眠）
  暫停        否
  系統設定    SleepDisabled = 1（TermAwake 設的；Terminal 結束後會改回 0）
  免密碼規則  已安裝（/etc/sudoers.d/termawake）
```

### 所有指令

| 指令 | 做什麼 |
|---|---|
| `termawake` | 看目前狀態 |
| `termawake pause` | **暫停**：讓 Mac 可以正常睡（例如要把電腦收進包包時） |
| `termawake resume` | 取消暫停 |
| `termawake log` | 看最近的紀錄（什麼時候啟用、什麼時候恢復、為什麼） |
| `termawake config` | 看設定 |
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
   Terminal 開著時 Mac 不會睡，放在包包裡會一直耗電、發熱。MacBook Air 沒有風扇，熱只能慢慢散出去。
2. **只關視窗不等於關掉 Terminal。**
   按視窗左上角紅色的 ✕ 只會關掉視窗，Terminal 其實還開著（Dock 上的圖示下面還有一個小點）。要按 `⌘Q` 才是完全結束。
3. **Terminal 開著的時候，蘋果選單裡的「睡眠」也會沒有作用。**
   這是 macOS 的設計：這個開關是整台電腦共用的。想睡就先 `termawake pause`。
4. **合上蓋子時，螢幕由 TermAwake 負責關掉。** 擋住睡眠的時候，macOS 自己**不會**在合蓋時關螢幕（詳見[開發過程第 10 點](#10-合上蓋子螢幕卻還亮著實際使用才發現)），所以 TermAwake 每秒檢查一次蓋子，一合上就關螢幕。蓋子打開時，螢幕照你原本的設定自動關閉；接著外接螢幕（桌面模式）時，TermAwake 不會去動螢幕。

---

## 怎麼確認它有效？

### 測試 1：看狀態

```bash
termawake
```

看到 `✅ 防睡眠生效中` 就對了。也可以用 macOS 內建的指令確認：

```bash
pmset -g | grep SleepDisabled
```

- `SleepDisabled 1` → 不會睡（TermAwake 正在作用）
- `SleepDisabled 0`，或什麼都沒出現 → 正常睡眠

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
2. 等 5 秒，再打開 Terminal。
3. 輸入 `termawake log`，應該會看到這兩行：
   ```
   RELEASE: Terminal 已經完全結束 → SleepDisabled=0（恢復正常睡眠）
   ENGAGE: Terminal 開著 ... → SleepDisabled=1（不會睡眠，合上蓋子也照跑）
   ```

### 測試 4：低電量保護（拔掉電源時才能測）

1. 拔掉電源。
2. 暫時把門檻調到 99%（比現在的電量還高）：
   ```bash
   sed -i '' 's/^BATTERY_MIN=.*/BATTERY_MIN=99/' ~/Library/Application\ Support/TermAwake/config
   ```
3. 等 5 秒，輸入 `termawake`，應該會看到 `🪫 電量低`。
4. 記得改回來：
   ```bash
   sed -i '' 's/^BATTERY_MIN=.*/BATTERY_MIN=20/' ~/Library/Application\ Support/TermAwake/config
   ```

### 測試 5：程式被強制砍掉，也會自己恢復

```bash
kill -9 $(cat ~/Library/Application\ Support/TermAwake/watcher.pid)
sleep 12; termawake log 5
```

會看到 `RECOVER` 和 `ADOPT`：macOS 自動把監視程式重新打開，而且接手原本的狀態。

### 給開發者：自動測試

```bash
zsh tests/run-tests.zsh
```

用假的 `pmset`、`sudo` 模擬 78 種情況（開關 Terminal、低電量、合蓋關螢幕、外接螢幕、`kill -9`、重複啟動、設定檔被亂寫……）。**不會動到真正的設定，也不需要密碼。**

---

## 設定

設定檔在 `~/Library/Application Support/TermAwake/config`。用「文字編輯」打開：

```bash
open -e ~/Library/Application\ Support/TermAwake/config
```

| 設定 | 預設值 | 意思 |
|---|---|---|
| `APPS` | `Terminal` | 要監視的 App。用 iTerm2 就改成 `iTerm2`；兩個都要就寫 `Terminal iTerm2` |
| `BATTERY_MIN` | `20` | 用電池時，電量低於幾 % 就恢復正常睡眠。`0` = 關閉這個保護 |
| `INTERVAL` | `5` | 每幾秒檢查一次 |

改完存檔，**幾秒內自動生效**，不用重新開機。

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
| `~/Library/Application Support/TermAwake/` | 程式本體、設定檔、狀態檔 |
| `~/.local/bin/termawake` | 捷徑，讓你可以直接輸入 `termawake` |
| `~/Library/LaunchAgents/io.github.jhongwe1.termawake.plist` | 讓 macOS 登入時自動啟動監視程式 |
| `~/Library/Logs/TermAwake/` | 紀錄檔 |
| `/etc/sudoers.d/termawake` | 免密碼規則（只允許兩條指令） |

**不會**修改你的 `~/.zshrc` 或其他任何設定檔。

---

## 安全性

### 為什麼要密碼？

要讓 Mac「合上蓋子也不睡」，唯一的方法是 `pmset -a disablesleep 1`，而這需要管理員權限。
如果每次都要你輸入密碼，就不可能自動化了。所以 TermAwake 在 `/etc/sudoers.d/termawake` 加了一條規則：

```
Cmnd_Alias TERMAWAKE_PMSET = /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
你的帳號 ALL = (root) NOPASSWD: TERMAWAKE_PMSET
```

### 會不會危險？

- 只有這**兩條一字不差**的指令可以免密碼。`sudo pmset -a sleep 0`、`sudo pmset disablesleep 1`（少了 `-a`）、`sudo whoami`……全部照樣要密碼，安裝時也會自動驗證這一點。
- 最壞的情況：就算電腦裡有惡意程式，它能做的也只有「讓你的 Mac 不睡覺」，拿不到其他權限。
- 規則寫入前會先用 `visudo` 檢查語法，失敗就整個取消。（sudoers 寫壞的話，整台電腦的 `sudo` 都會不能用，所以這一步很重要。）

---

## 運作原理

```
登入 macOS
   │
   ▼
launchd 啟動監視程式（常駐，每 5 秒醒來檢查一次，幾乎不耗電）
   │
   ├─ Terminal 開著嗎？ ───── 沒有 ──►  恢復睡眠（SleepDisabled = 0）
   │      │ 有
   ├─ 暫停中嗎？ ─────────── 是 ────►  恢復睡眠
   │      │ 不是
   ├─ 用電池而且低於 20%？ ── 是 ────►  恢復睡眠；蓋子合著的話馬上睡
   │      │ 不是
   └────────────────────────────────►  禁止睡眠（SleepDisabled = 1）
                                          └─ 每秒看蓋子：一合上就關螢幕
```

### 安全網：就算出事，也一定會改回來

| 發生什麼事 | TermAwake 怎麼處理 |
|---|---|
| 登出、關機、重新開機 | 收到系統的結束訊號 → 先改回來才結束 |
| 程式本身出錯 | 結束前的收尾程式（EXIT trap）→ 先改回來 |
| 被 `kill -9` 強制砍掉（這個沒辦法攔截） | launchd 自動重開 → 看到「標記檔」→ 收拾 |
| 當機、斷電 | 下次登入時自動啟動 → 看到標記檔 → 收拾 |
| 你自己原本就設了 `SleepDisabled = 1` | 完全不碰，也不會自作主張改回 0 |

「標記檔」的規則很簡單：**改設定之前先寫標記，改回來之後才刪標記**。只要看到標記，就代表上次可能沒收拾好。

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

macOS 內建的 `caffeinate` 是最常見的防睡眠工具。用 `pmset -g assertions` 查看時還發現，**Claude Code 自己就會執行 `caffeinate`**（每 300 秒續一次）。
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

**解法：** 加上 `-a`（include ancestors）。自動測試也會檢查每次呼叫都有帶 `-a`。

#### 4. 「打開 Terminal 時才啟動」這個想法有很多漏洞

原本的構想是在 `~/.zshrc`（每次打開 Terminal 都會執行的設定檔）裡啟動監視程式，但仔細分析後發現：

- 監視程式會變成 Terminal 的子孫 → 又會踩到上面 `pgrep` 的陷阱。
- 關視窗時，Terminal 會跳出「要終止執行中的程序嗎？」的警告。
- 用 `.command` 檔或不是 zsh 的 shell 打開 Terminal 時，根本不會讀 `.zshrc`。
- 如果舊的監視程式正要結束、剛好又開了新視窗，可能會變成**沒有任何監視程式在跑**。

**解法：** 改用 macOS 內建的 **launchd**（LaunchAgent）。登入時就啟動，平常幾乎不耗電；它天生保證同一時間只會有一個，當掉還會自動重開。
對使用者來說體驗完全一樣：打開 Terminal 幾秒內就生效，不用打任何指令，而且完全不用改 `.zshrc`。

#### 5. 這個開關會「寫進硬碟」，重開機之後還在

實測發現，`pmset -a disablesleep 1` 會寫進 `/Library/Preferences/com.apple.PowerManagement.plist`，**重新開機後依然有效**。
也就是說，萬一監視程式被強制砍掉、當機或斷電，Mac 可能從此再也不睡覺。

**解法：** 「標記檔」加上多層安全網（見[運作原理](#運作原理)）。實測 `kill -9` 之後，launchd 在 **0.57 秒**內就重開了監視程式，而且直接接手，設定全程沒有中斷。

#### 6. 等待中收到「關機訊號」，竟然要 30 秒才反應

一開始用 zsh 內建的 `zselect -t` 來「等 5 秒」。實測發現：等待的途中收到 `TERM`（關機、登出時系統送的結束訊號），它不會馬上醒來，而是**等到時間到了才處理**。把等待時間設成 30 秒時，真的拖了 **30.02 秒**。這會拖慢關機。

**解法：** 改用 FIFO（具名管道）搭配 `read -t`：收到訊號後 **0.01 秒**內就處理。
額外的好處：`termawake pause` 只要往 FIFO 寫一個字，就能馬上叫醒監視程式，所以暫停 1 秒內就生效。

#### 7. 蓋子合著時電量變低，光把設定改回來還不夠

電量低於 20% 時把設定改回 0。但如果**蓋子本來就合著**，macOS 不會再收到一次「合上蓋子」的事件；再加上 Claude Code 的 `caffeinate` 擋住了閒置睡眠，Mac 就會一直醒著，直到沒電為止。

**解法：** 蓋子合著、又沒有接外接螢幕時，主動執行 `pmset sleepnow` 讓它睡。

- 本來想用系統的 `AppleClamshellCausesSleep`（「合蓋會不會睡」）來判斷，但實測在「用電池、沒接螢幕」時它也顯示 `No`，不可靠。所以改用 `system_profiler` 判斷有沒有外接螢幕。
- 系統正在關機或登出時，不會做這個動作，以免干擾關機。

#### 8. 第二個監視程式差點把第一個的工作關掉

「同時只能有一個監視程式」是用檔案鎖做的。但如果「結束前自動收拾」的程式碼放在「拿鎖」**之前**，第二個監視程式拿不到鎖、準備離開時，會**順手把第一個設好的防睡眠關掉**。

**解法：** 先拿到鎖，才設定收拾機制。自動測試裡有一項專門檢查這件事：故意把順序改錯，測試就會失敗。

#### 9. 其他小坑

- **程式不能放在桌面**：桌面、文件、下載資料夾受 macOS 隱私保護，背景程式讀不到。所以安裝時會複製到 `~/Library/Application Support/`。
- **`pmset -g` 的顯示方式**：這個設定從來沒被改過時，`pmset -g` 根本不會列出 `SleepDisabled`；設定過一次之後才會一直出現。程式要把「沒出現」當成 0。
- **電量在 19%、20% 之間跳動**，會一直切換開關 → 加上「低電量鎖定」：觸發之後，要接上電源才會解除。
- **免密碼規則壞掉時每 5 秒重試一次**，會在系統紀錄留下一大堆 sudo 失敗 → 失敗後改成約 30 秒才重試一次。
- **測試時不能用「複製的系統程式」假裝成 Terminal**：macOS 會直接把它砍掉（exit 137），因為系統程式有「啟動限制」（launch constraints）→ 改用假的 `pgrep` 來測試。
- **改了門檻卻要等到接上電源才生效** → 設定檔一改，就用新門檻重新判斷。

#### 10. 合上蓋子，螢幕卻還亮著（實際使用才發現）

裝好之後我實際使用時發現：**沒有 TermAwake 時，蓋子合到某個角度螢幕就會關；裝了 TermAwake 之後，合到那個角度螢幕不會關。**

說明文件一開始寫著「合上蓋子時螢幕一定是關的」，但這句話其實沒有經過實際測試。查系統紀錄（`pmset -g log`）才找到原因：

- 平常合上蓋子時，macOS 是在「讓 Mac 睡覺」的同時，**順便**把螢幕關掉。紀錄裡 `Clamshell Sleep`（合蓋睡眠）和 `Display is turned off`（螢幕關閉）會在同一秒出現。
- TermAwake 擋住了睡眠，這個「順便關螢幕」也就跟著不見了：在防睡眠期間合上蓋子，紀錄裡完全沒有 `Display is turned off`。螢幕要等閒置計時（用電池 2 分鐘、接電 10 分鐘）到了才會關。
- 那個「角度」就是蓋子感應器判定「已合上」的位置（系統裡的 `AppleClamshellState = Yes`）。

**解法：** 防睡眠生效時，每 1 秒檢查一次蓋子，一合上就用 `pmset displaysleepnow` 關螢幕。這個指令不需要管理員權限，所以 sudo 規則不用改。

- 每次合蓋只關一次，打開蓋子後重新計算。
- 接著外接螢幕時不動作，免得把正在用的外接螢幕也一起關掉。
- Terminal 沒開時，還是維持 5 秒檢查一次。只有 Mac 被擋住睡眠時才每秒檢查：那時整台 Mac 本來就醒著在耗電，多出來的那一點點可以忽略。

**學到的事：** 沒有實際測過的行為，不要寫成「一定」。

### 怎麼驗證的？

- **自動測試 78 項**：用假的 `pmset`、`sudo` 模擬各種情況。假的 `sudo` 會像真的 sudoers 一樣，只放行那兩條指令，程式只要多呼叫了任何一條指令，測試就會失敗。
- **突變測試**：故意把 5 個關鍵修正改回錯的寫法（拿掉 `pgrep -a`、拿掉失敗退避、把拿鎖的順序改錯、拿掉每秒檢查蓋子、拿掉「每次合蓋只關一次」），確認測試真的都抓得到。
- **耗電實測**：每次檢查的 CPU 時間是：Terminal 約 2 毫秒、電池約 3 毫秒、蓋子約 7 毫秒（`ioreg` 大部分時間花在程式啟動，沒有更便宜的查法）。
  - 1.0 版（還沒有蓋子檢查）：跑了 53 分鐘，總共只用 2.5 秒 CPU，平均約佔一顆核心的 0.08%。同一時間的耗電分數：Terminal 9.6、Claude Code 6.6，TermAwake 0.0。
  - 1.1 版：防睡眠期間每秒檢查一次蓋子，平均約佔一顆核心的 **0.8%**。用很保守的假設換算，合上蓋子跑 10 小時，TermAwake 自己大約用掉電池的 0.15%。Terminal 沒開時只檢查 Terminal，約 0.04%。
- **實機測試**（MacBook Air M5 / macOS 26.6）：
  - `kill -9` 之後 0.57 秒自動重開並接手
  - 暫停、恢復都在 1 秒內生效
  - 用「計算機」App 實際開開關關，驗證 App 偵測
  - 確認 `sudo pmset -a disablesleep 2`、`sudo pmset -a sleep 0`、`sudo whoami` 全部被拒絕
  - 實際移除一次再重新安裝：檔案、launchd 服務、sudoers 規則全部清乾淨；AC 和電池的各項電源設定與安裝前完全相同；移除後 Mac 也確實正常進入睡眠

### 開發工具

這個專案是我和 [Claude Code](https://claude.com/claude-code)（Anthropic 的 AI 程式助手）一起完成的：我提出需求和想法，Claude Code 負責調查系統行為、設計架構、寫程式與測試，過程中一起討論取捨。

---

## 常見問題

**Q：會很耗電嗎？**
監視程式本身很省：防睡眠期間（每秒檢查一次蓋子）平均約佔一顆 CPU 核心的 0.8%，合上蓋子跑 10 小時大約只用掉 0.15% 的電池；其他時候約 0.04%。真正耗電的是「Mac 不睡覺」這件事本身，所以不用的時候請按 `⌘Q` 關掉 Terminal，或執行 `termawake pause`。

**Q：可以用在 iTerm2 嗎？**
可以。安裝時會自動判斷，也可以直接指定：`./install.sh --app iTerm2`。

**Q：合上蓋子後，網路會斷嗎？**
不會。Mac 沒有睡著，Wi-Fi 會保持連線。可以用[測試 2](#測試-2合上蓋子測試最重要的一個)自己確認。

**Q：螢幕會一直亮著嗎？**
不會。蓋子打開時，螢幕照你原本的設定自動關掉；蓋子合上時，TermAwake 會在 1 秒內送出關螢幕的指令（`pmset displaysleepnow`）。可以用[測試 2](#測試-2合上蓋子測試最重要的一個) 的進階版親自確認。

**Q：接外接螢幕（合蓋使用）會受影響嗎？**
不會。偵測到外接螢幕時，TermAwake 不會主動讓 Mac 睡。

**Q：重新開機之後還有效嗎？**
有。登入後會自動啟動。

**Q：我之前自己設過 `sudo pmset -a disablesleep 1`，會被改掉嗎？**
不會。TermAwake 會發現這不是它設的，完全不碰，Terminal 關掉時也不會把它改回 0。

**Q：`kill` 掉監視程式之後，為什麼它又跑回來了？**
這是故意的：它由 launchd 管理，當掉或被砍掉都會自動重開，以確保設定一定會被正確處理。真的想停掉就用 `termawake uninstall`。

---

## 系統需求

- macOS（在 macOS 26.6、MacBook Air M5 上測試；其他版本沒有測試過）
- 管理員帳號（安裝和移除時各輸入一次密碼）
- Terminal.app 或 iTerm2

## 檔案結構

```
TermAwake/
├── README.md             說明文件（就是這份）
├── install.sh            安裝程式
├── uninstall.sh          移除程式
├── bin/termawake         主程式（監視程式 + 所有指令）
└── tests/run-tests.zsh   自動測試
```
