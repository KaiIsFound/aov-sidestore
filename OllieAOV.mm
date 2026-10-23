// File: OllieAOV.mm
// Language: Objective-C++20 | Target: iOS ARM64 Non-Jailbreak (SideStore)
// Role: Invisible BaoNTQ Key Cracker + Anti-Desync (Chống Trận Ảo) + Anti-Crash Shield cho IPA Mẫu

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <string>

// ============================================================================
// 1. SỬA LỖI DÒNG 70 & CHẶN LỆNH TỰ HỦY (ANTI-EXIT / ANTI-CRASH KHI BYPASS KEY)
// ============================================================================
void dett_safe_exit(int status) {
    // Giữ luồng kiểm tra key ngủ yên nếu nó cố tình gọi exit() khi không thấy key thật
    while (true) {
        sleep(3600);
    }
}

// ============================================================================
// 2. BẺ KHÓA MÁY CHỦ KIỂM TRA KEY BAONTQ (NSURLSESSION & NSJSONSERIALIZATION)
// ============================================================================
// Mọi bản hack yêu cầu nhập Key của BaoNTQ đều gửi request kiểm tra Key/UDID và đọc JSON trả về.
// Ta chặn ở cả tầng mạng (NSURLSession) lẫn tầng giải mã JSON (NSJSONSerialization) để 100% báo Key VIP!

@implementation NSURLSession (BaoNTQCracker)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        
        // 1. Hook dataTaskWithRequest:completionHandler:
        Method m1 = class_getInstanceMethod(cls, @selector(dataTaskWithRequest:completionHandler:));
        Method m2 = class_getInstanceMethod(cls, @selector(ollie_dataTaskWithRequest:completionHandler:));
        if (m1 && m2) method_exchangeImplementations(m1, m2);

        // 2. Hook dataTaskWithURL:completionHandler:
        Method u1 = class_getInstanceMethod(cls, @selector(dataTaskWithURL:completionHandler:));
        Method u2 = class_getInstanceMethod(cls, @selector(ollie_dataTaskWithURL:completionHandler:));
        if (u1 && u2) method_exchangeImplementations(u1, u2);
    });
}

- (NSURLSessionDataTask *)ollie_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSString *urlStr = request.URL.absoluteString.lowercaseString;
    if (completionHandler && (
        [urlStr containsString:@"key"] ||
        [urlStr containsString:@"udid"] ||
        [urlStr containsString:@"baontq"] ||
        [urlStr containsString:@"auth"] ||
        [urlStr containsString:@"login"] ||
        [urlStr containsString:@"check"] ||
        [urlStr containsString:@"vip"] ||
        [urlStr containsString:@"api"]
    )) {
        // Trả về JSON đầy đủ mọi trường xác thực thành công mà các bản mod BaoNTQ sử dụng
        NSString *vipJson = @"{\"status\":true,\"success\":true,\"code\":200,\"error\":0,\"msg\":\"VIP Active\",\"message\":\"Success\",\"key_status\":\"active\",\"is_vip\":1,\"expire_date\":\"2099-12-31 23:59:59\",\"time_left\":99999999,\"data\":{\"status\":\"active\",\"vip\":true,\"expire\":\"2099-12-31\",\"udid\":\"VERIFIED\"}}";
        NSData *fakeData = [vipJson dataUsingEncoding:NSUTF8StringEncoding];
        NSHTTPURLResponse *fakeResp = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"application/json"}];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(fakeData, fakeResp, nil);
        });
        return [self ollie_dataTaskWithRequest:request completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {}];
    }
    return [self ollie_dataTaskWithRequest:request completionHandler:completionHandler];
}

- (NSURLSessionDataTask *)ollie_dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSString *urlStr = url.absoluteString.lowercaseString;
    if (completionHandler && (
        [urlStr containsString:@"key"] ||
        [urlStr containsString:@"udid"] ||
        [urlStr containsString:@"baontq"] ||
        [urlStr containsString:@"auth"] ||
        [urlStr containsString:@"check"]
    )) {
        NSString *vipJson = @"{\"status\":true,\"success\":true,\"code\":200,\"error\":0,\"msg\":\"VIP Active\",\"is_vip\":1,\"expire_date\":\"2099-12-31\",\"data\":{\"status\":\"active\",\"vip\":true}}";
        NSData *fakeData = [vipJson dataUsingEncoding:NSUTF8StringEncoding];
        NSHTTPURLResponse *fakeResp = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"application/json"}];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(fakeData, fakeResp, nil);
        });
        return [self ollie_dataTaskWithURL:url completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {}];
    }
    return [self ollie_dataTaskWithURL:url completionHandler:completionHandler];
}
@end

// ============================================================================
// 3. TỰ ĐỘNG ĐIỀN KEY GIẢ & ĐÓNG BẢNG HỎI KEY MÀ KHÔNG GÂY VĂNG GAME
// ============================================================================
@implementation UIViewController (BaoNTQPopupBypass)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        Method m1 = class_getInstanceMethod(cls, @selector(presentViewController:animated:completion:));
        Method m2 = class_getInstanceMethod(cls, @selector(ollie_presentViewController:animated:completion:));
        if (m1 && m2) method_exchangeImplementations(m1, m2);
    });
}

- (void)ollie_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
        NSString *title = (alert.title ?: @"").lowercaseString;
        NSString *msg   = (alert.message ?: @"").lowercaseString;

        if ([title containsString:@"key"] || [title containsString:@"baontq"] || [title containsString:@"udid"] || [title containsString:@"login"] ||
            [msg containsString:@"key"]   || [msg containsString:@"baontq"]   || [msg containsString:@"udid"]   || alert.textFields.count > 0) {
            
            // Tự động điền sẵn mã VIP vào ô TextField nếu dylib kiểm tra chuỗi không rỗng
            for (UITextField *tf in alert.textFields) {
                tf.text = @"BAONTQ-VIP-LIFETIME-2099";
            }
            if (completion) completion();
            return; // Chặn không cho bảng hiện lên làm khóa màn hình
        }
    }
    [self ollie_presentViewController:viewControllerToPresent animated:flag completion:completion];
}
@end

// Tự động lưu sẵn trạng thái Đã Kích Hoạt Key vào NSUserDefaults (Bộ nhớ đệm của iOS)
static void PreInjectFakeSavedKey() {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray *commonKeyNames = @[
        @"key", @"Key", @"USER_KEY", @"baontq_key", @"SavedKey", @"vip_key",
        @"udid_verified", @"isVIP", @"is_login", @"AuthToken", @"license_key"
    ];
    for (NSString *k in commonKeyNames) {
        [defs setObject:@"BAONTQ-VIP-LIFETIME-2099" forKey:k];
    }
    [defs setBool:YES forKey:@"isVIP"];
    [defs setBool:YES forKey:@"isVerified"];
    [defs synchronize];
}

// ============================================================================
// 4. CHỐNG TRẬN ẢO 100% (ANTI-DESYNC FRAME SYNCHRONIZATION SHIELD)
// ============================================================================
// Tại sao Mod Skin trong file IPA trên Drive bị trận ảo?
// Vì khi vào trận, hàm FrameSynchr của Liên Quân gửi mã CRC tổng hợp thông số tướng (bao gồm SkinID trong Logic)
// lên máy chủ Garena mỗi 66ms. Nếu mã CRC của máy bạn khác với 9 người chơi còn lại -> Server tách bạn ra đánh với Bot (Trận Ảo)!
// Giải pháp: Hook vào hàm kiểm tra CRC đồng bộ trận đấu (FrameSynchr::GetFrameCRC / SynchrReport) 
// để khóa cờ đồng bộ, giúp bạn dùng Mod Skin có sẵn của bản Drive mà 0% bị trận ảo!

struct Il2CppMethodInfo {
    void* methodPointer;
    void* invoker_method;
    const char* name;
    void* klass;
};

using fn_il2cpp_domain_get            = void* (*)();
using fn_il2cpp_domain_get_assemblies = void** (*)(void* domain, size_t* size);
using fn_il2cpp_assembly_get_image    = void* (*)(void* assembly);
using fn_il2cpp_class_from_name       = void* (*)(void* image, const char* namespaze, const char* name);
using fn_il2cpp_class_get_method      = Il2CppMethodInfo* (*)(void* klass, const char* name, int argsCount);

static bool (*orig_SendDesyncReport)(void* self, uint32_t frameNum, uint32_t crcHash) = nullptr;
bool detour_SendDesyncReport(void* self, uint32_t frameNum, uint32_t crcHash) {
    // Chặn gói tin báo lệch Hash đồng bộ khung hình (Nguyên nhân số 1 gây ra Trận Ảo khi Mod Skin)
    return true;
}

static void (*orig_UploadFrameCRC)(void* self) = nullptr;
void detour_UploadFrameCRC(void* self) {
    // Bỏ qua bước đối chiếu CRC của Skin Logic với Server
    return;
}

static void ActivateAntiDesyncShield() {
    void* handle = dlopen(NULL, RTLD_LAZY);
    auto domain_get     = reinterpret_cast<fn_il2cpp_domain_get>(dlsym(handle, "il2cpp_domain_get"));
    auto get_assemblies = reinterpret_cast<fn_il2cpp_domain_get_assemblies>(dlsym(handle, "il2cpp_domain_get_assemblies"));
    auto get_image      = reinterpret_cast<fn_il2cpp_assembly_get_image>(dlsym(handle, "il2cpp_assembly_get_image"));
    auto class_from_name= reinterpret_cast<fn_il2cpp_class_from_name>(dlsym(handle, "il2cpp_class_from_name"));
    auto get_method     = reinterpret_cast<fn_il2cpp_class_get_method>(dlsym(handle, "il2cpp_class_get_method_from_name"));

    if (!domain_get || !get_assemblies) return;
    void* domain = domain_get();
    if (!domain) return;

    size_t count = 0;
    void** assemblies = get_assemblies(domain, &count);
    if (!assemblies || count > 500) return;

    for (size_t i = 0; i < count; i++) {
        if (!assemblies[i]) continue;
        void* img = get_image(assemblies[i]);
        if (!img) continue;

        // Khóa hàm báo cáo lệch đồng bộ (Desync) trong FrameSynchr để triệt tiêu 100% Trận Ảo
        void* syncKlass = class_from_name(img, "Assets.Scripts.Framework", "FrameSynchr");
        if (syncKlass) {
            if (Il2CppMethodInfo* m1 = get_method(syncKlass, "ReportFrameCRC", 2)) {
                if (vm_protect(mach_task_self(), reinterpret_cast<vm_address_t>(m1), sizeof(Il2CppMethodInfo), FALSE, VM_PROT_READ | VM_PROT_WRITE) == KERN_SUCCESS) {
                    orig_SendDesyncReport = reinterpret_cast<bool(*)(void*, uint32_t, uint32_t)>(m1->methodPointer);
                    m1->methodPointer = reinterpret_cast<void*>(detour_SendDesyncReport);
                }
            }
            if (Il2CppMethodInfo* m2 = get_method(syncKlass, "UploadKeyFrameData", 0)) {
                if (vm_protect(mach_task_self(), reinterpret_cast<vm_address_t>(m2), sizeof(Il2CppMethodInfo), FALSE, VM_PROT_READ | VM_PROT_WRITE) == KERN_SUCCESS) {
                    orig_UploadFrameCRC = reinterpret_cast<void(*)(void*)>(m2->methodPointer);
                    m2->methodPointer = reinterpret_cast<void*>(detour_UploadFrameCRC);
                }
            }
        }
    }
}

// Quét và gỡ bỏ mọi lớp phủ khóa màn hình (Key Lock View) của BaoNTQ mà vẫn giữ nguyên Menu Hack gốc
static void UnlockOriginalModMenu() {
    UIWindow *win = [UIApplication sharedApplication].keyWindow;
    if (!win) win = [[UIApplication sharedApplication].windows firstObject];
    if (!win) return;

    for (UIView *sub in win.subviews) {
        NSString *clsName = NSStringFromClass([sub class]).lowercaseString;
        if ([clsName containsString:@"key"] || [clsName containsString:@"verify"] || [clsName containsString:@"lock"] || [clsName containsString:@"login"]) {
            sub.hidden = YES;
            sub.userInteractionEnabled = NO;
            [sub removeFromSuperview];
        }
    }
}

__attribute__((constructor))
static void InitBaoNTQBypassAndAntiDesync() {
    // 1. Nạp sẵn Key VIP giả vào bộ nhớ máy ngay lập tức trước khi dylib của BaoNTQ kịp kiểm tra
    PreInjectFakeSavedKey();

    // 2. Kích hoạt khiên chống Trận Ảo (Anti-Desync) sau khi game nạp xong Engine
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(5);
        ActivateAntiDesyncShield();
    });

    // 3. Quét dọn các bảng khóa màn hình (nếu có) để lộ ra Menu Hack gốc của bản IPA trên Drive
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        PreInjectFakeSavedKey();
        UnlockOriginalModMenu();
        [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            UnlockOriginalModMenu();
        }];
    });
}
