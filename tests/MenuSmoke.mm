#import <UIKit/UIKit.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include "OllieConfig.h"
#import "OllieMenu.h"

CheatConfig cfg;

static void Check(bool value, const char *message) {
    if (!value) {
        fprintf(stderr, "MENU_SMOKE_FAILED: %s\n", message);
        fflush(stderr);
        exit(1);
    }
}

static UIView *Find(UIView *root, NSString *identifier) {
    if ([root.accessibilityIdentifier isEqualToString:identifier]) return root;
    for (UIView *child in root.subviews) {
        UIView *found = Find(child, identifier);
        if (found) return found;
    }
    return nil;
}

@interface MenuSmokeDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic) BOOL tested;
@end

@implementation MenuSmokeDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    // Starting before an active window exists must be safe and retry later.
    StartOllieMenu();
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.rootViewController.view.backgroundColor = UIColor.darkGrayColor;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (self.tested) return;
    self.tested = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        StartOllieMenu();
        [self.window layoutIfNeeded];
        UIView *overlay = Find(self.window, @"ollie.overlay");
        Check(overlay != nil, "overlay attaches after startup");
        [overlay layoutIfNeeded];
        UIButton *launcher = (UIButton *)Find(overlay, @"ollie.launcher");
        UIView *panel = Find(overlay, @"ollie.panel");
        Check(launcher != nil && !launcher.hidden && !CGRectIsEmpty(launcher.frame), "visible launcher");
        Check(panel != nil && panel.hidden, "panel starts closed");
        Check([overlay hitTest:launcher.center withEvent:nil] == launcher, "launcher accepts touches");
        Check([overlay hitTest:CGPointMake(2, 2) withEvent:nil] == nil, "empty area passes touches through");
        [launcher sendActionsForControlEvents:UIControlEventTouchUpInside];
        Check(!panel.hidden, "launcher opens panel");
        [overlay layoutIfNeeded];
        Check(CGRectContainsRect(overlay.bounds, panel.frame), "panel stays on screen");
        Check([overlay hitTest:panel.center withEvent:nil] != nil, "panel accepts touches");
        Check([overlay hitTest:CGPointMake(2, 2) withEvent:nil] == nil, "open panel preserves outside touches");

        NSArray<NSString *> *keys = @[@"espMaster", @"espBox", @"espLine", @"espHealth", @"espSkillCD", @"espMinimap",
                                     @"espJungleTimer", @"hackMap", @"autoSmite", @"aimElsu", @"skinMaster"];
        std::atomic<bool> *values[] = {&cfg.espMaster, &cfg.espBox, &cfg.espLine, &cfg.espHealth, &cfg.espSkillCD,
                                      &cfg.espMinimap, &cfg.espJungleTimer, &cfg.hackMap, &cfg.autoSmite, &cfg.aimElsu, &cfg.skinMaster};
        for (NSUInteger i = 0; i < keys.count; ++i) {
            UISwitch *control = (UISwitch *)Find(overlay, keys[i]);
            Check(control != nil, "setting exists");
            control.on = NO;
            [control sendActionsForControlEvents:UIControlEventValueChanged];
            Check(!values[i]->load(), "switch updates matching configuration off");
            control.on = YES;
            [control sendActionsForControlEvents:UIControlEventValueChanged];
            Check(values[i]->load(), "switch updates matching configuration on");
        }
        UISlider *camera = (UISlider *)Find(overlay, @"ollie.camera");
        camera.value = 2.25f;
        [camera sendActionsForControlEvents:UIControlEventValueChanged];
        Check(std::fabs(cfg.camHeightRate.load() - 2.25f) < 0.001f, "slider updates camera setting");
        UIButton *close = (UIButton *)Find(overlay, @"ollie.close");
        [close sendActionsForControlEvents:UIControlEventTouchUpInside];
        Check(panel.hidden, "close button hides panel");

        // Exercise the same clamping invoked after dragging and rotation.
        for (NSValue *size in @[[NSValue valueWithCGSize:CGSizeMake(844, 390)],
                               [NSValue valueWithCGSize:CGSizeMake(390, 844)],
                               [NSValue valueWithCGSize:CGSizeMake(320, 568)]]) {
            overlay.frame = (CGRect){CGPointZero, size.CGSizeValue};
            launcher.center = CGPointMake(2000, -100);
            [overlay setNeedsLayout];
            [overlay layoutIfNeeded];
            CGRect safe = CGRectInset(UIEdgeInsetsInsetRect(overlay.bounds, overlay.safeAreaInsets), 8, 8);
            Check(CGRectContainsRect(safe, launcher.frame), "launcher clamps to safe area after resize/drag");
            Check(CGRectContainsRect(safe, panel.frame), "panel fits safe area after resize");
        }

        // Replacement Unity content must not cover the menu indefinitely.
        UIView *cover = [[UIView alloc] initWithFrame:self.window.bounds];
        [self.window addSubview:cover];
        StartOllieMenu();
        Check(self.window.subviews.lastObject == overlay, "menu returns above new game content");
        [overlay removeFromSuperview];
        StartOllieMenu();
        Check(overlay.superview == self.window, "removed overlay reattaches");
        StartOllieMenu();
        NSUInteger count = 0;
        for (UIView *view in self.window.subviews) if ([view.accessibilityIdentifier isEqualToString:@"ollie.overlay"]) ++count;
        Check(count == 1, "repeated startup never duplicates overlay");

        UIWindow *replacement = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        replacement.rootViewController = [[UIViewController alloc] init];
        [replacement makeKeyAndVisible];
        self.window = replacement;
        StartOllieMenu();
        Check(overlay.superview == replacement, "menu follows replacement key game window");
        puts("MENU_SMOKE_PASSED");
        fflush(stdout);
        exit(0);
    });
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(MenuSmokeDelegate.class));
    }
}
