/*
 * tawatch — TermAwake 的感測小幫手
 * https://github.com/Jhongwe1/TermAwake
 *
 * 只負責「看」，不做任何決定，也不需要任何特殊權限。
 * 平常停在那裡等 macOS 的事件通知，完全不佔 CPU；
 * 一有變化，就印一行「目前狀態」給 TermAwake 的監視程式（bin/termawake）。
 *
 * ── 輸出（一行一筆，欄位用空白隔開）───────────────────────────────────────────
 *   S1 gen=<代號> pid=<PID> why=<原因> seq=<序號> app=<名稱|-> batt=<0|1> pct=<0-100|-1>
 *      lid=<0|1|-1> ext=<數量|-1> therm=<0-4|-1> lpm=<0|1> sd=<0|1|-1> work=<數量|-1>
 *
 *   gen    監視程式給的代號（重新啟動小幫手時用來分辨新舊資料）
 *   pid    小幫手自己的 PID（監視程式要叫它時用）
 *   why    這一行為什麼印出來：start tick ping app power lid display thermal lpm prefs work config wake once
 *   app    正在執行的監視對象（--apps 裡第一個找到的程序名稱）；都沒在跑就是 -
 *   batt   1 = 正在用電池（或插著電、但電量還在往下掉）
 *   pct    電量百分比；沒有電池時是 -1
 *   lid    1 = 蓋子合上、0 = 打開、-1 = 沒有蓋子（桌上型 Mac）
 *   ext    外接螢幕數量；判斷不出來是 -1
 *   therm  溫度壓力等級：0 正常、1 中度、2 重度、3 嚴重、4 即將緊急睡眠；讀不到是 -1
 *   lpm    1 = 低耗電模式開著
 *   sd     核心目前的 SleepDisabled（1 = 禁止睡眠）；讀不到是 -1
 *   work   有幾個「要求保持清醒」的請求，來自你的 caffeinate 或監視對象底下的程式；沒加 --work 時是 -1
 *
 * 只有狀態真的改變才會印（心跳和 ping 例外，一定會印）。
 *
 * ── 事件來源（全部是 macOS 的事件通知，不輪詢）──────────────────────────────
 *   App 啟動／結束   NSWorkspace 通知；結束另外用核心的程序結束通知（不是 App 的程序名稱也抓得到）
 *   電源／電量       notify(3)：com.apple.system.powersources.source / .percent / .lowbattery
 *   溫度             notify(3)：com.apple.system.thermalpressurelevel
 *   低耗電模式       NSProcessInfoPowerStateDidChangeNotification
 *   蓋子             IOKit：IOPMrootDomain 的 kIOPMMessageClamshellStateChange
 *   外接螢幕         CoreGraphics：CGDisplayRegisterReconfigurationCallback
 *   SleepDisabled    notify(3)：com.apple.system.powermanagement.prefschange（pmset 改設定後一定會發）
 *   保持清醒的請求   notify(3)：com.apple.system.powermanagement.assertions.anychange（只在 --work 時）
 *   設定檔           kqueue：檔案被修改或被取代
 *   睡醒             NSWorkspaceDidWakeNotification
 *   心跳             每 --tick 秒把全部重新讀一次、印一行（安全網，也讓監視程式知道我還活著）
 *   SIGUSR1          立刻重新讀一次、印一行（監視程式用來確認我還有反應）
 *
 * 父程式（監視程式）一結束，就立刻跟著結束，不會變成孤兒程序。
 *
 * ── 用法 ──────────────────────────────────────────────────────────────────────
 *   tawatch --parent PID --apps "Terminal iTerm2" [--tick 60] [--config FILE] [--work] [--gen N]
 *   tawatch --once [--apps ...] [--work]     印一行目前狀態就結束（termawake status / doctor 用）
 *
 * 編譯（install.sh 會自動做）：
 *   xcrun cc -O2 -Wall -Wextra -fobjc-arc -framework AppKit -framework IOKit \
 *            -framework CoreGraphics -o tawatch src/tawatch.m
 */
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/ps/IOPSKeys.h>
#include <IOKit/ps/IOPowerSources.h>
#include <IOKit/pwr_mgt/IOPM.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <libkern/OSThermalNotification.h>
#include <libproc.h>
#include <notify.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/proc.h>
#include <sys/proc_info.h>
#include <unistd.h>

typedef struct {
    char app[33];
    int batt, pct, lid, ext, therm, lpm, sd, work;
} Snapshot;

enum { kMaxApps = 16 };
static char gApps[kMaxApps][MAXCOMLEN + 1];  // 要監視的程序名稱（和 pgrep 一樣只比對前 16 個字元）
static int gAppCount;
static NSSet<NSNumber *> *gAppPids;         // 目前找到的監視對象 PID
static NSMutableDictionary<NSNumber *, dispatch_source_t> *gExitWatch;
static NSString *gConfigPath;
static BOOL gWork;                          // 要不要追蹤「保持清醒的請求」
static double gTick = 60;
static pid_t gParent;
static uid_t gUid;
static io_service_t gRoot = IO_OBJECT_NULL; // IOPMrootDomain
static int gThermTok = -1;
typedef IOReturn (*AssertionNotifyFn)(char *name, int reqType);
static AssertionNotifyFn gAssertionNotify;  // 私有 SPI，用 dlsym 取得（可能沒有）
static const char *gGen = "0";
static unsigned long gSeq;
static Snapshot gCur, gLast;
static BOOL gHaveLast, gDisplayPending, gWorkPending;

// ─── 讀取各種狀態 ─────────────────────────────────────────────────────────────

// 監視對象有沒有在跑：比對程序名稱和擁有者，規則和 `pgrep -x -u $UID` 相同
static void read_apps(void) {
    NSMutableSet<NSNumber *> *pids = [NSMutableSet set];
    BOOL found[kMaxApps] = {NO};
    int n = proc_listallpids(NULL, 0);
    if (n > 0 && gAppCount > 0) {
        size_t cap = (size_t)n + 256;
        pid_t *list = calloc(cap, sizeof(pid_t));
        if (list) {
            n = proc_listallpids(list, (int)(cap * sizeof(pid_t)));
            for (int i = 0; i < n; i++) {
                struct proc_bsdshortinfo info;
                if (list[i] <= 0 ||
                    proc_pidinfo(list[i], PROC_PIDT_SHORTBSDINFO, 0, &info, sizeof info) != sizeof info ||
                    info.pbsi_uid != gUid || info.pbsi_status == SZOMB) {
                    continue;
                }
                for (int k = 0; k < gAppCount; k++) {
                    if (strncmp(info.pbsi_comm, gApps[k], MAXCOMLEN) == 0) {
                        [pids addObject:@(list[i])];
                        found[k] = YES;
                    }
                }
            }
            free(list);
        }
    }
    snprintf(gCur.app, sizeof gCur.app, "-");
    for (int k = 0; k < gAppCount; k++) {
        if (found[k]) { snprintf(gCur.app, sizeof gCur.app, "%s", gApps[k]); break; }
    }
    gAppPids = pids;
}

// 電源與電量。「用電池」= 電池在供電，或插著電但電流是負的（充電器瓦數不夠）
static void read_power(void) {
    gCur.batt = 0;
    gCur.pct = -1;
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (!info) return;
    CFArrayRef list = IOPSCopyPowerSourcesList(info);
    for (CFIndex i = 0; list && i < CFArrayGetCount(list); i++) {
        NSDictionary *d = (__bridge NSDictionary *)IOPSGetPowerSourceDescription(info, CFArrayGetValueAtIndex(list, i));
        if (![d[@kIOPSTypeKey] isEqual:@kIOPSInternalBatteryType]) continue;
        int cur = [d[@kIOPSCurrentCapacityKey] intValue], max = [d[@kIOPSMaxCapacityKey] intValue];
        if (max > 0) gCur.pct = cur * 100 / max;
        BOOL onBattery = [d[@kIOPSPowerSourceStateKey] isEqual:@kIOPSBatteryPowerValue];
        BOOL draining = ![d[@kIOPSIsChargingKey] boolValue] && [d[@kIOPSCurrentKey] intValue] < 0;
        gCur.batt = (onBattery || draining) ? 1 : 0;
        break;
    }
    if (list) CFRelease(list);
    CFRelease(info);
}

static int read_root_bool(CFStringRef key) {
    if (gRoot == IO_OBJECT_NULL) return -1;
    CFTypeRef v = IORegistryEntryCreateCFProperty(gRoot, key, kCFAllocatorDefault, 0);
    int r = (v == kCFBooleanTrue) ? 1 : (v == kCFBooleanFalse) ? 0 : -1;
    if (v) CFRelease(v);
    return r;
}

static void read_displays(void) {
    CGDirectDisplayID ids[32];
    uint32_t n = 0;
    if (CGGetOnlineDisplayList(32, ids, &n) != kCGErrorSuccess) { gCur.ext = -1; return; }
    int ext = 0;
    for (uint32_t i = 0; i < n; i++) {
        if (!CGDisplayIsBuiltin(ids[i])) ext++;
    }
    gCur.ext = ext;
}

static void read_thermal(void) {
    uint64_t v = 0;
    if (gThermTok < 0 || notify_get_state(gThermTok, &v) != NOTIFY_STATUS_OK) { gCur.therm = -1; return; }
    gCur.therm = v > 4 ? 4 : (int)v;   // 超出範圍就當成最嚴重（寧可讓 Mac 睡）
}

// pid 是不是監視對象（例如 Terminal）的子孫程序
static BOOL descends_from_app(pid_t pid) {
    for (int depth = 0; depth < 64 && pid > 1; depth++) {
        if ([gAppPids containsObject:@(pid)]) return YES;
        struct proc_bsdshortinfo info;
        if (proc_pidinfo(pid, PROC_PIDT_SHORTBSDINFO, 0, &info, sizeof info) != sizeof info) return NO;
        pid = (pid_t)info.pbsi_ppid;
    }
    return NO;
}

// 「要求保持清醒」的請求：會擋住閒置睡眠的 assertion（caffeinate -i、-s 就是這種）。
// 只算兩種來源：你自己執行的 caffeinate，以及監視對象底下的程式（例如 Terminal 裡的 Claude Code）。
static void read_work(void) {
    if (!gWork) { gCur.work = -1; return; }
    CFDictionaryRef byPid = NULL;
    if (IOPMCopyAssertionsByProcess(&byPid) != kIOReturnSuccess || !byPid) { gCur.work = -1; return; }
    int count = 0;
    NSDictionary *all = (__bridge NSDictionary *)byPid;
    for (NSNumber *pidNum in all) {
        int held = 0;
        for (NSDictionary *a in all[pidNum]) {
            NSString *type = a[(__bridge NSString *)kIOPMAssertionTypeKey];
            if ([a[(__bridge NSString *)kIOPMAssertionLevelKey] intValue] > 0 &&
                ([type isEqual:(__bridge NSString *)kIOPMAssertionTypePreventUserIdleSystemSleep] ||
                 [type isEqual:(__bridge NSString *)kIOPMAssertionTypePreventSystemSleep] ||
                 [type isEqual:@"NoIdleSleepAssertion"])) {
                held++;
            }
        }
        if (!held) continue;
        pid_t pid = pidNum.intValue;
        struct proc_bsdshortinfo info;
        BOOL mine = proc_pidinfo(pid, PROC_PIDT_SHORTBSDINFO, 0, &info, sizeof info) == sizeof info &&
                    info.pbsi_uid == gUid;
        BOOL isCaffeinate = mine && strncmp(info.pbsi_comm, "caffeinate", MAXCOMLEN) == 0;
        if (isCaffeinate || (mine && descends_from_app(pid))) count += held;
    }
    CFRelease(byPid);
    gCur.work = count;
}

static void read_all(void) {
    read_apps();
    read_power();
    gCur.lid = read_root_bool(CFSTR(kAppleClamshellStateKey));
    read_displays();
    read_thermal();
    gCur.lpm = NSProcessInfo.processInfo.isLowPowerModeEnabled ? 1 : 0;
    gCur.sd = read_root_bool(CFSTR("SleepDisabled"));
    read_work();
}

// ─── 輸出 ─────────────────────────────────────────────────────────────────────

static void emit(const char *why, BOOL force) {
    if (!force && gHaveLast && memcmp(&gCur, &gLast, sizeof gCur) == 0) return;
    gLast = gCur;
    gHaveLast = YES;
    char line[384];
    int len = snprintf(line, sizeof line,
                       "S1 gen=%s pid=%d why=%s seq=%lu app=%s batt=%d pct=%d lid=%d ext=%d therm=%d lpm=%d sd=%d work=%d\n",
                       gGen, (int)getpid(), why, ++gSeq, gCur.app, gCur.batt, gCur.pct, gCur.lid, gCur.ext,
                       gCur.therm, gCur.lpm, gCur.sd, gCur.work);
    if (len <= 0 || len >= (int)sizeof line) return;
    // 一行小於 PIPE_BUF（512 bytes），寫進 FIFO 是一次完成的，不會和別人寫的內容交錯
    for (ssize_t off = 0; off < len;) {
        ssize_t w = write(STDOUT_FILENO, line + off, (size_t)(len - off));
        if (w <= 0) exit(0);   // 輸出的另一端不見了 → 沒有人需要我了
        off += w;
    }
}

static void refresh(const char *why) {
    read_all();
    emit(why, NO);
}

// 程序結束通知：監視對象（不管是不是 App）一結束就立刻知道
static void watch_app_exits(void) {
    for (NSNumber *pid in gExitWatch.allKeys) {
        if (![gAppPids containsObject:pid]) {
            dispatch_source_cancel(gExitWatch[pid]);
            [gExitWatch removeObjectForKey:pid];
        }
    }
    for (NSNumber *pid in gAppPids) {
        if (gExitWatch[pid]) continue;
        dispatch_source_t s = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, (uintptr_t)pid.intValue,
                                                     DISPATCH_PROC_EXIT, dispatch_get_main_queue());
        if (!s) continue;
        dispatch_source_set_event_handler(s, ^{
            dispatch_source_cancel(s);
            [gExitWatch removeObjectForKey:pid];
            refresh("app");
            watch_app_exits();
        });
        gExitWatch[pid] = s;
        dispatch_resume(s);
    }
}

static void refresh_apps(const char *why) {
    refresh(why);
    watch_app_exits();
}

// 有些事件會一口氣來好幾個（螢幕重新設定、assertion 變化），合併成一次處理
static void debounce(BOOL *pending, double secs, void (^block)(void)) {
    if (*pending) return;
    *pending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(secs * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        *pending = NO;
        block();
    });
}

static void on_display_change(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *info) {
    (void)display;
    (void)info;
    if (flags & kCGDisplayBeginConfigurationFlag) return;
    debounce(&gDisplayPending, 0.1, ^{ refresh("display"); });
}

static void on_root_message(void *refcon, io_service_t service, uint32_t type, void *arg) {
    (void)refcon;
    (void)service;
    (void)arg;
    if (type == kIOPMMessageClamshellStateChange) refresh("lid");
}

static void notify_on(const char *name, void (^handler)(void)) {
    int tok;
    if (notify_register_dispatch(name, &tok, dispatch_get_main_queue(), ^(int t) { (void)t; handler(); }) !=
        NOTIFY_STATUS_OK) {
        fprintf(stderr, "tawatch: notify_register_dispatch(%s) failed\n", name);
    }
}

// powerd 只在有人登記之後才會發 assertion 變化的通知（PowerManagement PMAssertions.c:4333）。
// 登記用的是私有 SPI（pmset -g assertionslog 也用它），所以用 dlsym 取得；沒有的話就只靠心跳更新。
static void register_assertion_events(void) {
    if (gAssertionNotify) gAssertionNotify("com.apple.system.powermanagement.assertions.anychange", 1);
}

// 設定檔被修改或取代（文字編輯器存檔通常是「寫新檔再改名」）→ 通知監視程式重新讀取
static void watch_config(void);
static void watch_config_later(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{ watch_config(); });
}
static dispatch_source_t gConfigSrc;
static void watch_config(void) {
    static int retries;
    if (!gConfigPath) return;
    if (gConfigSrc) { dispatch_source_cancel(gConfigSrc); gConfigSrc = nil; }
    int fd = open(gConfigPath.fileSystemRepresentation, O_EVTONLY);
    if (fd < 0) {
        if (++retries <= 20) watch_config_later();   // 存檔中途短暫不存在；之後由心跳重試
        return;
    }
    retries = 0;
    dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, (uintptr_t)fd,
                                 DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_ATTRIB |
                                     DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE,
                                 dispatch_get_main_queue());
    if (!src) { close(fd); return; }
    dispatch_source_set_cancel_handler(src, ^{ close(fd); });
    dispatch_source_set_event_handler(src, ^{
        unsigned long f = dispatch_source_get_data(src);
        read_all();
        emit("config", YES);
        if (f & (DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE)) {
            dispatch_source_cancel(src);
            if (gConfigSrc == src) gConfigSrc = nil;
            watch_config_later();
        }
    });
    gConfigSrc = src;
    dispatch_resume(src);
}

static void exit_when_gone(pid_t pid) {
    dispatch_source_t s = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, (uintptr_t)pid, DISPATCH_PROC_EXIT,
                                                 dispatch_get_main_queue());
    if (!s) { fprintf(stderr, "tawatch: cannot watch pid %d\n", pid); exit(1); }
    dispatch_source_set_event_handler(s, ^{ exit(0); });
    dispatch_resume(s);
    static NSMutableArray *keep;   // ARC：保留住，不然會被回收
    if (!keep) keep = [NSMutableArray array];
    [keep addObject:s];
}

static void usage(void) {
    fprintf(stderr, "usage: tawatch --parent PID --apps \"Terminal\" [--tick 60] [--config FILE] [--work] [--gen N]\n"
                    "       tawatch --once [--apps \"Terminal\"] [--work]\n");
    exit(64);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        BOOL once = NO;
        NSString *apps = @"";
        for (int i = 1; i < argc; i++) {
            const char *a = argv[i];
            BOOL hasValue = i + 1 < argc;
            if (!strcmp(a, "--once")) once = YES;
            else if (!strcmp(a, "--work")) gWork = YES;
            else if (!strcmp(a, "--apps") && hasValue) apps = @(argv[++i]);
            else if (!strcmp(a, "--parent") && hasValue) gParent = (pid_t)atoi(argv[++i]);
            else if (!strcmp(a, "--tick") && hasValue) gTick = atof(argv[++i]);
            else if (!strcmp(a, "--config") && hasValue) gConfigPath = @(argv[++i]);
            else if (!strcmp(a, "--gen") && hasValue) gGen = argv[++i];
            else usage();
        }
        if (strspn(gGen, "0123456789") != strlen(gGen) || strlen(gGen) > 12) usage();
        if (!once && gParent <= 1) usage();
        if (gTick < 1) gTick = 1;
        for (NSString *name in [apps componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]) {
            if (name.length && gAppCount < kMaxApps) {
                snprintf(gApps[gAppCount++], sizeof gApps[0], "%s", name.UTF8String);
            }
        }
        gUid = getuid();
        gExitWatch = [NSMutableDictionary dictionary];
        gRoot = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"));
        if (gRoot == IO_OBJECT_NULL) fprintf(stderr, "tawatch: IOPMrootDomain not found\n");
        if (notify_register_dispatch(kOSThermalNotificationPressureLevelName, &gThermTok, dispatch_get_main_queue(),
                                     ^(int t) { (void)t; refresh("thermal"); }) != NOTIFY_STATUS_OK) {
            gThermTok = -1;
            fprintf(stderr, "tawatch: cannot subscribe to thermal pressure\n");
        }

        if (once) {
            read_all();
            emit("once", YES);
            return 0;
        }

        // 父程式（監視程式）或直接的上一層一結束，就跟著結束
        if (kill(gParent, 0) != 0) return 0;
        signal(SIGPIPE, SIG_IGN);
        exit_when_gone(gParent);
        if (getppid() != gParent && getppid() > 1) exit_when_gone(getppid());

        NSNotificationCenter *ws = NSWorkspace.sharedWorkspace.notificationCenter;
        NSOperationQueue *main = NSOperationQueue.mainQueue;
        [ws addObserverForName:NSWorkspaceDidLaunchApplicationNotification object:nil queue:main
                    usingBlock:^(NSNotification *n) { (void)n; refresh_apps("app"); }];
        [ws addObserverForName:NSWorkspaceDidTerminateApplicationNotification object:nil queue:main
                    usingBlock:^(NSNotification *n) { (void)n; refresh_apps("app"); }];
        [ws addObserverForName:NSWorkspaceDidWakeNotification object:nil queue:main
                    usingBlock:^(NSNotification *n) { (void)n; refresh_apps("wake"); }];
        [NSNotificationCenter.defaultCenter addObserverForName:NSProcessInfoPowerStateDidChangeNotification
                                                        object:nil queue:main
                                                    usingBlock:^(NSNotification *n) { (void)n; refresh("lpm"); }];

        notify_on(kIOPSNotifyPowerSource, ^{ refresh("power"); });
        notify_on("com.apple.system.powersources.percent", ^{ refresh("power"); });
        notify_on(kIOPSNotifyLowBattery, ^{ refresh("power"); });
        // pmset 改完設定會發這個通知，但核心的值是 powerd 收到後才更新 → 稍等一下再讀
        notify_on("com.apple.system.powermanagement.prefschange", ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{ refresh("prefs"); });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ refresh("prefs"); });
        });

        if (gRoot != IO_OBJECT_NULL) {
            IONotificationPortRef port = IONotificationPortCreate(kIOMainPortDefault);
            io_object_t note = IO_OBJECT_NULL;
            if (port && IOServiceAddInterestNotification(port, gRoot, kIOGeneralInterest, on_root_message, NULL,
                                                         &note) == KERN_SUCCESS) {
                IONotificationPortSetDispatchQueue(port, dispatch_get_main_queue());
            } else {
                fprintf(stderr, "tawatch: cannot subscribe to lid events\n");
            }
        }
        if (CGDisplayRegisterReconfigurationCallback(on_display_change, NULL) != kCGErrorSuccess) {
            fprintf(stderr, "tawatch: cannot subscribe to display changes\n");
        }

        if (gWork) {
            gAssertionNotify = (AssertionNotifyFn)dlsym(RTLD_DEFAULT, "IOPMAssertionNotify");
            if (!gAssertionNotify) fprintf(stderr, "tawatch: IOPMAssertionNotify not available; work updates only on heartbeat\n");
            register_assertion_events();
            notify_on("com.apple.system.powermanagement.assertions.anychange", ^{
                debounce(&gWorkPending, 0.25, ^{ read_work(); emit("work", NO); });
            });
        }

        watch_config();

        signal(SIGUSR1, SIG_IGN);
        dispatch_source_t ping = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGUSR1, 0, dispatch_get_main_queue());
        dispatch_source_set_event_handler(ping, ^{ read_all(); watch_app_exits(); emit("ping", YES); });
        dispatch_resume(ping);

        dispatch_source_t tick = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        uint64_t interval = (uint64_t)(gTick * NSEC_PER_SEC);
        dispatch_source_set_timer(tick, dispatch_time(DISPATCH_TIME_NOW, (int64_t)interval), interval, interval / 10);
        dispatch_source_set_event_handler(tick, ^{
            register_assertion_events();   // powerd 重新啟動過的話要重新登記（重複登記沒有副作用）
            if (gConfigPath && !gConfigSrc) watch_config();   // 之前設定檔不存在 → 再試一次
            read_all();
            watch_app_exits();
            emit("tick", YES);
        });
        dispatch_resume(tick);

        read_all();
        watch_app_exits();
        emit("start", YES);
        CFRunLoopRun();
    }
    return 0;
}
