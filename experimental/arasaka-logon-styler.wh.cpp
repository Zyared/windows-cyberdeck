// ==WindhawkMod==
// @id              arasaka-logon-styler
// @name            Arasaka Logon Styler (experimental)
// @description     Diagnostic-first, appearance-only PasswordBox prototype. Not runtime validated.
// @version         0.1.1
// @author          Windows Cyberdeck contributors
// @include         LogonUI.exe
// @architecture    x86-64
// @compilerOptions -luser32 -lole32 -loleaut32 -lruntimeobject
// @license         GPL-3.0-only
// ==/WindhawkMod==

// ==WindhawkModReadme==
/*
Experimental source, not a supported login-screen customization.
Default mode only reports matched-control counts. No credential values are read.
See experimental/README.md before testing in a disposable VM.
UI-window discovery and XAML-root approach derived from grn15RenS's
lock-screen-live-wallpaper (GPL-3.0), ramensoftware/windhawk-mods.
*/
// ==/WindhawkModReadme==

// ==WindhawkModSettings==
/*
- enableStyling: false
  $name: Enable experimental appearance changes (VM testing only)
*/
// ==/WindhawkModSettings==

#include <windows.h>
#include "ui-thread-join.h"
#ifndef ARASAKA_VM_RESEARCH
#define ARASAKA_VM_RESEARCH 0
#endif
#undef GetCurrentTime
#include <atomic>
#include <vector>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.UI.h>
#include <winrt/Windows.UI.Xaml.h>
#include <winrt/Windows.UI.Xaml.Controls.h>
#include <winrt/Windows.UI.Xaml.Data.h>
#include <winrt/Windows.UI.Xaml.Media.h>

using namespace winrt;
using namespace Windows::UI;
using namespace Windows::UI::Xaml;
using namespace Windows::UI::Xaml::Controls;
using namespace Windows::UI::Xaml::Media;

namespace {
HANDLE stopEvent = nullptr, worker = nullptr;
HWND target = nullptr;
HHOOK hook = nullptr;
UINT privateMessage = 0;
bool styling = false;
std::atomic<bool> stopping{false};
int lastMatches = -1;
struct Saved {
    weak_ref<DependencyObject> object;
    DependencyProperty property;
    Windows::Foundation::IInspectable original;
    Windows::Foundation::IInspectable applied;
};
std::vector<Saved> saved;

void Restore() {
    for (auto it = saved.rbegin(); it != saved.rend(); ++it) {
        try {
            if (auto object = it->object.get()) {
                // Preserve subsequent changes from Windows or another mod.
                if (object.ReadLocalValue(it->property) != it->applied) continue;
                if (it->original == DependencyProperty::UnsetValue())
                    object.ClearValue(it->property);
                else object.SetValue(it->property, it->original);
            }
        } catch (...) { Wh_Log(L"Appearance restore failed for one property"); }
    }
    saved.clear();
}

void SetAppearance(PasswordBox const& box, DependencyProperty const& property,
                   Windows::Foundation::IInspectable const& value) {
    for (auto const& item : saved)
        if (item.object.get() == box && item.property == property) return;
    if (saved.size() >= 64) return;
    // Do not replace a binding: restoring an expression via SetValue is unsafe.
    if (box.GetBindingExpression(property)) return;
    auto old = box.ReadLocalValue(property);
    saved.push_back({make_weak(box.as<DependencyObject>()), property, old, value});
    box.SetValue(property, value);
    saved.back().applied = box.ReadLocalValue(property);
}

void Scan() {
    if (stopping.load()) return;
    auto window = Window::Current();
    if (!window || !window.Content()) return;
    struct Entry { DependencyObject node; unsigned depth; bool credentialView; };
    std::vector<Entry> pending{{window.Content(), 0, false}};
    unsigned visited = 0;
    int matches = 0;
    auto deadline = GetTickCount64() + 15;
    while (!stopping.load() && !pending.empty() && visited++ < 1024 && GetTickCount64() < deadline) {
        auto entry = std::move(pending.back()); pending.pop_back();
        if (auto element = entry.node.try_as<FrameworkElement>()) {
            if (element.Name() == L"RequestCredentialUserControl") entry.credentialView = true;
        }
        if (entry.credentialView) {
            if (auto box = entry.node.try_as<PasswordBox>()) {
                ++matches;
                if (styling) {
                    SetAppearance(box, Control::BackgroundProperty(), SolidColorBrush(Color{255,8,9,12}));
                    SetAppearance(box, Control::BorderBrushProperty(), SolidColorBrush(Color{255,237,36,56}));
                    SetAppearance(box, Control::ForegroundProperty(), SolidColorBrush(Color{255,219,219,224}));
                }
            }
        }
        if (entry.depth >= 40) continue;
        auto count = VisualTreeHelper::GetChildrenCount(entry.node);
        for (int i = 0; i < count && pending.size() < 1024; ++i)
            pending.push_back({VisualTreeHelper::GetChild(entry.node, i), entry.depth + 1, entry.credentialView});
    }
    if (matches != lastMatches) {
        Wh_Log(L"Credential-view PasswordBox count=%d; styling=%d; scanComplete=%d", matches, styling, pending.empty());
        lastMatches = matches;
    }
}

LRESULT CALLBACK MessageHook(int code, WPARAM wp, LPARAM lp) {
    if (code >= 0) {
        auto message = reinterpret_cast<CWPSTRUCT const*>(lp);
        if (message->hwnd == target && message->message == privateMessage) {
            try { if (message->wParam == 1) Restore(); else Scan(); }
            catch (...) { Wh_Log(L"XAML unavailable or appearance operation failed"); }
        }
    }
    return CallNextHookEx(nullptr, code, wp, lp);
}

BOOL CALLBACK FindWindow(HWND hwnd, LPARAM) {
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid != GetCurrentProcessId()) return TRUE;
    wchar_t name[128]{};
    GetClassNameW(hwnd, name, ARRAYSIZE(name));
    if (wcscmp(name, L"LogonUI Logon Window") != 0) return TRUE;
    target = hwnd;
    return FALSE;
}

DWORD WINAPI Worker(void*) {
    // Discovery ends after 30 seconds. No injection or desktop switching here.
    for (unsigned i = 0; i < 150; ++i) {
        if (WaitForSingleObject(stopEvent, 0) == WAIT_OBJECT_0) return 0;
        EnumWindows(FindWindow, 0);
        if (target || WaitForSingleObject(stopEvent, 200) == WAIT_OBJECT_0) break;
    }
    if (WaitForSingleObject(stopEvent, 0) == WAIT_OBJECT_0) return 0;
    if (!target) { Wh_Log(L"LogonUI window not found"); return 0; }
    hook = SetWindowsHookExW(WH_CALLWNDPROC, MessageHook, nullptr, GetWindowThreadProcessId(target, nullptr));
    if (!hook) { Wh_Log(L"UI-thread hook unavailable"); return 0; }
    while (WaitForSingleObject(stopEvent, 1000) == WAIT_TIMEOUT && IsWindow(target)) {
        // Synchronous dispatch prevents outstanding callbacks at unload.
        SendMessageW(target, privateMessage, 0, 0);
    }
    if (IsWindow(target)) SendMessageW(target, privateMessage, 1, 0);
    UnhookWindowsHookEx(hook);
    hook = nullptr;
    return 0;
}
}

BOOL Wh_ModInit() {
    // The join cycle has a native regression test. Real LogonUI teardown and
    // XAML lifetime still require validation before ordinary builds activate.
    if (!ARASAKA_VM_RESEARCH) {
        Wh_Log(L"Prototype inactive: UI teardown validation is incomplete");
        return FALSE;
    }
    styling = Wh_GetIntSetting(L"enableStyling") != 0;
    stopping.store(false);
    privateMessage = RegisterWindowMessageW(L"WindowsCyberdeck.ArasakaLogonStyler.0.1");
    stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!privateMessage || !stopEvent) {
        if (stopEvent) CloseHandle(stopEvent);
        stopEvent = nullptr;
        return FALSE;
    }
    worker = CreateThread(nullptr, 0, Worker, nullptr, 0, nullptr);
    if (!worker) { CloseHandle(stopEvent); stopEvent = nullptr; return FALSE; }
    return TRUE;
}

void Wh_ModBeforeUninit() {
    stopping.store(true);
    if (stopEvent) SetEvent(stopEvent);
    // Keep servicing sent UI calls until restoration and unhook have finished.
    // A timeout/forced unload would leave a callback in unloaded code.
    if (worker) {
        while (JoinWorkerServicingSentMessages(worker) != WAIT_OBJECT_0) {
            Wh_Log(L"Worker join failed (%lu); retaining module until worker exits", GetLastError());
            Sleep(10);
        }
    }
}

void Wh_ModUninit() {
    if (worker) CloseHandle(worker);
    if (stopEvent) CloseHandle(stopEvent);
    worker = nullptr;
    stopEvent = nullptr;
    saved.clear();
}

void Wh_ModSettingsChanged(BOOL* reload) { *reload = TRUE; }
