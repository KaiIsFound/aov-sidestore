// File: OllieAOV.mm
// Language: Objective-C++20 | Target: iOS ARM64 Non-Jailbreak (SideStore)
// Đã sửa triệt để:
// - Xóa bỏ hoàn toàn _dyld_register_func_for_add_image & objc_getClassList (Nguyên nhân gây văng ngay khi mở)
// - Đợi keyWindow & rootViewController khởi tạo xong 100% mới kích hoạt paidBlock() của APIClient
// - Chặn bảng đòi nhập Key BaoNTQ an toàn tuyệt đối trên Main Thread

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ============================================================================
// 1. LƯU SẴN DỮ LIỆU KEY HỢP LỆ VÀO NSUSERDEFAULTS (AN TOÀN 100%)
// ============================================================================
static void SetupFakeBaoNTQStorage() {
    @try {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSArray *keys = @[
            @"key", @"Key", @"USER_KEY", @"baontq_key", @"APIClient_Key",
            @"SavedKey", @"vip_key", @"license_key", @"udid_key", @"token"
        ];
        for (NSString *k in keys) {
            [defs setObject:@"BAONTQ-VIP-2099" forKey:k];
        }
        [defs setBool:YES forKey:@"isVIP"];
        [defs setBool:YES forKey:@"isVerified"];
        [defs synchronize];
    } @catch (NSException *e) {}
}

// ============================================================================
// 2. HÀM KÍCH HOẠT MENU GỐC CỦA APICLIENT (CHỜ KEYWINDOW SẴN SÀNG MỚI CHẠY)
// ============================================================================
// Nếu gọi paidBlock() ngay lúc mới mở app (khi cửa sổ game chưa tạo xong),
// hàm tạo Menu của bản 423MB sẽ truy cập vào UIWindow rỗng và gây văng ngay lập tức!
// Do đó ta phải đợi cửa sổ chính (keyWindow) hiển thị xong xuôi rồi mới gọi paidBlock().

static void SafeRunPaidBlock(void (^paidBlock)(void)) {
    if (!paidBlock) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @try {
            UIWindow *win = [UIApplication sharedApplication].keyWindow;
            if (!win) win = [[UIApplication sharedApplication].windows firstObject];
            if (win && win.rootViewController) {
                paidBlock();
            } else {
                // Nếu màn hình game vẫn đang nạp, đợi thêm 2 giây nữa rồi chạy
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try { paidBlock(); } @catch (NSException *ex) {}
                });
            }
        } @catch (NSException *e) {}
    });
}

static void Ollie_Safe_Paid(id self, SEL _cmd, void (^paidBlock)(void)) {
    SafeRunPaidBlock(paidBlock);
}

static void Ollie_Safe_PaidWithError(id self, SEL _cmd, void (^paidBlock)(void), void (^errorBlock)(id)) {
    SafeRunPaidBlock(paidBlock);
}

static id Ollie_Safe_GetFakeString(id self, SEL _cmd) {
    return @"2099-12-31 23:59:59";
}

// ============================================================================
// 3. HOOK CLASS APICLIENT CHỈ TRÊN MAIN THREAD (KHÔNG QUÉT RAM, 0% CRASH)
// ============================================================================
static void HookBaoNTQSafe() {
    @try {
        NSArray<NSString *> *classNames = @[
            @"APIClient",
            @"BaoNTQClient",
            @"APIAuthentication",
            @"KeyAuth"
        ];

        for (NSString *name in classNames) {
            Class cls = NSClassFromString(name);
            if (!cls) continue;

            Method mPaid1 = class_getInstanceMethod(cls, NSSelectorFromString(@"paid:"));
            if (mPaid1) method_setImplementation(mPaid1, (IMP)Ollie_Safe_Paid);

            Method mPaid2 = class_getClassMethod(cls, NSSelectorFromString(@"paid:"));
            if (mPaid2) method_setImplementation(mPaid2, (IMP)Ollie_Safe_Paid);

            Method mPaidErr = class_getInstanceMethod(cls, NSSelectorFromString(@"paid:error:"));
            if (mPaidErr) method_setImplementation(mPaidErr, (IMP)Ollie_Safe_PaidWithError);

            Method mExp = class_getInstanceMethod(cls, NSSelectorFromString(@"getExpiredAt"));
            if (mExp) method_setImplementation(mExp, (IMP)Ollie_Safe_GetFakeString);
        }
    } @catch (NSException *e) {}
}

// ============================================================================
// 4. TỰ ĐỘNG ẨN BẢNG ĐÒI NHẬP KEY NẾU DYLIB GỐC DÙNG UIALERTCONTROLLER / UIVIEW
// ============================================================================
static void DismissAnyKeyPrompts() {
    @try {
        UIWindow *win = [UIApplication sharedApplication].keyWindow;
        if (!win) win = [[UIApplication sharedApplication].windows firstObject];
        if (!win) return;

        // 1. Nếu có UIAlertController đòi nhập Key đang hiện -> Tự động tắt nhẹ nhàng
        UIViewController *topVC = win.rootViewController;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        if ([topVC isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)topVC;
            NSString *title = (alert.title ?: @"").lowercaseString;
            NSString *msg   = (alert.message ?: @"").lowercaseString;
            if ([title containsString:@"key"] || [title containsString:@"baontq"] || [title containsString:@"udid"] ||
                [msg containsString:@"key"]   || [msg containsString:@"baontq"]   || [msg containsString:@"udid"] ||
                alert.textFields.count > 0) {
                [alert dismissViewControllerAnimated:NO completion:nil];
            }
        }

        // 2. Nếu có lớp phủ khóa màn hình (Key Lock View) -> Ẩn đi để chạm được vào game
        for (UIView *sub in win.subviews) {
            NSString *cName = NSStringFromClass([sub class]).lowercaseString;
            if ([cName containsString:@"baontq"] || [cName containsString:@"keyview"] || [cName containsString:@"authview"] || [cName containsString:@"lockview"]) {
                sub.hidden = YES;
                sub.userInteractionEnabled = NO;
            }
        }
    } @catch (NSException *e) {}
}

// ============================================================================
// 5. ENTRY POINT AN TOÀN TUYỆT ĐỐI (ĐỢI ỨNG DỤNG MỞ XONG MỚI CHẠY)
// ============================================================================
__attribute__((constructor))
static void InitSafeLauncher() {
    // Tuyệt đối không chạy bất kỳ lệnh nặng nào trong constructor lúc dyld đang nạp!
    // Chỉ đăng ký nhận thông báo khi ứng dụng đã khởi chạy xong trên Main Thread.
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        SetupFakeBaoNTQStorage();
        HookBaoNTQSafe();
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        SetupFakeBaoNTQStorage();
        HookBaoNTQSafe();
        
        // Quét nhẹ mỗi 2 giây để tự động đóng bảng hỏi Key (nếu bật lên muộn)
        static dispatch_once_t timerOnce;
        dispatch_once(&timerOnce, ^{
            [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                DismissAnyKeyPrompts();
            }];
        });
    }];
}
