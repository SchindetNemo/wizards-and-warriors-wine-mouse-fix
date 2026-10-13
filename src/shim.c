/*
 * Wizards & Warriors (GOG) mouse-click fix for Wine/Proton.
 *
 * deep6.exe only registers a click when GetAsyncKeyState() returns the
 * "pressed since last call" bit (0x0001). Wine never sets that bit, so the
 * game sees the button held but never clicked. This DLL poses as binkw32.dll
 * (forwarding every export to binkw32_orig.dll) and, on load, redirects
 * user32!GetAsyncKeyState to a wrapper that synthesises the bit on the first
 * poll after a key goes down.
 */
typedef unsigned long DWORD;
typedef int BOOL;

__declspec(dllimport) void *__stdcall LoadLibraryA(const char *name);
__declspec(dllimport) void *__stdcall GetProcAddress(void *mod, const char *name);
__declspec(dllimport) BOOL __stdcall VirtualProtect(void *addr, unsigned long size, DWORD prot, DWORD *old);
__declspec(dllimport) BOOL __stdcall FlushInstructionCache(void *proc, const void *addr, unsigned long size);

static short (__stdcall *real_get_async_key_state)(int key);
static unsigned char was_down[256];

static short __stdcall hook_get_async_key_state(int key)
{
    short ret = real_get_async_key_state(key);

    if ((unsigned)key < 256)
    {
        if (ret & 0x8000)
        {
            if (!was_down[key]) ret |= 1;
            was_down[key] = 1;
        }
        else was_down[key] = 0;
    }
    return ret;
}

static void install_hook(void)
{
    unsigned char *target = GetProcAddress(LoadLibraryA("user32.dll"), "GetAsyncKeyState");
    DWORD old;

    real_get_async_key_state = GetProcAddress(LoadLibraryA("win32u.dll"), "NtUserGetAsyncKeyState");
    if (!target || !real_get_async_key_state) return;
    if (!VirtualProtect(target, 5, 0x40 /* PAGE_EXECUTE_READWRITE */, &old)) return;
    target[0] = 0xe9; /* jmp rel32 */
    *(int *)(target + 1) = (int)((unsigned char *)hook_get_async_key_state - (target + 5));
    VirtualProtect(target, 5, old, &old);
    FlushInstructionCache((void *)-1, target, 5);
}

BOOL __stdcall DllMain(void *inst, DWORD reason, void *reserved)
{
    if (reason == 1 /* DLL_PROCESS_ATTACH */) install_hook();
    return 1;
}
