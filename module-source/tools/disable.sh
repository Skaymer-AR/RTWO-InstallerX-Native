#!/sbin/sh

MODULE_ID="rtwo_installerx_native"
MODDIR="/data/adb/modules/$MODULE_ID"
PACKAGE="com.google.android.packageinstaller"
OLD_PACKAGE="com.rosan.installer.x.revived"
EXPECTED_STOCK_SHA="c826d4f46f6180897b9246960fbbbe0b8b0a9c05259f51bbfab9e0645aca9a3f"
EXPECTED_PAYLOAD_SHA="dbae3bc57ecb130b282fed16799d46b2342db46980caab15457ac0338d32fa07"

ui_print() {
  echo "ui_print $*" > "/proc/self/fd/$OUTFD" 2>/dev/null || true
  echo "ui_print" > "/proc/self/fd/$OUTFD" 2>/dev/null || true
}

mounted() {
  grep -qE "[[:space:]]$1[[:space:]]" /proc/mounts 2>/dev/null
}

try_mount() {
  MP="$1"
  [ -d "$MP" ] || return 1
  mounted "$MP" && return 0
  mount "$MP" >/dev/null 2>&1 && return 0
  if [ -x /sbin/twrp ]; then
    /sbin/twrp mount "$MP" >/dev/null 2>&1 && return 0
    /sbin/twrp mount "${MP#/}" >/dev/null 2>&1 && return 0
  fi
  return 1
}

hash_file() {
  F="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$F" 2>/dev/null | awk '{print $1}'
  elif [ -x /tmp/busybox ]; then
    /tmp/busybox sha256sum "$F" 2>/dev/null | awk '{print $1}'
  else
    return 1
  fi
}

find_stock_apk() {
  for P in /system_root/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk /system/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk /system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk /mnt/system/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk
  do
    [ -f "$P" ] && { echo "$P"; return 0; }
  done
  return 1
}

context_of() {
  ls -Zd "$1" 2>/dev/null | grep -o 'u:object_r:[^ ]*:s0' | head -n 1
}

apply_system_context() {
  TARGET="$1"
  for C in chcon /sbin/chcon /system/bin/chcon /system_root/system/bin/chcon; do
    if [ "$C" = "chcon" ]; then
      command -v chcon >/dev/null 2>&1 || continue
      chcon -R u:object_r:system_file:s0 "$TARGET" >/dev/null 2>&1 && return 0
    elif [ -x "$C" ]; then
      "$C" -R u:object_r:system_file:s0 "$TARGET" >/dev/null 2>&1 && return 0
    fi
  done
  for T in /sbin/toybox /system/bin/toybox /system_root/system/bin/toybox; do
    [ -x "$T" ] || continue
    "$T" chcon -R u:object_r:system_file:s0 "$TARGET" >/dev/null 2>&1 && return 0
  done
  return 1
}

verify_contexts() {
  BASE="$1"
  for P in "$BASE" "$BASE/system" "$BASE/system/priv-app" "$BASE/system/priv-app/GooglePackageInstaller" "$BASE/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk" "$BASE/system/etc" "$BASE/system/etc/permissions" "$BASE/system/etc/permissions/privapp-permissions-installerx-native.xml"
  do
    [ -e "$P" ] || return 1
    [ "$(context_of "$P")" = "u:object_r:system_file:s0" ] || return 1
  done
  return 0
}

dependency_checks() {
  [ -d /data/adb/modules/rtwo_pm_sigbypass ] || { ui_print "[ERROR] RTWO signature bypass v1.2 is not installed."; return 1; }
  [ ! -f /data/adb/modules/rtwo_pm_sigbypass/disable ] || { ui_print "[ERROR] Signature bypass is disabled."; ui_print "Enable it before enabling native InstallerX."; return 1; }
  [ -d /data/adb/modules/hybrid_mount ] || { ui_print "[ERROR] Hybrid Mount is not installed."; return 1; }
  [ ! -f /data/adb/modules/hybrid_mount/disable ] || { ui_print "[ERROR] Hybrid Mount is disabled."; return 1; }
  if [ -d /data/adb/modules/zygisk_thanox ] && [ ! -f /data/adb/modules/zygisk_thanox/disable ]; then
    ui_print "[ERROR] Thanox Zygisk is active."
    ui_print "Disable it first; it conflicts with the patched system_server."
    return 1
  fi
  return 0
}

old_installerx_present() {
  grep -q "^$OLD_PACKAGE " /data/system/packages.list 2>/dev/null
}

clear_installer_art_cache() {
  LOG="$1"
  : > "$LOG"
  for BASE in /data/dalvik-cache /data/misc/apexdata/com.android.art/dalvik-cache; do
    [ -d "$BASE" ] || continue
    find "$BASE" -type f \( -iname '*GooglePackageInstaller*' -o -iname '*com.google.android.packageinstaller*' \) 2>/dev/null | while IFS= read -r F; do
      echo "$F" >> "$LOG"
      rm -f "$F" 2>/dev/null || true
    done
  done
}

ui_print ""
ui_print "RTWO InstallerX Native v1.1 - DISABLE"
ui_print "-------------------------------------"

try_mount /data || true
[ -d /data/adb ] || { ui_print "[ERROR] /data is not mounted or decrypted."; exit 1; }

if [ -d "$MODDIR" ]; then
  rm -f "$MODDIR/remove" "$MODDIR/update"
  touch "$MODDIR/disable" || { ui_print "[ERROR] Cannot create disable marker."; exit 1; }
  chmod 0644 "$MODDIR/disable" 2>/dev/null || true
  apply_system_context "$MODDIR" >/dev/null 2>&1 || true

  STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
  case "$STAMP" in 19*|20*) ;; *) STAMP="recovery-$(date +%s 2>/dev/null)" ;; esac
  LOGDIR="/data/media/0/RTWO-INSTALLERX-NATIVE-LOGS"
  mkdir -p "$LOGDIR"
  clear_installer_art_cache "$LOGDIR/art-cache-removed-disable-$STAMP.txt"
  sync

  ui_print "[OK] Native InstallerX disabled."
  ui_print "The stock Google Package Installer will return next boot."
else
  ui_print "[OK] Native InstallerX module is not installed."
fi
exit 0
