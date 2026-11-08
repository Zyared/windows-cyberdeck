#pragma once
#include <windows.h>

// A UI thread must service sent messages while joining a worker which may
// synchronously call it. Do not dispatch posted input/timers during teardown.
inline DWORD JoinWorkerServicingSentMessages(HANDLE thread) {
    for (;;) {
        DWORD result = MsgWaitForMultipleObjectsEx(
            1, &thread, INFINITE, QS_SENDMESSAGE, MWMO_INPUTAVAILABLE);
        if (result != WAIT_OBJECT_0 + 1) return result;
        MSG message{};
        PeekMessageW(&message, nullptr, 0, 0,
                     PM_NOREMOVE | (QS_SENDMESSAGE << 16));
    }
}
