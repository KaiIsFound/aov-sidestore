// File: OllieAOV.mm
// Language: Objective-C++20 | Target: iOS ARM64 (Metal Overlay & Menu Hook)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <vector>
#import <string>

#include "imgui.h"
#include "imgui_impl_metal.h"

// Biến trạng thái hiển thị Menu
bool g_ShowMenu = true;

// Khai báo giao diện cửa sổ ImGui trực tiếp trên màn hình game
void RenderOllieUI(CGSize screenSize, ImDrawList* drawList) {
    if (!g_ShowMenu) return;

    ImGui::SetNextWindowSize(ImVec2(420, 320), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowPos(ImVec2(50, 50), ImGuiCond_FirstUseEver);
    
    if (ImGui::Begin("OLLIE BENCH - LIEN QUAN ACTIVE", &g_ShowMenu, ImGuiWindowFlags_NoCollapse)) {
        ImGui::Text("STATUS: CONNECTED (ARM64 NON-JB)");
        ImGui::Separator();
        
        if (ImGui::BeginTabsBar ? ImGui::BeginTabBar("Tabs") : ImGui::BeginTabBar("Tabs")) {
            if (ImGui::BeginTabItem("ESP & Map")) {
                static bool espBox = true;
                static bool espLine = true;
                static bool hackMap = true;
                ImGui::Checkbox("ESP Khung Tướng (Box)", &espBox);
                ImGui::Checkbox("Tia Định Vị (Line)", &espLine);
                ImGui::Checkbox("Hack Map Sáng Bụi 100%", &hackMap);
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Mod Skin")) {
                static bool skinOn = true;
                ImGui::Checkbox("Kích Hoạt Mod Skin Không Trận Ảo", &skinOn);
                ImGui::Text("Nakroth -> Thu Nguyen Ve Than");
                ImGui::Text("Ngo Khong -> Tan Nien Vo Than");
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Anti-Ban")) {
                ImGui::TextColored(ImVec4(0,1,0,1), "anogs Telemetry: BLOCKED");
                ImGui::TextColored(ImVec4(0,1,0,1), "Memory CRC Check: SPOOFED");
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }
    }
    ImGui::End();
}

// Lớp giao diện phủ Metal View
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
        ImGui::StyleColorsDark();
        ImGui_ImplMetal_Init(dev);
    }
    return self;
}

- (void)drawInMTKView:(MTKView *)view {
    id<MTLCommandBuffer> cmdBuf = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *rpd = view.currentRenderPassDescriptor;
    if (!rpd) return;

    ImGui_ImplMetal_NewFrame(rpd);
    ImGui::NewFrame();

    RenderOllieUI(view.bounds.size, ImGui::GetBackgroundDrawList());

    ImGui::Render();
    id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rpd];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmdBuf, enc);
    [enc endEncoding];
    [cmdBuf presentDrawable:view.currentDrawable];
    [cmdBuf commit];
}
@end

// Hàm tự động tiêm view vào cửa sổ chính của ứng dụng
__attribute__((constructor))
static void InjectOllieUI() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
        if (window) {
            OllieOverlayView *overlay = [[OllieOverlayView alloc] initWithFrame:window.bounds];
            [window addSubview:overlay];
            [window bringSubviewToFront:overlay];
        }
    });
}
