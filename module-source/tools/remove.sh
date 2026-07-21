#!/sbin/sh

MODULE_ID="rtwo_installerx_native"
MODDIR="/data/adb/modules/$MODULE_ID"

ui_print() {
  echo "ui_print $*" > "/proc/self/fd/$OUTFD" 2>/dev/null || true
  echo "ui_print" > "/proc/self/fd/$OUTFD" 2>/dev/null || true
}

try_mount() {
  MP="$1"
  [ -d "$MP" ] || return 1
  grep -qE "[[:space:]]$MP[[:space:]]" /proc/mounts 2>/dev/null && return 0
  mount "$MP" >/dev/null 2>&1 && return 0
  if [ -x /sbin/twrp ]; then
    /sbin/twrp mount "$MP" >/dev/null 2>&1 && return 0
    /sbin/twrp mount "${MP#/}" >/dev/null 2>&1 && return 0
  fi
  return 1
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
ui_print "RTWO InstallerX Native v1.1 - REMOVE"
ui_print "------------------------------------"

try_mount /data || true
[ -d /data/adb ] || { ui_print "[ERROR] /data is not mounted or decrypted."; exit 1; }

if [ -d "$MODDIR" ]; then
  STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
  case "$STAMP" in 19*|20*) ;; *) STAMP="recovery-$(date +%s 2>/dev/null)" ;; esac
  QUAR="/data/media/0/RTWO-INSTALLERX-NATIVE-REMOVED/$STAMP"
  mkdir -p "$QUAR"
  cp -a "$MODDIR/." "$QUAR/" 2>/dev/null || true
  rm -rf "$MODDIR" || { ui_print "[ERROR] Cannot remove module directory."; exit 1; }

  LOGDIR="/data/media/0/RTWO-INSTALLERX-NATIVE-LOGS"
  mkdir -p "$LOGDIR"
  clear_installer_art_cache "$LOGDIR/art-cache-removed-remove-$STAMP.txt"
  sync

  ui_print "[OK] Native InstallerX removed."
  ui_print "Quarantine: $QUAR"
  ui_print "The stock Google Package Installer will return next boot."
else
  ui_print "[OK] Native InstallerX module is not installed."
fi
exit 0
