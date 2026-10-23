#import <UIKit/UIKit.h>
#import "OllieMenu.h"
#include "OllieConfig.h"

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
    UILabel *notice = [self label:@"Menu đã tải. Bản build hiện dùng Dobby stub; bật công tắc chưa kích hoạt tính năng trong game." size:12];
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
@end

@implementation OllieMenuHost
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

void StartOllieMenu(void) {
    NSCAssert(NSThread.isMainThread, @"Menu must start on the main thread");
    static OllieMenuHost *host;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        host = [[OllieMenuHost alloc] init];
        for (NSString *name in @[UIApplicationDidFinishLaunchingNotification, UIApplicationDidBecomeActiveNotification,
                                 UIWindowDidBecomeKeyNotification, UISceneDidActivateNotification]) {
            [NSNotificationCenter.defaultCenter addObserver:host selector:@selector(attach) name:name object:nil];
        }
        host.timer = [NSTimer timerWithTimeInterval:1 target:host selector:@selector(attach) userInfo:nil repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:host.timer forMode:NSRunLoopCommonModes];
    });
    [host attach];
}
