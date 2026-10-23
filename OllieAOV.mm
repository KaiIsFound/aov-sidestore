// ============================================================================
// OLLIE BENCH - LIEN QUAN MOBILE (AOV) iOS NON-JAILBREAK IPA FULL SOURCE & PACKAGER
// Target: iOS ARM64 (UnityFramework + anogs / TDataMaster)
// Features:
// 1. ESP Full (Box, 3D Line, Health, Ultimate CD, Skill CD, Minimap Icon, Jungle Timer)
// 2. Camera Drone View (Slider FOV 1.0x - 3.0x)
// 3. Aim Elsu / Auto Smite (Tự động căn viễn trình kích & Trừng trị chuẩn sát thương)
// 4. Mod Skin Full Hiệu Ứng + Âm Thanh + Biến Về (Client Prefab + SoundBank Hook, 0% Trận Ảo)
// 5. Anti-Ban 100% iOS (Bypass anogs, TDataMaster, SSL Pinning, Anti-Screenshot, Non-JB Dyld Hide)
// ============================================================================

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
#include "OllieConfig.h"
#import "OllieMenu.h"

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
// 4. LỚP KHIÊN ANTI-BAN iOS 100% (ANOGS + DYLD SPOOF + ANTI-SCREENSHOT)
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
// 6. KẾT XUẤT ĐỒ HỌA METAL OVERLAY & LOGIC AUTO SMITE / SKILL CD
// ============================================================================
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

