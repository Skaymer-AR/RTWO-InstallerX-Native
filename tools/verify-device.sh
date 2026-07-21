#!/usr/bin/env bash
set -euo pipefail

ADB="${ADB:-adb}"
EXPECTED="dbae3bc57ecb130b282fed16799d46b2342db46980caab15457ac0338d32fa07"
PATH_ON_DEVICE="/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk"

echo "== Mounted APK hash =="
"$ADB" shell sha256sum "$PATH_ON_DEVICE"

echo
echo "== Package state =="
"$ADB" shell dumpsys package com.google.android.packageinstaller |
  grep -E 'codePath=|versionCode=|enabled=' | head -n 30

echo
echo "Expected native APK SHA-256:"
echo "$EXPECTED"
