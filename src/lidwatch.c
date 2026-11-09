/*
 * lidwatch — TermAwake 的「蓋子事件」小幫手
 * https://github.com/Jhongwe1/TermAwake
 *
 * 向 macOS 登記「蓋子狀態改變」的通知（IOPMrootDomain 送出的
 * kIOPMMessageClamshellStateChange）。蓋子一合上或打開，就印出一行：
 *     closed   或   open
 * 平常完全不佔 CPU：程式停在那裡等系統通知，不會每秒去問。
 *
 * TermAwake 的監視程式會把它的輸出接到自己的喚醒管道（FIFO），
 * 所以蓋子一合上，監視程式就會立刻醒來把螢幕關掉。
 *
 * 父程式（監視程式）一結束，這個小幫手也會立刻跟著結束，
 * 就算父程式是被 kill -9 強制砍掉也一樣，不會留下孤兒程序。
 *
 * 編譯（install.sh 會自動做）：
 *   cc -O2 -Wall -Wextra -framework IOKit -framework CoreFoundation \
 *      -o lidwatch src/lidwatch.c
 */
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/pwr_mgt/IOPM.h>
#include <dispatch/dispatch.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void on_root_domain_message(void *refcon, io_service_t service,
                                   uint32_t message_type, void *message_argument) {
    (void)refcon;
    (void)service;
    if (message_type != kIOPMMessageClamshellStateChange) {
        return;
    }
    uintptr_t state = (uintptr_t)message_argument;
    const char *line = (state & kClamshellStateBit) ? "closed" : "open";
    if (printf("%s\n", line) < 0 || fflush(stdout) != 0) {
        exit(0);   /* 輸出的另一端不見了 → 沒有人需要我了 */
    }
}

int main(void) {
    io_service_t root = IOServiceGetMatchingService(MACH_PORT_NULL,
                                                    IOServiceMatching("IOPMrootDomain"));
    if (root == IO_OBJECT_NULL) {
        fprintf(stderr, "lidwatch: IOPMrootDomain not found\n");
        return 1;
    }

    IONotificationPortRef port = IONotificationPortCreate(MACH_PORT_NULL);
    if (port == NULL) {
        fprintf(stderr, "lidwatch: IONotificationPortCreate failed\n");
        return 1;
    }

    io_object_t notification = IO_OBJECT_NULL;
    kern_return_t kr = IOServiceAddInterestNotification(port, root, kIOGeneralInterest,
                                                        on_root_domain_message, NULL,
                                                        &notification);
    IOObjectRelease(root);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "lidwatch: IOServiceAddInterestNotification failed (0x%x)\n", kr);
        return 1;
    }
    CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port),
                       kCFRunLoopDefaultMode);

    /* 父程式結束 → 立刻結束（用核心的程序事件通知，不是輪詢） */
    pid_t parent = getppid();
    dispatch_source_t parent_exit = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_PROC, (uintptr_t)parent, DISPATCH_PROC_EXIT,
        dispatch_get_main_queue());
    if (parent_exit == NULL) {
        fprintf(stderr, "lidwatch: cannot watch parent process\n");
        return 1;
    }
    dispatch_source_set_event_handler(parent_exit, ^{ exit(0); });
    dispatch_resume(parent_exit);
    if (getppid() != parent) {
        return 0;   /* 父程式在登記完成前就已經結束了 */
    }

    CFRunLoopRun();
    return 0;
}
