// ==WindhawkMod==
// @id              arasaka-shutdown-styler
// @name            Arasaka Shutdown Styler (local test)
// @description     Replace shutdown status and shutdown spinner template, without changing shutdown logic.
// @version         0.1.0
// @author          Windows Cyberdeck contributors
// @include         LogonUI.exe
// @architecture    x86-64
// @compilerOptions -luser32 -lole32 -loleaut32 -lruntimeobject
// @license         GPL-3.0-only
// ==/WindhawkMod==
#include <windows.h>
#undef GetCurrentTime
#include <winstring.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.UI.Xaml.h>
#include <winrt/Windows.UI.Xaml.Markup.h>
#include "shutdown-visuals.h"

// Exact ABI entry points found in Microsoft's PDB for this PC's Windows.UI.Logon.
// Do not substitute non-ABI C++/CX methods or adjustor thunks.
constexpr wchar_t statusSymbol[] = L"?__abi_LogonUX___IDisplayMessageViewModelPublicNonVirtuals____abi_get_StatusMessage@?Q__IDisplayMessageViewModelPublicNonVirtuals@LogonUX@@DisplayMessageViewModel@2@UE$AAAJPEAPE$AAVString@Platform@@@Z";
constexpr wchar_t spinnerSymbol[] = L"?__abi_Windows_UI_Xaml_Controls_IDataTemplateSelectorOverrides____abi_SelectTemplateCore@?QIDataTemplateSelectorOverrides@Controls@Xaml@UI@Windows@@ShutdownProgressSpinnerSelector@LogonUX@@UE$AAAJPE$AAVObject@Platform@@PE$AAVDependencyObject@345@PEAPE$AAVDataTemplate@345@@Z";
using StatusFn = HRESULT(WINAPI*)(void*, HSTRING*);
using SpinnerFn = HRESULT(WINAPI*)(void*, void*, void*, void**);
StatusFn originalStatus;
SpinnerFn originalSpinner;
HMODULE logonModule;

HRESULT WINAPI StatusHook(void* self, HSTRING* value) {
    HRESULT hr = originalStatus(self, value);
    if (SUCCEEDED(hr) && value && *value) {
        UINT32 length = 0;
        const wchar_t* buffer = WindowsGetStringRawBuffer(*value, &length);
        if (auto replacement = ArasakaStatus({buffer, length})) {
            HSTRING custom = nullptr;
            if (SUCCEEDED(WindowsCreateString(replacement, (UINT32)wcslen(replacement), &custom))) {
                WindowsDeleteString(*value);
                *value = custom;
            }
        }
    }
    return hr;
}

HRESULT WINAPI SpinnerHook(void* self, void* item, void* container, void** result) {
    HRESULT hr = originalSpinner(self, item, container, result);
    if (FAILED(hr) || !result) return hr;
    try {
        auto replacement = winrt::Windows::UI::Xaml::Markup::XamlReader::Load(
            ArasakaShutdownTemplate).as<winrt::Windows::UI::Xaml::DataTemplate>();
        void* custom = winrt::detach_abi(replacement);
        if (*result) reinterpret_cast<IUnknown*>(*result)->Release();
        *result = custom;
    } catch (...) {
        Wh_Log(L"Custom shutdown template unavailable; using original template");
    }
    return hr;
}

BOOL Wh_ModInit() {
    HMODULE module = logonModule = LoadLibraryExW(L"Windows.UI.Logon.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!module) {
        Wh_Log(L"Windows.UI.Logon is not loaded; leaving system unchanged");
        return FALSE;
    }
    void* status = nullptr;
    void* spinner = nullptr;
    WH_FIND_SYMBOL_OPTIONS options{sizeof(options), nullptr, TRUE};
    WH_FIND_SYMBOL symbol{};
    HANDLE search = Wh_FindFirstSymbol(module, &options, &symbol);
    if (!search) return FALSE;
    do {
        if (!symbol.symbolDecorated) continue;
        if (wcscmp(symbol.symbolDecorated, statusSymbol) == 0) status = symbol.address;
        if (wcscmp(symbol.symbolDecorated, spinnerSymbol) == 0) spinner = symbol.address;
    } while ((!status || !spinner) && Wh_FindNextSymbol(search, &symbol));
    Wh_FindCloseSymbol(search);
    if (!status || !spinner) {
        Wh_Log(L"Exact shutdown ABI symbols missing; leaving system unchanged");
        return FALSE;
    }
    if (!Wh_SetFunctionHook(status, (void*)StatusHook, (void**)&originalStatus) ||
        !Wh_SetFunctionHook(spinner, (void*)SpinnerHook, (void**)&originalSpinner)) return FALSE;
    Wh_Log(L"Shutdown status and template hooks prepared");
    return TRUE;
}

void Wh_ModUninit() {
    if (logonModule) FreeLibrary(logonModule);
    logonModule = nullptr;
}
