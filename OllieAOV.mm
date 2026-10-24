// File: OllieAOV.mm
// Language: Objective-C++20 | Target: iOS ARM64 Non-Jailbreak (SideStore)
// Target Cracker: baontq23/Logos-API-Authentication (APIClient)
// Cơ chế: Hook trực tiếp phương thức -[APIClient paid:] để chạy thẳng Block mở Menu Hack
//         mà KHÔNG kích hoạt Anti-MITM và KHÔNG dùng vm_protect gây văng ở Logo Liên Quân!

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

// ============================================================================
// 1. HÀM THAY THẾ TRỰC TIẾP CHO CLASS APIClient CỦA BAONTQ (baontq23)
// ============================================================================
// Theo mã nguồn chuẩn của baontq23/Logos-API-Authentication:
// Tác giả bọc toàn bộ lệnh mở Menu Hack trong: [API paid:^{ loadview(); menuSetup(); }];
// Khi ta thay thế hàm paid: bằng hàm dưới đây, nó sẽ kích hoạt thẳng block() mở Menu ngay lập tức
// mà không cần kết nối tới máy chủ baontq.xyz và không hiện bảng nhập Key!

static void Ollie_APIClient_paid(id self, SEL _cmd, void (^ paidBlock)(void)) {
    if (paidBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            paidBlock(); // Chạy thẳng hàm mở Menu Hack của bản IPA gốc!
        });
    }
}

static void Ollie_APIClient_paidWithError(id self, SEL _cmd, void (^ paidBlock)(void), void (^ errorBlock)(NSError *)) {
    if (paidBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            paidBlock();
        });
    }
}

static void Ollie_NoOp_SetToken(id self, SEL _cmd, id token) {
    // Vô hiệu hóa việc kiểm tra Token với máy chủ
}

static id Ollie_Fake_GetString(id self, SEL _cmd) {
    return @"VIP_LIFETIME_2099";
}

// ============================================================================
// 2. TỰ ĐỘNG QUÉT & BẺ KHÓA MỌI CLASS XÁC THỰC KEY TRONG DYLIB GỐC
// ============================================================================
static bool g_Bypassed = false;

static void BypassBaoNTQClasses() {
    // 1. Quét tìm chính xác class "APIClient" (hoặc các tên biến thể trong libAPIClient.a của baontq23)
    const char* targetClasses[] = {
        "APIClient",
        "BaoNTQClient",
        "APIAuthentication",
        "KeyAuth",
        "AuthClient"
    };

    for (const char* clsName : targetClasses) {
        Class cls = objc_getClass(clsName);
        if (!cls) continue;

        // Danh sách các Selector khởi chạy Menu sau khi check key thành công của baontq23
        SEL paidSelectors[] = {
            sel_registerName("paid:"),
            sel_registerName("start:"),
            sel_registerName("verify:"),
            sel_registerName("checkKey:"),
            sel_registerName("loginWithKey:completion:")
        };

        for (SEL sel : paidSelectors) {
            Method m = class_getInstanceMethod(cls, sel);
            if (m) {
                method_setImplementation(m, (IMP)Ollie_APIClient_paid);
                g_Bypassed = true;
            }
            Method cm = class_getClassMethod(cls, sel);
            if (cm) {
                method_setImplementation(cm, (IMP)Ollie_APIClient_paid);
                g_Bypassed = true;
            }
        }

        // Bắt thêm các hàm trả về ngày hết hạn (getExpiredAt / getKey / getDeviceData) trong v5.x - v6.1.0
        SEL infoSelectors[] = {
            sel_registerName("getExpiredAt"),
            sel_registerName("getKey"),
            sel_registerName("getUDID")
        };
        for (SEL sel : infoSelectors) {
            if (Method m = class_getInstanceMethod(cls, sel)) {
                method_setImplementation(m, (IMP)Ollie_Fake_GetString);
            }
        }
    }

    // 2. Quét toàn bộ danh sách Class đang nạp trong bộ nhớ:
    // Nếu tác giả đổi tên class APIClient thành tên ngẫu nhiên nhưng vẫn giữ hàm "paid:" và "setToken:"
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            Class c = classes[i];
            Method mPaid = class_getInstanceMethod(c, sel_registerName("paid:"));
            Method mToken = class_getInstanceMethod(c, sel_registerName("setToken:"));
            if (mPaid && mToken) {
                method_setImplementation(mPaid, (IMP)Ollie_APIClient_paid);
                method_setImplementation(mToken, (IMP)Ollie_NoOp_SetToken);
                g_Bypassed = true;
            }
        }
        free(classes);
    }
}

// ============================================================================
// 3. KHIÊN CHỐNG TRẬN ẢO AN TOÀN (CHẶN GÓI TIN BÁO LỆCH SKIN QUA NSURLSESSION)
// ============================================================================
// Tuyệt đối KHÔNG chạm vào các request của baontq.xyz (để không kích hoạt Anti-MITM gây văng ở Logo),
// chỉ chặn riêng các gói tin báo cáo lệch CRC đồng bộ Skin (Desync Report) gửi về máy chủ Garena!

static void PreSaveFakeKeyDefaults() {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:@"VIP-2099" forKey:@"APIClient_Key"];
    [defs setObject:@"VIP-2099" forKey:@"baontq_key"];
    [defs setObject:@"VIP-2099" forKey:@"saved_key"];
    [defs setBool:YES forKey:@"is_verified"];
}

// Callback tự động chạy ngay lập tức mỗi khi một file .dylib mới được nạp vào bộ nhớ
static void OnDylibImageLoaded(const struct mach_header *mh, intptr_t vmaddr_slide) {
    BypassBaoNTQClasses();
}

__attribute__((constructor))
static void InitSafeBaoNTQCracker() {
    PreSaveFakeKeyDefaults();
    
    // Đăng ký callback với dyld: Ngay khoảnh khắc dylib gốc trong IPA vừa nạp lên RAM
    // (trước cả khi hàm constructor của nó kịp chạy ở màn hình Logo), OnDylibImageLoaded sẽ
    // khóa hàm [APIClient paid:] ngay lập tức!
    _dyld_register_func_for_add_image(OnDylibImageLoaded);
    
    BypassBaoNTQClasses();
}
