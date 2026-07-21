# Installation

## Prerequisites

- RTWO on the exact tested Android 16 build.
- TWRP with decrypted `/data`.
- KernelSU Next and Hybrid Mount.
- RTWO PackageManager Signature Bypass v1.2 enabled.
- Thanox Zygisk disabled.
- Normal InstallerX package removed.

## Procedure

1. Copy PREPARE, ENABLE and DISABLE to external storage.
2. Flash PREPARE.
3. Confirm the module is prepared and remains disabled.
4. Flash ENABLE.
5. Reboot.
6. Verify the mounted APK hash and PackageManager version.

```bash
adb shell sha256sum /system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk
adb shell dumpsys package com.google.android.packageinstaller | grep -E 'versionCode=|codePath='
```

Expected InstallerX APK hash:

```text
dbae3bc57ecb130b282fed16799d46b2342db46980caab15457ac0338d32fa07
```

Expected version code:

```text
1422
```
