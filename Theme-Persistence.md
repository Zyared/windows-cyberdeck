# Cursor and pre-sign-in appearance repair — 2026-11-13

The user reported standard cursors after reboot and standard appearance only before
the first sign-in. The existing red clock after Win+L still worked.

## Applied on Zyared's ASUS

- `apply-arasaka-cursors.ps1` now registers the Arasaka scheme and disables theme
  replacement of mouse pointers (`ThemeChangesMousePointers=0`). It validates all
  17 CUR/ANI files through Windows before applying them and preserves backups.
- `Repair-Theme-Session.ps1` restores cursors and the static lock image once,
  15 seconds after sign-in. HKCU Run entry: `CyberDeck Theme Restore`. There is no
  resident polling process. Installed helpers live in `%USERPROFILE%\CyberDeck`.
- `Repair-PreLogon-Appearance.ps1` copies the image and cursors to
  `C:\ProgramData\CyberDeck`, sets `.DEFAULT` cursor paths and machine lock-image
  settings, and backs up every registry value before writing. `-Undo` restores them.
- Wallpaper Engine's `Zyared.general.user.overridelockscreen` was true; Windows
  reported its generated JPEG as the lock image. It is now false; no other JSON
  value changed. Windows now reports `C:\ProgramData\CyberDeck\lockscreen.png`.

Machine lock-image policies are not fully supported on ordinary Windows Pro.
Their readback does **not** prove the initial screen is fixed. No reboot/sign-out
was performed, and the clock before first sign-in remains visually unverified.
The existing Clock Styler was not replaced. Check the initial screen after the
next user-initiated restart; compare it with Win+L.

## Rollback

`Undo-Theme-Persistence.cmd` on the desktop invokes `Undo-Theme-Persistence.ps1`.
It removes today's Run entry, restores cursor scheme metadata and machine values,
and restores only the previous Wallpaper Engine lockscreen override preference.
It briefly restarts Wallpaper Engine if it is running. It does not change EFI,
BCD, the working boot animation, or trigger a restart. Machine rollback needs UAC.
The rollback code was inspected and syntax-checked; a full live rollback was not
performed during the unattended run. The original registry snapshots are retained.

The full `restore.ps1` also removes persistence and restores backed-up cursor roles.
The older all-in-one installer does not automatically install this machine-specific
repair; the four helper scripts must be deployed with the corresponding assets.

## Storage archive

`Archive-Theme-Research.ps1` is the reviewed, one-time plan for this PC. It copies
reproducible boot-lab artifacts and selected downloadable installers to
`E:\Archives\Arasaka-2026-11-13`, checks every file's length and SHA256, writes a
manifest on C and E, and only then removes each original. It refuses reparse points,
running lab VMs, active application roots and destinations outside E:\Archives.

E: has a damaged NTFS directory index in `\ПЕРЕДАЧА_Проект_АНАЛОГ` (file reference
0x3A813). Read-only CHKDSK and online `/scan` found it; `/f` could not obtain the
volume lock. Forced dismount was refused. Online scan queued offline repair;
the volume still reports Warning / Full Repair Needed. This is **not repaired**,
and does not establish whether the USB cable or physical disk is healthy.

Unique phone backups, original recovery data, installed CyberDeck, live applications
and boot rollback stay on C/D. No `/x`, offline repair or reboot was performed.
Local transfer manifest: `%USERPROFILE%\CyberDeck\backup\archive-20261113\manifest.json`.
The archive README/result records bytes actually moved, not the proposed total.
