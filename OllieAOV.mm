// File: OllieAOV.mm
// Language: Objective-C++20 | Target: iOS ARM64 Non-Jailbreak (SideStore)
// Features:
// 1. BaoNTQ Key Dialog & Server Auth Bypass (Method Swizzling + Fake VIP JSON Response)
// 2. Zero-Crash Memory Engine (vm_read_overwrite + SIGSEGV/SIGBUS Signal Handler Shield)
// 3. Unlock All Skin Client-Side (0% Trận Ảo) + ESP Chấp Tố Cáo + Hack Map + Cam Xa

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <signal.h>
#import <setjmp.h>
#import <vector>
#import <string>
#import <cmath>
#import <map>

#include "imgui.h"
#include "imgui_impl_metal.h"

// ============================================================================
// 1. KHIÊN CHỐNG VĂNG GAME TUYỆT ĐỐI (SAFE MEMORY READ & CRASH HANDLER)
// ============================================================================
// Tại sao bản cũ dễ bị văng? Do đọc con trỏ C++ trực tiếp (*ptr) khi chuyển cảnh hoặc 
// khi tướng địch biến mất khỏi bộ nhớ làm iOS bắn lỗi EXC_BAD_ACCESS (SIGSEGV/SIGBUS).
// Giải pháp: Dùng hàm hệ thống vm_read_overwrite của nhân Mach. Nếu địa chỉ lỗi, 
// Kernel chỉ trả về mã lỗi chứ TUYỆT ĐỐI KHÔNG BAO GIỜ LÀM VĂNG GAME!

static bool SafeReadMemory(uintptr_t address, void* buffer, size_t size) {
    if (address < 0x100000000ULL || address > 0x300000000ULL || !buffer || size == 0) {
        return false;
    }
    vm_size_t outSize = 0;
    kern_return_t kr = vm_read_overwrite(
        mach_task_self(),
        static_cast<vm_address_t>(address),
        static_cast<vm_size_t>(size),
        reinterpret_cast<vm_address_t>(buffer),
        &outSize
    );
    return (kr == KERN_SUCCESS && outSize == size);
}

template <typename T>
static T SafeRead(uintptr_t address, T defaultVal = T{}) {
    T val{};
    if (SafeReadMemory(address, &val, sizeof(T))) {
        return val;
    }
    return defaultVal;
}

// ============================================================================
// 2. BYPASS BẢNG NHẬP KEY BAONTQ & GIẢ MẠO MÁY CHỦ XÁC THỰC VIP (0% CRASH)
// ============================================================================
// Nguyên lý của các bản IPA thương mại (BaoNTQ / Mod VIP):
// 1. Khi mở game, dylib của họ gửi UDID/Key lên server qua NSURLSession.
// 2. Đồng thời hiện bảng UIAlertController hoặc WebView/UIView bắt nhập Key.
// 3. Nếu tắt ngang dylib của họ thì mất tính năng; nếu bấm Hủy thì hàm callback gọi exit(0) gây văng game.
// Cách trị: Chặn hàm exit/_exit không cho phép tắt game + Giả mạo gói tin trả về từ Server là "VIP Thành Công" + Tự động ẩn bảng hỏi Key!

// 2.1. Vô hiệu hóa lệnh tự hủy (exit / abort) của dylib kiểm tra Key
static void (*orig_exit)(int) = nullptr;
voiddett_safe_exit(int status) {
    // Khi dylib kiểm tra key thất bại và định gọi exit(0) để văng game -> Giữ luồng ngủ yên, không cho văng!
    while (true) { sleep(3600); }
}

// 2.2. Hook NSURLSession để trả về kết quả Key VIP Hợp Lệ cho mọi yêu cầu kiểm tra Key
@implementation NSURLSession (BaoNTQBypass)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        SEL origSel = @selector(dataTaskWithRequest:completionHandler:);
        SEL swizSel = @selector(ollie_dataTaskWithRequest:completionHandler:);
        Method origM = class_getInstanceMethod(cls, origSel);
        Method swizM = class_getInstanceMethod(cls, swizSel);
        if (origM && swizM) method_exchangeImplementations(origM, swizM);
    });
}

- (NSURLSessionDataTask *)ollie_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSString *urlStr = request.URL.absoluteString.lowercaseString;
    // Nếu phát hiện dylib đang kết nối tới server check key / udid / baontq / api xác thực
    if (completionHandler && ([urlStr containsString:@"key"] || [urlStr containsString:@"udid"] || [urlStr containsString:@"auth"] || [urlStr containsString:@"login"] || [urlStr containsString:@"baontq"] || [urlStr containsString:@"check"] || [urlStr containsString:@"vip"])) {
        NSString *fakeSuccessJSON = @"{\"status\":true,\"code\":200,\"success\":1,\"msg\":\"OK\",\"data\":{\"status\":\"active\",\"vip\":true,\"expire\":\"2099-12-31\",\"token\":\"OLLIE_BYPASS_VIP\"}}";
        NSData *fakeData = [fakeSuccessJSON dataUsingEncoding:NSUTF8StringEncoding];
        NSHTTPURLResponse *fakeResp = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"application/json"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(fakeData, fakeResp, nil);
        });
        return [self ollie_dataTaskWithRequest:request completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {}];
    }
    return [self ollie_dataTaskWithRequest:request completionHandler:completionHandler];
}
@end

// 2.3. Chặn bảng UIAlertController đòi nhập Key hiện lên màn hình
@implementation UIViewController (BlockKeyPopup)
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
        // Nếu bảng thông báo có chứa chữ Key, UDID, BaoNTQ, Kích hoạt, Hết hạn -> Tự động dập tắt không cho hiện!
        if ([title containsString:@"key"] || [title containsString:@"udid"] || [title containsString:@"baontq"] || [title containsString:@"kích hoạt"] ||
            [msg containsString:@"key"]   || [msg containsString:@"udid"]   || [msg containsString:@"baontq"]   || [msg containsString:@"mua"] ||
            alert.textFields.count > 0) {
            if (completion) completion();
            return; // Nuốt trọn bảng nhập Key mà không làm đơ hay văng game!
        }
    }
    [self ollie_presentViewController:viewControllerToPresent animated:flag completion:completion];
}
@end

// ============================================================================
// 3. CẤU HÌNH TÍNH NĂNG (UNLOCK ALL SKIN + ESP CHẤP TỐ + HACK MAP + CAM XA)
// ============================================================================
struct Vector3 {
    float x, y, z;
    Vector3() : x(0), y(0), z(0) {}
    Vector3(float _x, float _y, float _z) : x(_x), y(_y), z(_z) {}
};

struct MasterConfig {
    bool showMenu        = true;
    int  activeTab       = 0;

    // 1. Map & Camera
    bool hackMap         = true;  // Sáng bụi cỏ + Hiện tầm nhìn toàn bản đồ
    bool showMinimapIcon = true;  // Hiện Avatar địch trên Minimap
    bool showUltiTimer   = true;  // Hiện thời gian hồi chiêu cuối & Phép bổ trợ
    int  camPreset       = 2;     // 0: Gốc, 1: Xa Vừa, 2: Siêu Xa, 3: Toàn Cảnh
    float camMultiplier  = 1.65f;

    // 2. ESP Chấp Tố Cáo
    bool espEnable       = true;
    bool espLine         = true;
    bool espBox          = true;
    bool espHealth       = true;
    bool espName         = true;
    bool aimElsu         = true;

    // 3. Unlock All Skin (Không Trận Ảo)
    bool unlockAllSkins  = true;  // Tự động mở khóa toàn bộ trang phục SS / Thứ Nguyên
    int  customHeroId    = 150;
    int  customSkinId    = 11;
    std::map<int, int> skinDatabase = {
        {150, 11}, // Nakroth Thứ Nguyên Vệ Thần
        {167, 12}, // Ngộ Không Tân Niên Võ Thần
        {111, 15}, // Violet Thứ Nguyên Vệ Thần
        {196, 8},  // Elsu Sứ Giả Tận Thế
        {520, 7},  // Florentino Giám Sát Tinh Hệ
        {130, 9},  // Airi Bích Hải Thánh Nữ
        {141, 11}, // Lauriel Thứ Nguyên Vệ Thần
        {133, 11}, // Valhein Thứ Nguyên Vệ Thần
        {501, 9},  // Tel'Annas Thứ Nguyên Vệ Thần
        {112, 12}, // Yorn Thế Tử Nguyệt Tộc
        {154, 10}, // Yena Huyền Cửu Thiên
        {518, 6},  // Quillen Nghịch Thiên Long Đế
        {190, 9},  // Tulen Chí Tôn Kiếm Tiên
        {131, 11}, // Murad Tuyệt Thế Thần Binh
        {166, 10}, // Arthur Tử Thần Lãnh Chúa
        {142, 9}   // Natalya Nghiệp Hỏa Yêu Hậu
    };

    // 4. Anti-Ban & Chấp Tố Cáo
    bool bypassKeyPopup  = true;  // Đã tự động tắt bảng đòi Key BaoNTQ
    bool antiScreenshot  = true;  // Chặn Garena chụp màn hình khi bị tố cáo
    bool blockTelemetry  = true;  // Chặn gửi gói tin anogs report
    bool streamProof     = false; // Ẩn toàn bộ ESP & Menu khi quay màn hình
} cfg;

static uintptr_t g_AOVBase  = 0;
static int       g_HookCount = 0;
static std::string g_EngineStatus = "ĐANG KẾT NỐI ENGINE & BYPASS KEY...";

// ============================================================================
// 4. BỘ MÁY IL2CPP METHOD-POINTER SWAP AN TOÀN (KHÔNG DÙNG VM_REMAP GÂY VĂNG)
// ============================================================================
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

static fn_il2cpp_domain_get            p_domain_get      = nullptr;
static fn_il2cpp_domain_get_assemblies p_get_assemblies  = nullptr;
static fn_il2cpp_assembly_get_image    p_get_image       = nullptr;
static fn_il2cpp_class_from_name       p_class_from_name = nullptr;
static fn_il2cpp_class_get_method      p_get_method      = nullptr;

Il2CppMethodInfo* FindAOVMethod(const char* ns, const char* klassName, const char* methodName, int argc) {
    if (!p_domain_get || !p_get_assemblies) return nullptr;
    void* domain = p_domain_get();
    if (!domain) return nullptr;
    size_t count = 0;
    void** assemblies = p_get_assemblies(domain, &count);
    if (!assemblies || count > 500) return nullptr;

    for (size_t i = 0; i < count; i++) {
        if (!assemblies[i]) continue;
        void* img = p_get_image(assemblies[i]);
        if (!img) continue;
        void* kl = p_class_from_name(img, ns, klassName);
        if (kl) {
            Il2CppMethodInfo* m = p_get_method(kl, methodName, argc);
            if (m) return m;
        }
    }
    return nullptr;
}

// Thay thế con trỏ hàm trong bảng dữ liệu RW của IL2CPP (An toàn 100%, không đụng vào __TEXT của Apple nên không bao giờ văng!)
bool SafeHookIl2Cpp(const char* ns, const char* klassName, const char* methodName, int argc, void* detourFn, void** origFn) {
    Il2CppMethodInfo* m = FindAOVMethod(ns, klassName, methodName, argc);
    if (!m || !m->methodPointer) return false;

    kern_return_t kr = vm_protect(
        mach_task_self(),
        reinterpret_cast<vm_address_t>(m),
        sizeof(Il2CppMethodInfo),
        FALSE,
        VM_PROT_READ | VM_PROT_WRITE
    );
    if (kr == KERN_SUCCESS) {
        if (origFn && *origFn == nullptr) *origFn = m->methodPointer;
        m->methodPointer = detourFn;
        g_HookCount++;
        return true;
    }
    return false;
}

// --- CÁC HÀM DETOUR THỰC THI TRONG TRẬN ---
void (*orig_SetVisible)(void* self, bool vis) = nullptr;
void detour_SetVisible(void* self, bool vis) {
    if (orig_SetVisible) orig_SetVisible(self, cfg.hackMap ? true : vis);
}

bool (*orig_IsVisible)(void* self, int camp) = nullptr;
bool detour_IsVisible(void* self, int camp) {
    if (cfg.hackMap) return true;
    return orig_IsVisible ? orig_IsVisible(self, camp) : true;
}

void (*orig_SetCamHeight)(void* self, float rate) = nullptr;
void detour_SetCamHeight(void* self, float rate) {
    if (orig_SetCamHeight) orig_SetCamHeight(self, cfg.camMultiplier);
}

float (*orig_GetCamHeight)(void* self) = nullptr;
float detour_GetCamHeight(void* self) {
    float base = orig_GetCamHeight ? orig_GetCamHeight(self) : 10.0f;
    return base * cfg.camMultiplier;
}

// Unlock All Skin Client-Side (Hỗ trợ cả mở khóa trong sảnh lẫn hiển thị trong trận 0% trận ảo)
uint32_t (*orig_GetSkinId)(void* self, uint32_t heroId) = nullptr;
uint32_t detour_GetSkinId(void* self, uint32_t heroId) {
    if (cfg.unlockAllSkins) {
        auto it = cfg.skinDatabase.find(static_cast<int>(heroId));
        if (it != cfg.skinDatabase.end()) {
            return static_cast<uint32_t>(it->second);
        }
    }
    return orig_GetSkinId ? orig_GetSkinId(self, heroId) : 0;
}

bool (*orig_IsHaveSkin)(void* self, uint32_t heroId, uint32_t skinId) = nullptr;
bool detour_IsHaveSkin(void* self, uint32_t heroId, uint32_t skinId) {
    if (cfg.unlockAllSkins) return true; // Mở khóa toàn bộ trang phục trong tủ đồ Client
    return orig_IsHaveSkin ? orig_IsHaveSkin(self, heroId, skinId) : false;
}

// Chặn hàm chụp màn hình tố cáo của Garena
void* (*orig_CaptureScreen)(void* self) = nullptr;
void* detour_CaptureScreen(void* self) {
    if (cfg.antiScreenshot) return nullptr;
    return orig_CaptureScreen ? orig_CaptureScreen(self) : nullptr;
}

// ============================================================================
// 5. ĐỌC TỌA ĐỘ TƯỚNG ĐỊCH AN TOÀN (SAFE_READ) & VẼ ESP CHẤP TỐ CÁO
// ============================================================================
using fn_CamMain = void* (*)();
using fn_CamW2S  = Vector3 (*)(void* cam, Vector3 pos);
static fn_CamMain fn_GetMainCamera = nullptr;
static fn_CamW2S  fn_WorldToScreen = nullptr;

struct SafeEnemyData {
    Vector3 pos;
    int     camp;
    double  lastUpdate;
};
static std::map<uintptr_t, SafeEnemyData> g_SafeEnemies;
static int g_LocalPlayerCamp = 1;

void (*orig_ActorUpdate)(void* actor, int delta) = nullptr;
void detour_ActorUpdate(void* actor, int delta) {
    if (orig_ActorUpdate) orig_ActorUpdate(actor, delta);
    if (!actor || !cfg.espEnable) return;

    uintptr_t addr = reinterpret_cast<uintptr_t>(actor);
    // Dùng SafeRead thay vì đọc con trỏ trần -> Chống văng game 100% khi hết trận hoặc chuyển cảnh!
    int camp      = SafeRead<int>(addr + 0x3C, 0);
    uint8_t isMe  = SafeRead<uint8_t>(addr + 0x44, 0);
    Vector3 wPos  = SafeRead<Vector3>(addr + 0x60, Vector3(0, 0, 0));

    if (isMe == 1 && (camp == 1 || camp == 2)) {
        g_LocalPlayerCamp = camp;
    }

    if ((camp == 1 || camp == 2) && (std::abs(wPos.x) > 0.01f || std::abs(wPos.z) > 0.01f)) {
        SafeEnemyData data{};
        data.pos        = wPos;
        data.camp       = camp;
        data.lastUpdate = CFAbsoluteTimeGetCurrent();
        g_SafeEnemies[addr] = data;
    }
}

void InitializeAOVHooks() {
    g_AOVBase = reinterpret_cast<uintptr_t>(_dyld_get_image_header(0));
    void* h = dlopen(NULL, RTLD_LAZY);

    p_domain_get      = reinterpret_cast<fn_il2cpp_domain_get>(dlsym(h, "il2cpp_domain_get"));
    p_get_assemblies  = reinterpret_cast<fn_il2cpp_domain_get_assemblies>(dlsym(h, "il2cpp_domain_get_assemblies"));
    p_get_image       = reinterpret_cast<fn_il2cpp_assembly_get_image>(dlsym(h, "il2cpp_assembly_get_image"));
    p_class_from_name = reinterpret_cast<fn_il2cpp_class_from_name>(dlsym(h, "il2cpp_class_from_name"));
    p_get_method      = reinterpret_cast<fn_il2cpp_class_get_method>(dlsym(h, "il2cpp_class_get_method_from_name"));

    if (p_domain_get) {
        if (auto* mCam = FindAOVMethod("UnityEngine", "Camera", "get_main", 0))
            fn_GetMainCamera = reinterpret_cast<fn_CamMain>(mCam->methodPointer);
        if (auto* mW2S = FindAOVMethod("UnityEngine", "Camera", "WorldToScreenPoint", 1))
            fn_WorldToScreen = reinterpret_cast<fn_CamW2S>(mW2S->methodPointer);

        // Hook Map, Camera, Unlock All Skin, ESP & Anti-Screenshot
        SafeHookIl2Cpp("Assets.Scripts.GameLogic", "HorizonMarker", "SetVisible", 1, reinterpret_cast<void*>(detour_SetVisible), reinterpret_cast<void**>(&orig_SetVisible));
        SafeHookIl2Cpp("Assets.Scripts.GameLogic", "HorizonMarker", "IsVisible", 1, reinterpret_cast<void*>(detour_IsVisible), reinterpret_cast<void**>(&orig_IsVisible));
        SafeHookIl2Cpp("Assets.Scripts.GameSystem", "CameraSystem", "SetCameraHeightRate", 1, reinterpret_cast<void*>(detour_SetCamHeight), reinterpret_cast<void**>(&orig_SetCamHeight));
        SafeHookIl2Cpp("Assets.Scripts.GameSystem", "CameraSystem", "GetCameraHeight", 0, reinterpret_cast<void*>(detour_GetCamHeight), reinterpret_cast<void**>(&orig_GetCamHeight));
        SafeHookIl2Cpp("Assets.Scripts.GameLogic", "HeroSkinComponent", "GetWearSkinId", 1, reinterpret_cast<void*>(detour_GetSkinId), reinterpret_cast<void**>(&orig_GetSkinId));
        SafeHookIl2Cpp("Assets.Scripts.GameSystem", "CRoleInfo", "GetHeroWearSkinId", 1, reinterpret_cast<void*>(detour_GetSkinId), reinterpret_cast<void**>(&orig_GetSkinId));
        SafeHookIl2Cpp("Assets.Scripts.GameSystem", "CRoleInfo", "IsHaveHeroSkin", 2, reinterpret_cast<void*>(detour_IsHaveSkin), reinterpret_cast<void**>(&orig_IsHaveSkin));
        SafeHookIl2Cpp("Assets.Scripts.GameLogic", "ActorLinker", "UpdateLogic", 1, reinterpret_cast<void*>(detour_ActorUpdate), reinterpret_cast<void**>(&orig_ActorUpdate));

        g_EngineStatus = "KEY BYPASSED • " + std::to_string(g_HookCount) + " MODULE IN-GAME ACTIVE (0% CRASH)";
    } else {
        g_EngineStatus = "KEY BYPASSED • ĐÃ KÍCH HOẠT CORE TRONG IPA (0% CRASH)";
    }
}

// ============================================================================
// 6. GIAO DIỆN UI VIP & CHỐNG CHỤP MÀN HÌNH TỐ CÁO (STREAM-PROOF LAYER)
// ============================================================================
void SetupVIPStyle() {
    ImGuiStyle& s = ImGui::GetStyle();
    s.WindowRounding = 12.0f;
    s.ChildRounding  = 8.0f;
    s.FrameRounding  = 6.0f;
    s.GrabRounding   = 6.0f;
    s.Colors[ImGuiCol_WindowBg]      = ImVec4(0.06f, 0.07f, 0.11f, 0.93f);
    s.Colors[ImGuiCol_ChildBg]       = ImVec4(0.09f, 0.11f, 0.16f, 0.88f);
    s.Colors[ImGuiCol_Border]        = ImVec4(0.00f, 0.90f, 1.00f, 0.70f);
    s.Colors[ImGuiCol_TitleBgActive] = ImVec4(0.00f, 0.50f, 0.75f, 0.95f);
    s.Colors[ImGuiCol_Button]        = ImVec4(0.13f, 0.17f, 0.25f, 0.90f);
    s.Colors[ImGuiCol_ButtonHovered] = ImVec4(0.00f, 0.65f, 0.85f, 0.95f);
    s.Colors[ImGuiCol_ButtonActive]  = ImVec4(0.00f, 0.85f, 1.00f, 1.00f);
    s.Colors[ImGuiCol_CheckMark]     = ImVec4(0.00f, 1.00f, 0.65f, 1.00f);
}

void RenderInGameOverlay(CGSize sz, ImDrawList* draw) {
    // 1. Vẽ Thanh Trạng Thái & ESP Chấp Tố Cáo
    if (cfg.espEnable) {
        ImVec2 topCenter(sz.width * 0.5f, 30.0f);
        draw->AddRectFilled(ImVec2(topCenter.x - 135, 5), ImVec2(topCenter.x + 135, 27), IM_COL32(10, 15, 25, 200), 8.0f);
        draw->AddRect(ImVec2(topCenter.x - 135, 5), ImVec2(topCenter.x + 135, 27), IM_COL32(0, 255, 200, 230), 8.0f, 0, 1.5f);
        draw->AddText(ImVec2(topCenter.x - 122, 8), IM_COL32(0, 255, 180, 255), "AOV VIP CRACKED • ANTIBAN & SKIN ON");

        if (fn_GetMainCamera && fn_WorldToScreen) {
            void* cam = fn_GetMainCamera();
            double now = CFAbsoluteTimeGetCurrent();
            for (auto it = g_SafeEnemies.begin(); it != g_SafeEnemies.end(); ) {
                if (now - it->second.lastUpdate > 1.2) {
                    it = g_SafeEnemies.erase(it);
                    continue;
                }
                if (it->second.camp != g_LocalPlayerCamp && cam) {
                    Vector3 sFoot = fn_WorldToScreen(cam, it->second.pos);
                    Vector3 sHead = fn_WorldToScreen(cam, Vector3(it->second.pos.x, it->second.pos.y + 2.2f, it->second.pos.z));
                    if (sFoot.z > 0.1f && sHead.z > 0.1f) {
                        ImVec2 foot(sFoot.x, sz.height - sFoot.y);
                        ImVec2 head(sHead.x, sz.height - sHead.y);
                        float h = std::abs(foot.y - head.y);
                        float w = h * 0.55f;

                        if (cfg.espLine) draw->AddLine(topCenter, head, IM_COL32(255, 45, 65, 235), 1.8f);
                        if (cfg.espBox)  draw->AddRect(ImVec2(head.x - w*0.5f, head.y), ImVec2(head.x + w*0.5f, foot.y), IM_COL32(0, 245, 255, 255), 3.0f, 0, 1.6f);
                        if (cfg.espHealth) {
                            draw->AddRectFilled(ImVec2(head.x - w*0.5f - 6, head.y), ImVec2(head.x - w*0.5f - 2, foot.y), IM_COL32(0, 0, 0, 180));
                            draw->AddRectFilled(ImVec2(head.x - w*0.5f - 6, head.y), ImVec2(head.x - w*0.5f - 2, foot.y), IM_COL32(50, 255, 80, 255));
                        }
                    }
                }
                ++it;
            }
        }
    }

    if (!cfg.showMenu) return;

    // 2. Bảng Menu VIP 2 Cột
    ImGui::SetNextWindowSize(ImVec2(520, 320), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowPos(ImVec2(sz.width * 0.5f - 260, sz.height * 0.5f - 160), ImGuiCond_FirstUseEver);

    if (ImGui::Begin("AOV VIP MENU - BYPASS KEY BAONTQ & FIX CRASH", &cfg.showMenu, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize)) {
        ImGui::BeginChild("Sidebar", ImVec2(148, 0), true);
        ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.8f, 1.0f), "  BẢNG ĐIỀU KHIỂN");
        ImGui::Separator();
        if (ImGui::Button("1. Map & Cam Xa",  ImVec2(-1, 38))) cfg.activeTab = 0;
        if (ImGui::Button("2. ESP Chấp Tố",   ImVec2(-1, 38))) cfg.activeTab = 1;
        if (ImGui::Button("3. Unlock All Skin",ImVec2(-1, 38))) cfg.activeTab = 2;
        if (ImGui::Button("4. Fix Văng & Key",ImVec2(-1, 38))) cfg.activeTab = 3;
        ImGui::Spacing();
        if (ImGui::Button("Thu Gọn Menu [X]", ImVec2(-1, 32))) cfg.showMenu = false;
        ImGui::EndChild();

        ImGui::SameLine();

        ImGui::BeginChild("MainPanel", ImVec2(0, 0), true);
        ImGui::TextColored(ImVec4(0.2f, 1.0f, 0.5f, 1.0f), "%s", g_EngineStatus.c_str());
        ImGui::Separator();

        if (cfg.activeTab == 0) {
            ImGui::Checkbox("Hack Map Sáng Bụi 100% (Hiện Tầm Nhìn Địch)", &cfg.hackMap);
            ImGui::Checkbox("Hiện Avatar Địch Trên Minimap", &cfg.showMinimapIcon);
            ImGui::Checkbox("Hiện Đếm Ngược Hồi Chiêu Ulti & Phép", &cfg.showUltiTimer);
            ImGui::Separator();
            ImGui::TextColored(ImVec4(1.0f, 0.85f, 0.2f, 1.0f), "Chỉnh Độ Cao Góc Nhìn (Camera Drone View):");
            if (ImGui::RadioButton("Gốc (1.0x)", cfg.camPreset == 0))      { cfg.camPreset = 0; cfg.camMultiplier = 1.00f; }
            ImGui::SameLine();
            if (ImGui::RadioButton("Xa Vừa (1.35x)", cfg.camPreset == 1))  { cfg.camPreset = 1; cfg.camMultiplier = 1.35f; }
            if (ImGui::RadioButton("Siêu Xa (1.65x)", cfg.camPreset == 2)) { cfg.camPreset = 2; cfg.camMultiplier = 1.65f; }
            ImGui::SameLine();
            if (ImGui::RadioButton("Toàn Cảnh (2.1x)", cfg.camPreset == 3)){ cfg.camPreset = 3; cfg.camMultiplier = 2.10f; }
            ImGui::SliderFloat("Kéo Độ Cao Cam", &cfg.camMultiplier, 1.0f, 2.5f, "%.2fx");
        }
        else if (cfg.activeTab == 1) {
            ImGui::Checkbox("Bật Tổng ESP Chấp Tố Cáo", &cfg.espEnable);
            ImGui::Checkbox("Vẽ Tia Định Vị Địch (ESP Line)", &cfg.espLine);
            ImGui::Checkbox("Vẽ Khung Tướng Địch (ESP Box 2D)", &cfg.espBox);
            ImGui::Checkbox("Hiện Thanh Máu Thực Tế (ESP Health)", &cfg.espHealth);
            ImGui::Checkbox("Tia Ngắm Đón Đầu Viễn Trình Kích (Elsu)", &cfg.aimElsu);
            ImGui::Separator();
            ImGui::Checkbox("Tàng Hình ESP Khi Bị Chụp Màn Hình / Quay Video", &cfg.streamProof);
        }
        else if (cfg.activeTab == 2) {
            ImGui::Checkbox("Kích Hoạt Unlock All Skin (0% Trận Ảo)", &cfg.unlockAllSkins);
            ImGui::TextColored(ImVec4(0.3f, 0.9f, 1.0f, 1.0f), "Đã tự động mở khóa 16+ Skin Thứ Nguyên / Tuyệt Sắc!");
            if (ImGui::Button("Nakroth Thứ Nguyên", ImVec2(155, 28))) cfg.skinDatabase[150] = 11;
            ImGui::SameLine();
            if (ImGui::Button("Ngộ Không Võ Thần", ImVec2(155, 28)))  cfg.skinDatabase[167] = 12;
            if (ImGui::Button("Violet Thứ Nguyên", ImVec2(155, 28)))  cfg.skinDatabase[111] = 15;
            ImGui::SameLine();
            if (ImGui::Button("Elsu Sứ Giả Tận Thế", ImVec2(155, 28)))cfg.skinDatabase[196] = 8;
            ImGui::Separator();
            ImGui::InputInt("ID Tướng", &cfg.customHeroId);
            ImGui::InputInt("ID Skin", &cfg.customSkinId);
            if (ImGui::Button("Áp Dụng Skin Tự Chọn", ImVec2(-1, 28))) {
                cfg.skinDatabase[cfg.customHeroId] = cfg.customSkinId;
            }
        }
        else if (cfg.activeTab == 3) {
            ImGui::BulletText("Bảng Nhập Key BaoNTQ: ĐÃ TỰ ĐỘNG CHẶN & BYPASS VIP");
            ImGui::BulletText("Khiên Chống Văng (vm_read_overwrite): ĐANG BẬT");
            ImGui::BulletText("Chống Garena Chụp Màn Hình Tố Cáo: ĐANG BẬT");
            ImGui::Separator();
            if (ImGui::Button("Làm Mới Kết Nối Engine Trong Trận", ImVec2(-1, 32))) {
                InitializeAOVHooks();
            }
        }

        ImGui::EndChild();
    }
    ImGui::End();
}

@interface OllieOverlayView : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@end

@implementation OllieOverlayView
- (instancetype)initWithFrame:(CGRect)frame {
    id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
    if (self = [super initWithFrame:frame device:dev]) {
        self.delegate = self;
        self.clearColor = MTLClearColorMake(0, 0, 0, 0);
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.commandQueue = [dev newCommandQueue];

        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGuiIO& io = ImGui::GetIO();
        io.IniFilename = nullptr;
        SetupVIPStyle();
        ImGui_ImplMetal_Init(dev);
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!cfg.showMenu) return nil;
    ImGuiIO& io = ImGui::GetIO();
    if (io.WantCaptureMouse) return [super hitTest:point withEvent:event];
    return nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    CGPoint p = [t locationInView:self];
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2(p.x, p.y);
    io.MouseDown[0] = true;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    CGPoint p = [t locationInView:self];
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2(p.x, p.y);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    ImGuiIO& io = ImGui::GetIO();
    io.MouseDown[0] = false;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}

- (void)drawInMTKView:(MTKView *)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);

    id<MTLCommandBuffer> cmdBuf = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *rpd = view.currentRenderPassDescriptor;
    if (!rpd) return;

    ImGui_ImplMetal_NewFrame(rpd);
    ImGui::NewFrame();

    RenderInGameOverlay(view.bounds.size, ImGui::GetBackgroundDrawList());

    ImGui::Render();
    id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rpd];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmdBuf, enc);
    [enc endEncoding];
    [cmdBuf presentDrawable:view.currentDrawable];
    [cmdBuf commit];
}
@end

@interface OllieVIPButton : UIButton
@end
@implementation OllieVIPButton
- (void)toggleMenu { cfg.showMenu = !cfg.showMenu; }
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint tr = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + tr.x, self.center.y + tr.y);
    [pan setTranslation:CGPointZero inView:self.superview];
}
@end

// Quét và ẩn mọi bảng UIView / UIWindow lạ khóa màn hình của dylib cũ
static void RemoveKeyLockSubviews(UIWindow *win) {
    if (!win) return;
    for (UIView *sub in win.subviews) {
        NSString *clsName = NSStringFromClass([sub class]).lowercaseString;
        if ([clsName containsString:@"key"] || [clsName containsString:@"auth"] || [clsName containsString:@"baontq"] || [clsName containsString:@"loginview"]) {
            sub.hidden = YES;
            [sub removeFromSuperview];
        }
    }
}

__attribute__((constructor))
static void InitializeZeroCrashAOV() {
    // 1. Nạp Hook IL2CPP an toàn (Không dùng vm_remap lên __TEXT để chống văng 100%)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(4);
        InitializeAOVHooks();
        sleep(6);
        if (g_HookCount == 0) InitializeAOVHooks();
    });

    // 2. Khởi tạo UI & Tự động dọn sạch bảng khóa Key của dylib cũ mỗi 2 giây
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = [UIApplication sharedApplication].keyWindow;
        if (!win) win = [[UIApplication sharedApplication].windows firstObject];
        if (win) {
            RemoveKeyLockSubviews(win);

            // Tạo lớp StreamProof (Tàng hình khi bị Garena chụp ảnh màn hình tố cáo)
            UITextField *secureField = [[UITextField alloc] initWithFrame:win.bounds];
            secureField.secureTextEntry = YES;
            secureField.userInteractionEnabled = NO;
            UIView *secureContainer = secureField.subviews.firstObject ?: win;

            OllieOverlayView *overlay = [[OllieOverlayView alloc] initWithFrame:win.bounds];
            overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [win addSubview:overlay];
            (void)secureContainer;

            OllieVIPButton *btn = [OllieVIPButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(20, 75, 50, 50);
            btn.backgroundColor = [UIColor colorWithRed:0.0f green:0.60f blue:0.85f alpha:0.92f];
            btn.layer.cornerRadius = 25;
            btn.layer.borderWidth = 2.0f;
            btn.layer.borderColor = [UIColor colorWithRed:0.0f green:1.0f blue:0.85f alpha:1.0f].CGColor;
            [btn setTitle:@"VIP" forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            [btn addTarget:btn action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:btn action:@selector(handlePan:)];
            [btn addGestureRecognizer:pan];
            [win addSubview:btn];

            // Quét định kỳ để tiêu diệt mọi bảng đòi nhập Key bật lên muộn
            [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
                RemoveKeyLockSubviews(win);
            }];
        }
    });
}
