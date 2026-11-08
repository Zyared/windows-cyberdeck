# Arasaka Logon Styler — experimental source

This is an appearance-only Windhawk prototype for the real Windows sign-in view. It is **not installed or runtime validated**, and is deliberately excluded from the one-click installer. Ordinary builds refuse activation in `Wh_ModInit`: a compile-time gate protects against accidental use while teardown validation is incomplete. In an explicitly compiled VM research build, the initial setting `enableStyling: false` only logs the number of matching password controls. A successful build does not establish compatibility with Windows LogonUI.

When explicitly enabled in a test VM, it attempts to set three brushes on a XAML `PasswordBox`: almost-black background, red border, and light foreground. It does not move the login field, replace the authentication icon, alter keyboard focus, or change authentication. It does not read `Password`, `Text`, key events, usernames, account details, or credential-provider data. Diagnostic output contains only matched-control counts and operation status.

## Architecture and boundaries

The window class `LogonUI Logon Window`, `Window::Current().Content()` discovery, and credential-view name `RequestCredentialUserControl` come from the published [Lock Screen Live Wallpaper source](https://github.com/ramensoftware/windhawk-mods/blob/main/mods/lock-screen-live-wallpaper.wh.cpp) by **grn15RenS**, version 1.0.0. This prototype uses that discovery approach; it does not include the wallpaper/video feature. This directory is GPL-3.0-only; see LICENSE. No ownership of those upstream contributions is claimed.

Only a typed `PasswordBox` below that exact named view is considered. These names and control types have **not** been discovered in this PC's live sign-in tree. PIN, Windows Hello, third-party credential providers, or native controls may expose entirely different trees. No match means no styling. Template visual states may override the brushes. There is no claim that this changes the screenshot's password field yet.

A thread-specific `WH_CALLWNDPROC` hook handles only this mod's registered message, sent synchronously once per second. All XAML access and ordinary restoration happen on the UI thread. Each traversal has limits of 1,024 visited nodes, depth 40, 1,024 queued nodes, and a 15 ms deadline checked between nodes. A single Windows API call is not preemptible, so 15 ms is not a hard runtime guarantee. At most 64 property records are retained. Existing bindings are skipped. Prior local values are saved; unset values are restored with `ClearValue`. Restoration skips properties subsequently changed by another component. No authentication APIs are hooked.

Unload requests a UI-thread restoration and waits for the worker to finish before removing the hook. A hung LogonUI thread can consequently block unload. If unload runs on the UI thread while the worker synchronously sends to that thread, the join can also deadlock. This is an unresolved release blocker, not merely a cosmetic limitation; there is intentionally no unsafe forced unload while a callback might execute. If the window has already been destroyed, there is no remaining visible UI to restore. Transient template changes, animations, and unknown Windows builds remain untested. Settings changes request a full mod reload.

## Build without installing

Use the bundled x64 Windhawk compiler and matching engine import library:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\experimental\build.ps1
```

Defaults target Windhawk 1.7.3 in `C:\Program Files\Windhawk`; use `-WindhawkRoot` and `-EngineVersion` for another installation. Output is `experimental/build/arasaka-logon-styler.dll`, ignored by Git. This script only compiles and links. It does not register the DLL, change injection settings, inject LogonUI, lock the workstation, or install a mod. The compiler flags follow the [official Windhawk flag builder](https://github.com/ramensoftware/windhawk/blob/main/src/windhawk-core/core/src/services/compiler/flags.rs) and the installed `Compiler/compile_flags.txt`, with actual API linkage rather than `WH_EDITING` stubs.

## Required validation before distribution

First resolve the synchronous-dispatch/unload lifecycle blocker above. Use a disposable Windows VM with a snapshot and an independent recovery route. A developer-only build can be compiled with `-VmResearchOnly` (defines `ARASAKA_VM_RESEARCH=1`); this does not fix the blocker and must not be used on a daily-use machine. Ordinary source imported into Windhawk remains gated. Follow Windhawk documentation for LogonUI exclusions; this repository does not automate enabling injection into it. First verify diagnostic mode finds the intended control without changing sign-in. Only then enable appearance changes and verify password, PIN, Hello fallback, multiple users, accessibility, high contrast, focus/hover/error states, DPI, repeated lock/unlock, settings reload, and disable/unload restoring the prior appearance. Validate the hook and worker teardown under slow/unresponsive UI conditions. Until these checks pass, retain the prototype label and keep it out of the portable installer.

