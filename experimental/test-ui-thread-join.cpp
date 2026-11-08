#include "ui-thread-join.h"
#include <cstdio>
#include <atomic>

constexpr UINT workMessage = WM_APP + 1;
std::atomic<int> calls{0};
HWND window;
HANDLE started;
DWORD delay;
LRESULT CALLBACK WindowProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == workMessage) {
        if (delay) Sleep(delay);
        ++calls;
        return 1;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}
DWORD WINAPI Sender(void*) {
    SetEvent(started);
    SendMessageW(window, workMessage, 0, 0);
    SendMessageW(window, workMessage, 1, 0); // restoration
    return 0;
}
DWORD WINAPI IdleWorker(void*) { Sleep(10); return 0; }
DWORD WINAPI Watchdog(void* done) {
    if (WaitForSingleObject(done, 15000) != WAIT_OBJECT_0)
        TerminateProcess(GetCurrentProcess(), 99);
    return 0;
}
int main() {
    HANDLE done = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    HANDLE watchdog = CreateThread(nullptr, 0, Watchdog, done, 0, nullptr);
    WNDCLASSW cls{};
    cls.lpfnWndProc = WindowProc;
    cls.hInstance = GetModuleHandleW(nullptr);
    cls.lpszClassName = L"ArasakaJoinRegression";
    if (!RegisterClassW(&cls)) return 1;
    window = CreateWindowW(cls.lpszClassName, L"", 0, 0, 0, 0, 0,
                           HWND_MESSAGE, nullptr, cls.hInstance, nullptr);
    if (!window) return 2;
    started = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    for (int i = 0; i < 100; ++i) {
        ResetEvent(started);
        calls = 0;
        delay = i == 0 ? 75 : 0;
        HANDLE sender = CreateThread(nullptr, 0, Sender, nullptr, 0, nullptr);
        WaitForSingleObject(started, INFINITE);
        if (i == 0 && WaitForSingleObject(sender, 100) != WAIT_TIMEOUT) return 3;
        // A queued posted message must survive the join untouched.
        PostMessageW(window, WM_APP + 2, 123, 0);
        if (JoinWorkerServicingSentMessages(sender) != WAIT_OBJECT_0 || calls != 2) return 4;
        MSG queued{};
        if (!PeekMessageW(&queued, window, WM_APP + 2, WM_APP + 2, PM_REMOVE)
            || queued.wParam != 123) return 5;
        CloseHandle(sender);
    }
    DestroyWindow(window);
    HANDLE idle = CreateThread(nullptr, 0, IdleWorker, nullptr, 0, nullptr);
    if (JoinWorkerServicingSentMessages(idle) != WAIT_OBJECT_0) return 6;
    CloseHandle(idle);
    CloseHandle(started);
    SetEvent(done);
    WaitForSingleObject(watchdog, INFINITE);
    CloseHandle(watchdog);
    CloseHandle(done);
    puts("PASS: old wait blocks; 100 UI joins complete; slow handler completes; posted messages preserved; idle worker joins.");
}
