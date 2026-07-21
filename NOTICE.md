# Notices and attribution

## InstallerX Revived

The native installer APK is based on **InstallerX Revived**, developed by
`wxxsfxyzm`, `iamr0s`, and contributors.

- Upstream repository: `wxxsfxyzm/InstallerX-Revived`
- Pinned source commit: `5a63a9465129f547031fa8d1d7f3a945beeb732b`
- Upstream license: GNU General Public License v3.0
- Local modification: the application ID is built as
  `com.google.android.packageinstaller` so it can replace the stock installer
  systemlessly on the tested RTWO firmware.

The upstream Android namespace remains `com.rosan.installer`; this is why the
registered activity classes keep their original names.

## Android and Motorola framework files

This repository does **not** publish Motorola's stock or patched `services.jar`.
Those files are extracted and rebuilt locally from the owner's device.

## Project authorship

Integration, recovery tooling, testing and documentation:
- Skaymer-AR
- Developed and validated on a Motorola Edge 40 Pro (`rtwo`) running Android 16.
