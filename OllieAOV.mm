// UIKit menu launcher plus the existing game callbacks.
// The packaging workflow still uses a no-op Dobby stub.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <vector>
#import <string>
#import <cmath>
#import <map>
#include <cstring>
#include <unistd.h>
#include <atomic>
#import <QuartzCore/QuartzCore.h>

// Giả định sử dụng Dobby / CydiaSubstrate cho Hooking trên iOS (Hỗ trợ cả Jitless/Non-JB)
extern "C" int DobbyHook(void *address, void *fake_func, void **out_origin_func);

// ============================================================================
// 1. OFFSETS BLOCK (UnityFramework & anogs - iOS ARM64)
// ============================================================================
namespace off {
    // UnityFramework RVA
    constexpr uintptr_t GetHeroList            = 0x2B14A80; // LogicGameManager::GetAllHeroes()
    constexpr uintptr_t GetMonsterList         = 0x2B14C10; // LogicGameManager::GetAllMonsters()
    constexpr uintptr_t GetLocalPlayer         = 0x2B14B00; // LogicGameManager::GetHostPlayer()
    
    constexpr uintptr_t Actor_GetPos           = 0x1E92100; // ActorLinker::get_Position()
    constexpr uintptr_t Actor_GetTeam          = 0x1E92240; // ActorLinker::get_CampType()
    constexpr uintptr_t Actor_GetHP            = 0x1E92600; // ValuePropertyComponent::get_actorHp()
    constexpr uintptr_t Actor_GetMaxHP         = 0x1E92650; // ValuePropertyComponent::get_actorHpTotal()
    constexpr uintptr_t Actor_GetHeroId        = 0x1E92810; // ActorLinker::get_ConfigId()
    constexpr uintptr_t Actor_SetVisible       = 0x1E93500; // HorizonMarker::SetVisible(bool)
    
    // Cooldown & Skills
    constexpr uintptr_t SkillControl_GetSlot   = 0x2104A00; // SkillControl::GetSkillSlot(int slot)
    constexpr uintptr_t SkillSlot_GetCD        = 0x2105120; // SkillSlot::GetCooldownTime()
    
    // Camera Drone View & W2S
    constexpr uintptr_t Camera_get_main        = 0x39A1200; // UnityEngine.Camera::get_main()
    constexpr uintptr_t Camera_WorldToScreen   = 0x39A0B40; // UnityEngine.Camera::WorldToScreenPoint_Injected
    constexpr uintptr_t Camera_SetHeight       = 0x2410F80; // CameraSystem::SetCameraHeightRate(float)

    // Mod Skin Full (Model + Sound + Recall)
    constexpr uintptr_t Skin_GetWearSkinId     = 0x24C1890; // HeroSkinComponent::GetWearSkinId(uint32_t)
    constexpr uintptr_t Sound_LoadSkinBank     = 0x25A3300; // CSoundManager::LoadSkinSoundBank(uint32_t, uint32_t)
    
    // Anti-Cheat iOS (anogs / TDataMaster)
    constexpr uintptr_t Anogs_SendReport       = 0x00112A40; // anogs_report_data
    constexpr uintptr_t Anogs_MemoryScan       = 0x00154B00; // anogs_check_text_segment
    constexpr uintptr_t Anogs_DyldCheck        = 0x00168C20; // anogs_enum_loaded_dylibs
    constexpr uintptr_t Game_TakeScreenshot    = 0x28F1000; // GameReport::CaptureScreenForReview()
}

// ============================================================================
// 2. CẤU HÌNH HỆ THỐNG (FULL MARKET FEATURES)
// ============================================================================
struct Vector3 { float x, y, z; };

// UI writes and game callbacks may run on different threads.
struct CheatConfig {
    std::atomic<bool> espMaster{true};
    std::atomic<bool> espBox{true};
    std::atomic<bool> espLine{true};
    std::atomic<bool> espHealth{true};
    std::atomic<bool> espSkillCD{true};
    std::atomic<bool> espMinimap{true};
    std::atomic<bool> espJungleTimer{true};
    std::atomic<bool> hackMap{true};
    std::atomic<float> camHeightRate{1.65f};
    std::atomic<bool> autoSmite{true};
    std::atomic<bool> aimElsu{true};
    std::atomic<bool> skinMaster{true};
    std::map<int, int> skinMap = {
        {150, 11}, {167, 12}, {111, 15}, {196, 8}, {520, 7}
    };
    std::atomic<bool> streamProof{true};
};

CheatConfig cfg;

uintptr_t g_UnityBase = 0;
uintptr_t g_AnogsBase = 0;

// ============================================================================
// 3. TRÌNH TÌM ĐỊA CHỈ MODULE TRÊN iOS (DYLD)
// ============================================================================
uintptr_t GetMachOBase(const char* imageName) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, imageName)) {
            return reinterpret_cast<uintptr_t>(_dyld_get_image_header(i));
        }
    }
    return 0;
}

// ============================================================================
// 4. EXISTING CALLBACKS (NOT VALIDATED; BUILD USES A NO-OP STUB)
// ============================================================================
// Chặn gửi gói tin tố cáo về máy chủ Garena
int (*orig_AnogsSendReport)(void* a1, const char* packet, size_t len);
int hook_AnogsSendReport(void* a1, const char* packet, size_t len) {
    return 0;
}

// Giả mạo kiểm tra toàn vẹn vùng nhớ .text của UnityFramework
bool (*orig_AnogsMemoryScan)(uintptr_t addr, size_t len, uint32_t crc);
bool hook_AnogsMemoryScan(uintptr_t addr, size_t len, uint32_t crc) {
    return true;
}

// Ẩn dylib đã tiêm khỏi danh sách quét của Anti-Cheat khi cài qua ESign/Scarlet/TrollStore
const char* (*orig_AnogsDyldCheck)(uint32_t index);
const char* hook_AnogsDyldCheck(uint32_t index) {
    const char* name = orig_AnogsDyldCheck(index);
    if (name && (strstr(name, "OllieAOV.dylib") || strstr(name, "CydiaSubstrate") || strstr(name, "libdobby"))) {
        return "/System/Library/Frameworks/Foundation.framework/Foundation";
    }
    return name;
}

// Chặn Garena tự động chụp màn hình khi bị người chơi khác tố cáo trong trận
void* (*orig_TakeScreenshot)(void* instance);
void* hook_TakeScreenshot(void* instance) {
    // Trả về nullptr để hủy tác vụ chụp màn hình kiểm tra ESP
    return nullptr;
}

// ============================================================================
// 5. CÁC CƠ CHẾ BỔ SUNG: DRONE VIEW, AUTO SMITE, MOD SKIN FULL ÂM THANH
// ============================================================================
// 5.1. Camera Siêu Rộng (Drone View)
void (*orig_SetCameraHeight)(void* instance, float rate);
void hook_SetCameraHeight(void* instance, float rate) {
    orig_SetCameraHeight(instance, cfg.camHeightRate);
}

// 5.2. Mod Skin Không Trận Ảo + Kèm Âm Thanh & Hiệu Ứng Biến Về
uint32_t (*orig_GetWearSkinId)(void* instance, uint32_t heroId);
uint32_t hook_GetWearSkinId(void* instance, uint32_t heroId) {
    if (cfg.skinMaster) {
        auto it = cfg.skinMap.find(static_cast<int>(heroId));
        if (it != cfg.skinMap.end()) {
            return static_cast<uint32_t>(it->second);
        }
    }
    return orig_GetWearSkinId(instance, heroId);
}

void (*orig_LoadSkinBank)(void* instance, uint32_t heroId, uint32_t skinId);
void hook_LoadSkinBank(void* instance, uint32_t heroId, uint32_t skinId) {
    if (cfg.skinMaster) {
        auto it = cfg.skinMap.find(static_cast<int>(heroId));
        if (it != cfg.skinMap.end()) {
            skinId = static_cast<uint32_t>(it->second);
        }
    }
    orig_LoadSkinBank(instance, heroId, skinId);
}

// 5.3. Hack Map Sáng Bụi
void (*orig_SetVisible)(void* instance, bool visible);
void hook_SetVisible(void* instance, bool visible) {
    orig_SetVisible(instance, cfg.hackMap ? true : visible);
}

// ============================================================================
// 6. UIKIT MENU & STARTUP
// ============================================================================
@interface OllieMenuView : UIView
@property(nonatomic, strong) UIButton *launcher;
@property(nonatomic, strong) UIView *panel;
@property(nonatomic, strong) UILabel *cameraLabel;
@property(nonatomic) BOOL positionedLauncher;
@end

@implementation OllieMenuView

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.accessibilityIdentifier = @"ollie.overlay";

    _launcher = [UIButton buttonWithType:UIButtonTypeCustom];
    _launcher.backgroundColor = [UIColor colorWithRed:0.1 green:0.35 blue:0.85 alpha:1];
    [_launcher setTitle:@"MENU" forState:UIControlStateNormal];
    [_launcher setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _launcher.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    _launcher.layer.cornerRadius = 24;
    _launcher.layer.borderWidth = 2;
    _launcher.layer.borderColor = UIColor.whiteColor.CGColor;
    _launcher.accessibilityIdentifier = @"ollie.launcher";
    _launcher.accessibilityLabel = @"Mở menu Ollie";
    _launcher.accessibilityHint = @"Chạm để mở, kéo để di chuyển";
    [_launcher addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [_launcher addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragLauncher:)]];
    [self addSubview:_launcher];

    _panel = [[UIView alloc] initWithFrame:CGRectZero];
    _panel.backgroundColor = [UIColor colorWithWhite:0.07 alpha:0.97];
    _panel.layer.cornerRadius = 16;
    _panel.clipsToBounds = YES;
    _panel.hidden = YES;
    _panel.accessibilityIdentifier = @"ollie.panel";
    [self addSubview:_panel];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [_panel addSubview:scroll];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:_panel.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:_panel.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    UILabel *title = [self label:@"OLLIE AOV" size:19];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"Đóng" forState:UIControlStateNormal];
    close.accessibilityIdentifier = @"ollie.close";
    [close.widthAnchor constraintEqualToConstant:60].active = YES;
    [close.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [close addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[title, close]];
    [stack addArrangedSubview:header];
    UILabel *notice = [self label:@"Menu đã tải. Các công tắc hiện chỉ đổi cài đặt; chức năng trong game chưa được kết nối." size:12];
    notice.textColor = [UIColor colorWithRed:1 green:0.8 blue:0.35 alpha:1];
    [stack addArrangedSubview:notice];

    [self addSwitch:@"ESP tổng" key:@"espMaster" value:cfg.espMaster stack:stack];
    [self addSwitch:@"Khung tướng" key:@"espBox" value:cfg.espBox stack:stack];
    [self addSwitch:@"Đường nối" key:@"espLine" value:cfg.espLine stack:stack];
    [self addSwitch:@"Thanh máu" key:@"espHealth" value:cfg.espHealth stack:stack];
    [self addSwitch:@"Hồi chiêu" key:@"espSkillCD" value:cfg.espSkillCD stack:stack];
    [self addSwitch:@"Biểu tượng bản đồ" key:@"espMinimap" value:cfg.espMinimap stack:stack];
    [self addSwitch:@"Thời gian quái" key:@"espJungleTimer" value:cfg.espJungleTimer stack:stack];
    [self addSwitch:@"Hiện bản đồ" key:@"hackMap" value:cfg.hackMap stack:stack];
    [self addSwitch:@"Tự động Trừng Trị" key:@"autoSmite" value:cfg.autoSmite stack:stack];
    [self addSwitch:@"Ngắm Elsu" key:@"aimElsu" value:cfg.aimElsu stack:stack];
    [self addSwitch:@"Mod skin" key:@"skinMaster" value:cfg.skinMaster stack:stack];

    _cameraLabel = [self label:@"" size:14];
    [stack addArrangedSubview:_cameraLabel];
    UISlider *camera = [[UISlider alloc] init];
    camera.minimumValue = 1;
    camera.maximumValue = 3;
    camera.value = cfg.camHeightRate;
    camera.accessibilityLabel = @"Độ cao camera";
    camera.accessibilityIdentifier = @"ollie.camera";
    [camera addTarget:self action:@selector(changeCamera:) forControlEvents:UIControlEventValueChanged];
    [self changeCamera:camera];
    [stack addArrangedSubview:camera];
    return self;
}

- (UILabel *)label:(NSString *)text size:(CGFloat)size {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:size];
    label.numberOfLines = 0;
    return label;
}

- (void)addSwitch:(NSString *)title key:(NSString *)key value:(BOOL)value stack:(UIStackView *)stack {
    UILabel *label = [self label:title size:14];
    UISwitch *control = [[UISwitch alloc] init];
    control.on = value;
    control.accessibilityLabel = title;
    control.accessibilityIdentifier = key;
    [control addTarget:self action:@selector(changeSwitch:) forControlEvents:UIControlEventValueChanged];
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[label, control]];
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12;
    [row.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [stack addArrangedSubview:row];
}

- (void)changeSwitch:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
#define OLLIE_SETTING(name) if ([key isEqualToString:@#name]) { cfg.name = (bool)sender.on; return; }
    OLLIE_SETTING(espMaster)
    OLLIE_SETTING(espBox)
    OLLIE_SETTING(espLine)
    OLLIE_SETTING(espHealth)
    OLLIE_SETTING(espSkillCD)
    OLLIE_SETTING(espMinimap)
    OLLIE_SETTING(espJungleTimer)
    OLLIE_SETTING(hackMap)
    OLLIE_SETTING(autoSmite)
    OLLIE_SETTING(aimElsu)
    OLLIE_SETTING(skinMaster)
#undef OLLIE_SETTING
}

- (void)changeCamera:(UISlider *)sender {
    cfg.camHeightRate = sender.value;
    self.cameraLabel.text = [NSString stringWithFormat:@"Độ cao camera: %.2fx", sender.value];
}

- (void)toggleMenu {
    self.panel.hidden = !self.panel.hidden;
    self.launcher.accessibilityLabel = self.panel.hidden ? @"Mở menu Ollie" : @"Đóng menu Ollie";
}

// Empty space belongs to the game, even while the panel is open.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

- (CGRect)usableBounds {
    return CGRectInset(UIEdgeInsetsInsetRect(self.bounds, self.safeAreaInsets), 8, 8);
}

- (void)clampLauncher {
    CGRect safe = [self usableBounds];
    CGFloat half = CGRectGetWidth(self.launcher.bounds) / 2;
    CGPoint center = self.launcher.center;
    center.x = MAX(CGRectGetMinX(safe) + half, MIN(center.x, CGRectGetMaxX(safe) - half));
    center.y = MAX(CGRectGetMinY(safe) + half, MIN(center.y, CGRectGetMaxY(safe) - half));
    self.launcher.center = center;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect safe = [self usableBounds];
    if (!self.positionedLauncher && CGRectGetWidth(safe) >= 48 && CGRectGetHeight(safe) >= 48) {
        self.launcher.frame = CGRectMake(CGRectGetMinX(safe) + 8, CGRectGetMidY(safe) - 24, 48, 48);
        self.positionedLauncher = YES;
    }
    [self clampLauncher];
    CGFloat width = MAX(0, MIN(360, CGRectGetWidth(safe)));
    CGFloat height = MAX(0, MIN(440, CGRectGetHeight(safe)));
    self.panel.frame = CGRectMake(CGRectGetMidX(safe) - width / 2, CGRectGetMidY(safe) - height / 2, width, height);
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self setNeedsLayout];
}

- (void)dragLauncher:(UIPanGestureRecognizer *)gesture {
    CGPoint delta = [gesture translationInView:self];
    self.launcher.center = CGPointMake(self.launcher.center.x + delta.x, self.launcher.center.y + delta.y);
    [gesture setTranslation:CGPointZero inView:self];
    [self clampLauncher];
}
@end

@interface OllieMenuHost : NSObject
@property(nonatomic, strong) OllieMenuView *overlay;
@property(nonatomic, strong) NSTimer *timer;
- (void)attach;
- (void)refresh:(id)sender;
@end

@implementation OllieMenuHost
- (void)refresh:(id)sender {
    [self attach];
}

- (void)attach {
    UIApplication *app = UIApplication.sharedApplication;
    if (app.applicationState != UIApplicationStateActive) return;
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    for (UIScene *scene in app.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:UIWindowScene.class]) {
            [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
    // Unity games can still use the legacy AppDelegate window lifecycle.
    if (windows.count == 0) [windows addObjectsFromArray:app.windows];
    UIWindow *host = nil;
    for (UIWindow *window in windows) {
        if (window.hidden || window.alpha <= 0 || window.windowLevel != UIWindowLevelNormal ||
            !window.rootViewController || CGRectIsEmpty(window.bounds)) continue;
        if (!host || window.isKeyWindow) host = window;
        if (window.isKeyWindow) break;
    }
    if (!host) return;
    if (!self.overlay) self.overlay = [[OllieMenuView alloc] initWithFrame:host.bounds];
    if (self.overlay.superview != host) {
        [self.overlay removeFromSuperview];
        self.overlay.frame = host.bounds;
        [host addSubview:self.overlay];
        [self.overlay setNeedsLayout];
        NSLog(@"[OllieAOV] MENU attached to game window");
    }
    // Unity may replace its views after login or while loading a scene.
    if (host.subviews.lastObject != self.overlay) [host bringSubviewToFront:self.overlay];
}
@end

static void StartOllieMenu(void) {
    NSCAssert(NSThread.isMainThread, @"Menu must start on the main thread");
    static OllieMenuHost *host;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        host = [[OllieMenuHost alloc] init];
        for (NSString *name in @[UIApplicationDidFinishLaunchingNotification, UIApplicationDidBecomeActiveNotification,
                                 UIWindowDidBecomeKeyNotification, UISceneDidActivateNotification]) {
            [NSNotificationCenter.defaultCenter addObserver:host selector:@selector(refresh:) name:name object:nil];
        }
        host.timer = [NSTimer timerWithTimeInterval:1 target:host selector:@selector(refresh:) userInfo:nil repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:host.timer forMode:NSRunLoopCommonModes];
    });
    [host attach];
}

// Khởi tạo tự động khi Dylib được nạp vào tiến trình Liên Quân iOS
__attribute__((constructor))
static void InitializeOllieIOS() {
    // UI startup must not wait for UnityFramework or anogs to load.
    dispatch_async(dispatch_get_main_queue(), ^{
        StartOllieMenu();
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        while ((g_AnogsBase = GetMachOBase("anogs")) == 0) {
            usleep(50000);
        }
        DobbyHook((void*)(g_AnogsBase + off::Anogs_SendReport), (void*)hook_AnogsSendReport, (void**)&orig_AnogsSendReport);
        DobbyHook((void*)(g_AnogsBase + off::Anogs_MemoryScan), (void*)hook_AnogsMemoryScan, (void**)&orig_AnogsMemoryScan);
        DobbyHook((void*)(g_AnogsBase + off::Anogs_DyldCheck),  (void*)hook_AnogsDyldCheck,  (void**)&orig_AnogsDyldCheck);

        while ((g_UnityBase = GetMachOBase("UnityFramework")) == 0) {
            usleep(50000);
        }
        DobbyHook((void*)(g_UnityBase + off::Game_TakeScreenshot), (void*)hook_TakeScreenshot,  (void**)&orig_TakeScreenshot);
        DobbyHook((void*)(g_UnityBase + off::Camera_SetHeight),    (void*)hook_SetCameraHeight, (void**)&orig_SetCameraHeight);
        DobbyHook((void*)(g_UnityBase + off::Skin_GetWearSkinId),  (void*)hook_GetWearSkinId,   (void**)&orig_GetWearSkinId);
        DobbyHook((void*)(g_UnityBase + off::Sound_LoadSkinBank),  (void*)hook_LoadSkinBank,    (void**)&orig_LoadSkinBank);
        DobbyHook((void*)(g_UnityBase + off::Actor_SetVisible),    (void*)hook_SetVisible,      (void**)&orig_SetVisible);
    });
}

