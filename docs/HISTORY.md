# Project history

## v1.0

- InstallerX adapted to `com.google.android.packageinstaller`.
- Systemless privileged-app overlay.
- PREPARE / ENABLE / DISABLE / REMOVE split.
- Correct SELinux labeling.
- On-device result initially remained the stock installer because the app
  directory was merged.

## v1.1

- Added and verified `GooglePackageInstaller/.replace`.
- Mounted APK hash changed to the InstallerX payload hash.
- InstallerX confirmed working as native installer and uninstaller.
- Installation, uninstallation and application authorization tested.
