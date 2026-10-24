// File: OllieAOV.mm
// Language: Objective-C++20 | Target: iOS ARM64 Non-Jailbreak (SideStore)
// Giải pháp:
// 1. Nhúng trực tiếp Mach-O Fishhook (rebind_symbols) khóa chết exit(), _exit(), abort() của dylib BaoNTQ sau 2 giây!
// 2. Chặn -[UIApplication terminateWithSuccess] và suspend để game không bao giờ tự đóng ở màn hình tải tài nguyên.
// 3. Hỗ trợ cả hàm C apiclient_paid() lẫn Objective-C -[APIClient paid:] mà không tự ý giết UIAlertController gây kích hoạt Anti-Tamper.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <dlfcn.h>

// ============================================================================
// 1. TÍCH HỢP TRỰC TIẾP BỘ MÁY MACH-O FISHHOOK (CHẶN LỆNH EXIT/ABORT Ở BẢNG GOT)
// ============================================================================
#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
typedef struct nlist_64 nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
typedef struct nlist nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

#ifndef SEG_DATA_CONST
#define SEG_DATA_CONST "__DATA_CONST"
#endif

struct rebinding {
    const char *name;
    void *replacement;
    void **replaced;
};

static void perform_rebinding_with_section(struct rebinding rebindings[], size_t rebindings_nel, section_t *section, intptr_t slide, nlist_t *symtab, char *strtab, uint32_t *indirect_symtab) {
    uint32_t *indirect_symbol_indices = indirect_symtab + section->reserved1;
    void **indirect_symbol_bindings = (void **)((uintptr_t)slide + section->addr);
    for (size_t i = 0; i < section->size / sizeof(void *); i++) {
        uint32_t symtab_index = indirect_symbol_indices[i];
        if (symtab_index == INDIRECT_SYMBOL_ABS || symtab_index == INDIRECT_SYMBOL_LOCAL || symtab_index == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) {
            continue;
        }
        uint32_t strtab_offset = symtab[symtab_index].n_un.n_strx;
        char *symbol_name = strtab + strtab_offset;
        bool symbol_name_longer_than_1 = symbol_name[0] && symbol_name[1];
        for (size_t j = 0; j < rebindings_nel; j++) {
            if (symbol_name_longer_than_1 && strcmp(&symbol_name[1], rebindings[j].name) == 0) {
                if (rebindings[j].replaced != NULL && indirect_symbol_bindings[i] != rebindings[j].replacement) {
                    *(rebindings[j].replaced) = indirect_symbol_bindings[i];
                }
                indirect_symbol_bindings[i] = rebindings[j].replacement;
                break;
            }
        }
    }
}

static void rebind_symbols_for_image(struct rebinding rebindings[], size_t rebindings_nel, const struct mach_header *header, intptr_t slide) {
    Dl_info info;
    if (dladdr(header, &info) == 0) return;
    // Không can thiệp vào các thư viện hệ thống của Apple (/System/Library hoặc /usr/lib) để tránh xung đột
    if (info.dli_fname && (strncmp(info.dli_fname, "/System/", 8) == 0 || strncmp(info.dli_fname, "/usr/lib/", 9) == 0)) {
        return;
    }

    segment_command_t *cur_seg_cmd;
    segment_command_t *linkedit_segment = NULL;
    struct symtab_command* symtab_cmd = NULL;
    struct dysymtab_command* dysymtab_cmd = NULL;

    uintptr_t cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint32_t i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_LINKEDIT) == 0) {
                linkedit_segment = cur_seg_cmd;
            }
        } else if (cur_seg_cmd->cmd == LC_SYMTAB) {
            symtab_cmd = (struct symtab_command*)cur_seg_cmd;
        } else if (cur_seg_cmd->cmd == LC_DYSYMTAB) {
            dysymtab_cmd = (struct dysymtab_command*)cur_seg_cmd;
        }
    }

    if (!symtab_cmd || !dysymtab_cmd || !linkedit_segment || !dysymtab_cmd->nindirectsyms) return;

    uintptr_t linkedit_base = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
    nlist_t *symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
    char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
    uint32_t *indirect_symtab = (uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);

    cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint32_t i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_DATA) != 0 && strcmp(cur_seg_cmd->segname, SEG_DATA_CONST) != 0) {
                continue;
            }
            for (uint32_t j = 0; j < cur_seg_cmd->nsects; j++) {
                section_t *sect = (section_t *)(cur + sizeof(segment_command_t)) + j;
                if ((sect->flags & SECTION_TYPE) == S_LAZY_SYMBOL_POINTERS || (sect->flags & SECTION_TYPE) == S_NON_LAZY_SYMBOL_POINTERS) {
                    perform_rebinding_with_section(rebindings, rebindings_nel, sect, slide, symtab, strtab, indirect_symtab);
                }
            }
        }
    }
}

// ============================================================================
// 2. CÁC HÀM CHẶN ĐỨNG LỆNH TỰ ĐÓNG SAU 2 GIÂY (EXIT / _EXIT / ABORT / TERMINATE)
// ============================================================================
static void (*orig_exit)(int)   = nullptr;
static void (*orig__exit)(int)  = nullptr;
static void (*orig_abort)(void) = nullptr;

void my_safe_exit(int status) {
    // Khi bộ đếm 2 giây của BaoNTQ gọi exit(0) từ luồng phụ -> Treo riêng luồng kiểm tra đó hoặc bỏ qua!
    if (![NSThread isMainThread]) {
        while (true) { sleep(86400); }
    }
    // Nếu gọi trên Main Thread (do hẹn giờ dispatch_after 2 giây) -> Tuyệt đối KHÔNG thoát, trả quyền điều khiển lại cho RunLoop của game!
    NSLog(@"[OllieShield] Đã chặn đứng lệnh exit(%d) sau 2 giây của BaoNTQ!", status);
}

void my_safe__exit(int status) {
    if (![NSThread isMainThread]) {
        while (true) { sleep(86400); }
    }
    NSLog(@"[OllieShield] Đã chặn đứng lệnh _exit(%d)!", status);
}

void my_safe_abort(void) {
    if (![NSThread isMainThread]) {
        while (true) { sleep(86400); }
    }
    NSLog(@"[OllieShield] Đã chặn đứng lệnh abort()!");
}

static void InstallAntiExitFishhook() {
    struct rebinding binds[] = {
        {"exit",  (void *)my_safe_exit,  (void **)&orig_exit},
        {"_exit", (void *)my_safe__exit, (void **)&orig__exit},
        {"abort", (void *)my_safe_abort, (void **)&orig_abort}
    };
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        rebind_symbols_for_image(binds, 3, _dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i));
    }
}

// Chặn luôn các lệnh đóng ứng dụng bằng Objective-C của UIApplication
@implementation UIApplication (BlockAutoExit)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        NSArray *exitSels = @[@"terminateWithSuccess", @"suspend", @"_terminateWithStatus:"];
        for (NSString *s in exitSels) {
            SEL sel = NSSelectorFromString(s);
            Method m = class_getInstanceMethod(cls, sel);
            if (m) {
                method_setImplementation(m, imp_implementationWithBlock(^(id _self) {
                    NSLog(@"[OllieShield] Đã chặn UIApplication %@", s);
                }));
            }
        }
    });
}
@end

// ============================================================================
// 3. BẺ KHÓA APICLIENT & KÍCH HOẠT MENU GỐC (KHÔNG GIẾT ALERT ĐỂ TRÁNH PHẢN ĐÒN)
// ============================================================================
static bool g_MenuLoaded = false;

static void TriggerOriginalMenuSafe(void (^paidBlock)(void)) {
    if (!paidBlock || g_MenuLoaded) return;
    g_MenuLoaded = true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @try {
            paidBlock();
        } @catch (NSException *e) {}
    });
}

static void Ollie_Hook_Paid(id self, SEL _cmd, void (^paidBlock)(void)) {
    TriggerOriginalMenuSafe(paidBlock);
}

static void Ollie_Hook_PaidErr(id self, SEL _cmd, void (^paidBlock)(void), void (^errBlock)(id)) {
    TriggerOriginalMenuSafe(paidBlock);
}

static id Ollie_Hook_FakeStr(id self, SEL _cmd) {
    return @"2099-12-31 23:59:59";
}

static void ApplyBaoNTQMethodHooks() {
    @try {
        NSArray *clsList = @[@"APIClient", @"BaoNTQClient", @"APIAuthentication", @"KeyAuth"];
        for (NSString *cName in clsList) {
            Class cls = NSClassFromString(cName);
            if (!cls) continue;

            if (Method m = class_getInstanceMethod(cls, NSSelectorFromString(@"paid:")))
                method_setImplementation(m, (IMP)Ollie_Hook_Paid);
            if (Method m = class_getClassMethod(cls, NSSelectorFromString(@"paid:")))
                method_setImplementation(m, (IMP)Ollie_Hook_Paid);
            if (Method m = class_getInstanceMethod(cls, NSSelectorFromString(@"paid:error:")))
                method_setImplementation(m, (IMP)Ollie_Hook_PaidErr);
            if (Method m = class_getInstanceMethod(cls, NSSelectorFromString(@"getExpiredAt")))
                method_setImplementation(m, (IMP)Ollie_Hook_FakeStr);
            if (Method m = class_getInstanceMethod(cls, NSSelectorFromString(@"getKey")))
                method_setImplementation(m, (IMP)Ollie_Hook_FakeStr);
        }
    } @catch (NSException *e) {}
}

__attribute__((constructor))
static void InitImmortalShield() {
    // 1. Khóa chặt exit / _exit / abort ngay khi nạp thư viện
    InstallAntiExitFishhook();

    // 2. Khi ứng dụng khởi chạy xong (trước mốc 2 giây), quét lại bảng GOT một lần nữa cho mọi dylib nạp muộn
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        InstallAntiExitFishhook();
        ApplyBaoNTQMethodHooks();
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        InstallAntiExitFishhook();
        ApplyBaoNTQMethodHooks();
    }];
}
