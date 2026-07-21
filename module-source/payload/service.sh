#!/system/bin/sh
MODDIR="${0%/*}"
PKG="com.google.android.packageinstaller"
LOGDIR="/data/adb/rtwo-installerx-native"
LOG="$LOGDIR/boot.log"
mkdir -p "$LOGDIR"

i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 180 ]; do
  sleep 2
  i=$((i + 1))
done

{
  echo "===== $(date) ====="
  echo "boot_completed=$(getprop sys.boot_completed)"
  echo "pm_path:"
  pm path "$PKG" 2>&1
  echo
  echo "package_flags:"
  dumpsys package "$PKG" 2>/dev/null | grep -E 'codePath=|versionCode=|pkgFlags=|privateFlags=|INSTALL_PACKAGES|DELETE_PACKAGES|MANAGE_USERS' | head -n 80
  echo
  echo "signature_bypass_disabled=$([ -f /data/adb/modules/rtwo_pm_sigbypass/disable ] && echo yes || echo no)"
  echo "thanox_active=$([ -d /data/adb/modules/zygisk_thanox ] && [ ! -f /data/adb/modules/zygisk_thanox/disable ] && echo yes || echo no)"
} >> "$LOG" 2>&1

pm enable --user 0 "$PKG/com.rosan.installer.ui.activity.LauncherAlias" >/dev/null 2>&1 || true
pm grant --user 0 "$PKG" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1 || true
cmd appops set --user 0 "$PKG" REQUEST_INSTALL_PACKAGES allow >/dev/null 2>&1 || true
cmd appops set --user 0 "$PKG" MANAGE_EXTERNAL_STORAGE allow >/dev/null 2>&1 || true
dumpsys deviceidle whitelist +"$PKG" >/dev/null 2>&1 || true

touch "$MODDIR/native-boot-verified"
