# Arasaka Logon Styler — experimental source

This is an appearance-only Windhawk prototype for the real Windows sign-in view. It is **not installed or runtime validated**, and is deliberately excluded from the one-click installer. Ordinary builds refuse activation in `Wh_ModInit`: a compile-time gate protects against accidental use while teardown validation is incomplete. In an explicitly compiled VM research build, the initial setting `enableStyling: false` only logs the number of matching password controls. A successful build does not establish compatibility with Windows LogonUI.

When explicitly enabled in a test VM, it attempts to set three brushes on a XAML `PasswordBox`: almost-black background, red border, and light foreground. It does not move the login field, replace the authentication icon, alter keyboard focus, or change authentication. It does not read `Password`, `Text`, key events, usernames, account details, or credential-provider data. Diagnostic output contains only matched-control counts and operation status.

## Architecture and boundaries

The window class `LogonUI Logon Window`, `Window::Current().Content()` discovery, and credential-view name `RequestCredentialUserControl` come from the published [Lock Screen Live Wallpaper source](https://github.com/ramensoftware/windhawk-mods/blob/main/mods/lock-screen-live-wallpaper.wh.cpp) by **grn15RenS**, version 1.0.0. This prototype uses that discovery approach; it does not include the wallpaper/video feature. This directory is GPL-3.0-only; see LICENSE. No ownership of those upstream contributions is claimed.

Only a typed `PasswordBox` below that exact named view is considered. These names and control types have **not** been discovered in this PC's live sign-in tree. PIN, Windows Hello, third-party credential providers, or native controls may expose entirely different trees. No match means no styling. Template visual states may override the brushes. There is no claim that this changes the screenshot's password field yet.

A thread-specific `WH_CALLWNDPROC` hook handles only this mod's registered message, sent synchronously once per second. All XAML access and ordinary restoration happen on the UI thread. Each traversal has limits of 1,024 visited nodes, depth 40, 1,024 queued nodes, and a 15 ms deadline checked between nodes. A single Windows API call is not preemptible, so 15 ms is not a hard runtime guarantee. At most 64 property records are retained. Existing bindings are skipped. Prior local values are saved; unset values are restored with `ClearValue`. Restoration skips properties subsequently changed by another component. No authentication APIs are hooked.

Unload signals cancellation, then joins the worker with MsgWaitForMultipleObjectsEx and PeekMessage restricted to QS_SENDMESSAGE. This services synchronous UI calls even when unload runs on the receiving UI thread, breaking the former worker/UI join cycle. Posted input and timers are not dispatched by this join. The worker restores properties and removes its hook before exiting. A genuinely unresponsive UI thread or a stuck XAML API can still block completion; there is intentionally no timeout followed by unsafe forced unload. Reentrant unload from inside an active styling callback and live LogonUI hook teardown have not been validated. If the window has already been destroyed, there is no remaining visible UI to restore. Transient template changes, animations, and unknown Windows builds remain untested. Settings changes request a full mod reload.

## Build without installing

Use the bundled x64 Windhawk compiler and matching engine import library:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\experimental\build.ps1
```

Defaults target Windhawk 1.7.3 in `C:\Program Files\Windhawk`; use `-WindhawkRoot` and `-EngineVersion` for another installation. Output is `experimental/build/arasaka-logon-styler.dll`, ignored by Git. This script only compiles and links. It does not register the DLL, change injection settings, inject LogonUI, lock the workstation, or install a mod. The compiler flags follow the [official Windhawk flag builder](https://github.com/ramensoftware/windhawk/blob/main/src/windhawk-core/core/src/services/compiler/flags.rs) and the installed `Compiler/compile_flags.txt`, with actual API linkage rather than `WH_EDITING` stubs.

## Required validation before distribution

The former synchronous-dispatch/UI-join cycle is covered by a native regression test without using LogonUI. Full integration validation is still required; use an isolated Windows test environment with an independent recovery route. A developer-only build can be compiled with `-VmResearchOnly` (defines `ARASAKA_VM_RESEARCH=1`); this bypasses the integration-validation gate and is not a claim of production readiness. Ordinary source imported into Windhawk remains gated. Follow Windhawk documentation for LogonUI exclusions; this repository does not automate enabling injection into it. First verify diagnostic mode finds the intended control without changing sign-in. Only then enable appearance changes and verify password, PIN, Hello fallback, multiple users, accessibility, high contrast, focus/hover/error states, DPI, repeated lock/unlock, settings reload, and disable/unload restoring the prior appearance. Validate the hook and worker teardown under slow/unresponsive UI conditions. Until these checks pass, retain the prototype label and keep it out of the portable installer.


## Native join regression (0.1.1)

`test-ui-thread-join.cpp` includes the same `ui-thread-join.h` used by the mod.
It uses a message-only window in its own process, never LogonUI. It confirms the
old non-pumping wait times out with the sender blocked, then exercises 100 joins,
a delayed handler, two sequential sends (scan/restoration), preservation of posted
messages, and joining a worker after the window is destroyed. A 15-second watchdog
terminates only the test process on a regression. This tests the join primitive,
not XAML property restoration or actual Windhawk DLL unload.

```powershell
& 'C:\Program Files\Windhawk\Compiler\bin\clang++.exe' -std=c++23 -O2 -target x86_64-w64-mingw32 .\experimental\test-ui-thread-join.cpp -luser32 -o .\experimental\build\test-ui-thread-join.exe
& .\experimental\build\test-ui-thread-join.exe
```

Run `build.ps1` first to create the build directory. Keep the adjacent header with
the source when compiling; importing the single cpp into an editor is insufficient.
The join follows the Windows requirement to service messages on window-owning
threads: [Microsoft documentation](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-msgwaitformultipleobjectsex).
## Explicit local test on 2026-11-08

At the user's explicit request, version 0.1.1 was compiled with the research gate
open and registered on the current PC with enableStyling=1. This is a local trial,
not completion of the integration validation above. `enable-local-test.ps1` is an
administrator-only helper for this trial and remains outside the main installer.
It expects an already built research DLL, registers the exact LogonUI target and
adds only `%systemroot%\system32\logonui.exe` to the engine inclusion list. Global
critical-process injection remains disabled. It does not lock or reboot Windows.
`-Disable` disables this mod and removes that explicit engine inclusion, retaining
other inclusion entries. A copy is installed under CyberDeck/experimental for the
desktop Disable-Arasaka-Logon.cmd recovery shortcut. No visual success is claimed
until the user tests the actual sign-in view. Shutdown text and boot animation
are not implemented by this PasswordBox prototype.