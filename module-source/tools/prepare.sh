#!/sbin/sh

MODULE_ID="rtwo_installerx_native"
MODDIR="/data/adb/modules/$MODULE_ID"
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
  for P in \
    /system_root/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk \
    /system/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk \
    /system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk \
    /mnt/system/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk
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
  for P in \
    "$BASE" \
    "$BASE/system" \
    "$BASE/system/priv-app" \
    "$BASE/system/priv-app/GooglePackageInstaller" \
    "$BASE/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk" \
    "$BASE/system/priv-app/GooglePackageInstaller/.replace" \
    "$BASE/system/etc" \
    "$BASE/system/etc/permissions" \
    "$BASE/system/etc/permissions/privapp-permissions-installerx-native.xml"
  do
    [ -e "$P" ] || return 1
    [ "$(context_of "$P")" = "u:object_r:system_file:s0" ] || return 1
  done
  return 0
}

dependency_checks() {
  [ -d /data/adb/modules/rtwo_pm_sigbypass ] || {
    ui_print "[ERROR] RTWO signature bypass v1.2 is not installed."
    return 1
  }
  [ ! -f /data/adb/modules/rtwo_pm_sigbypass/disable ] || {
    ui_print "[ERROR] Signature bypass is disabled."
    return 1
  }
  [ -d /data/adb/modules/hybrid_mount ] || {
    ui_print "[ERROR] Hybrid Mount is not installed."
    return 1
  }
  [ ! -f /data/adb/modules/hybrid_mount/disable ] || {
    ui_print "[ERROR] Hybrid Mount is disabled."
    return 1
  }
  if [ -d /data/adb/modules/zygisk_thanox ] && [ ! -f /data/adb/modules/zygisk_thanox/disable ]; then
    ui_print "[ERROR] Thanox Zygisk is active."
    return 1
  fi
  return 0
}

old_installerx_present() {
  grep -q "^$OLD_PACKAGE " /data/system/packages.list 2>/dev/null
}

STAGE="/data/adb/.rtwo_installerx_native.stage.$$"
OLD="/data/adb/.rtwo_installerx_native.old.$$"
LOGTMP="/tmp/installerx-native-prepare.log"
LOG=""
: > "$LOGTMP"

log() {
  echo "[$(date +%H:%M:%S 2>/dev/null)] $*" >> "$LOGTMP"
  [ -n "$LOG" ] && echo "[$(date +%H:%M:%S 2>/dev/null)] $*" >> "$LOG" 2>/dev/null || true
}

rollback() {
  rm -rf "$STAGE" 2>/dev/null || true
  if [ -d "$OLD" ]; then
    rm -rf "$MODDIR" 2>/dev/null || true
    mv "$OLD" "$MODDIR" 2>/dev/null || true
  fi
}

abort_install() {
  log "ABORT: $*"
  rollback
  ui_print "[ERROR] $*"
  [ -n "$LOG" ] && ui_print "Log: $LOG"
  exit 1
}

ui_print ""
ui_print "RTWO InstallerX Native v1.1 - PREPARE"
ui_print "-------------------------------------"
ui_print "The module will remain DISABLED."

try_mount /data || true
[ -d /data/media/0 ] || abort_install "/data is not mounted or decrypted."

STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
case "$STAMP" in 19*|20*) ;; *) STAMP="recovery-$(date +%s 2>/dev/null)" ;; esac
LOGDIR="/data/media/0/RTWO-INSTALLERX-NATIVE-LOGS"
mkdir -p "$LOGDIR" || abort_install "Cannot create log directory."
LOG="$LOGDIR/prepare-$STAMP.log"
cp "$LOGTMP" "$LOG" 2>/dev/null || true

DEVICE="$(getprop ro.product.device 2>/dev/null)"
[ -n "$DEVICE" ] || DEVICE="$(getprop ro.product.vendor.device 2>/dev/null)"
SDK="$(getprop ro.build.version.sdk 2>/dev/null)"
[ "$DEVICE" = "rtwo" ] || abort_install "Expected rtwo; found ${DEVICE:-unknown}."
[ "$SDK" = "36" ] || abort_install "Expected SDK 36; found ${SDK:-unknown}."

dependency_checks || abort_install "Dependency check failed."
old_installerx_present && abort_install "Uninstall com.rosan.installer.x.revived before PREPARE."

for MP in /system_root /system /product /system_ext /vendor; do try_mount "$MP" || true; done
STOCK="$(find_stock_apk)" || abort_install "Stock GooglePackageInstaller.apk was not found."
STOCK_SHA="$(hash_file "$STOCK")" || abort_install "Cannot hash stock installer."
[ "$STOCK_SHA" = "$EXPECTED_STOCK_SHA" ] || abort_install "Stock installer hash does not match this build."

PAYLOAD="$TMP/payload/GooglePackageInstaller.apk"
[ -f "$PAYLOAD" ] || abort_install "Adapted InstallerX payload is missing."
[ "$(hash_file "$PAYLOAD")" = "$EXPECTED_PAYLOAD_SHA" ] || abort_install "Adapted APK hash mismatch."

BACKUP="/data/media/0/RTWO-INSTALLERX-NATIVE-BACKUP/$STAMP"
mkdir -p "$BACKUP" || abort_install "Cannot create backup directory."
cp -p "$STOCK" "$BACKUP/GooglePackageInstaller.apk.stock" 2>/dev/null || cp "$STOCK" "$BACKUP/GooglePackageInstaller.apk.stock" || abort_install "Cannot back up stock installer."
[ "$(hash_file "$BACKUP/GooglePackageInstaller.apk.stock")" = "$EXPECTED_STOCK_SHA" ] || abort_install "Stock backup verification failed."

if [ -d "$MODDIR" ]; then
  mkdir -p "$BACKUP/previous-module"
  cp -a "$MODDIR/." "$BACKUP/previous-module/" 2>/dev/null || true
fi

rm -rf "$STAGE" "$OLD"
mkdir -p "$STAGE/system/priv-app/GooglePackageInstaller" "$STAGE/system/etc/permissions" || abort_install "Cannot create module staging tree."
cp "$TMP/payload/module.prop" "$STAGE/module.prop" || abort_install "Cannot copy module.prop."
cp "$PAYLOAD" "$STAGE/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk" || abort_install "Cannot copy native APK."
touch "$STAGE/system/priv-app/GooglePackageInstaller/.replace" || abort_install "Cannot create Hybrid Mount .replace marker."
cp "$TMP/payload/privapp-permissions-installerx-native.xml" "$STAGE/system/etc/permissions/" || abort_install "Cannot copy permission XML."
cp "$TMP/payload/post-fs-data.sh" "$STAGE/post-fs-data.sh" || abort_install "Cannot copy post-fs-data.sh."
cp "$TMP/payload/service.sh" "$STAGE/service.sh" || abort_install "Cannot copy service.sh."
cp "$TMP/payload/uninstall.sh" "$STAGE/uninstall.sh" || abort_install "Cannot copy uninstall.sh."
cp "$TMP/payload/INFO.txt" "$STAGE/INFO.txt" 2>/dev/null || true
cp "$TMP/payload/VALIDATION.txt" "$STAGE/VALIDATION.txt" 2>/dev/null || true
touch "$STAGE/disable"

cat > "$STAGE/install-info.txt" <<EOF
version=1.1
prepared_at=$STAMP
device=$DEVICE
sdk=$SDK
stock_path=$STOCK
stock_sha256=$STOCK_SHA
payload_sha256=$EXPECTED_PAYLOAD_SHA
state=disabled_pending_enable
EOF

chmod 0755 "$STAGE" "$STAGE/system" "$STAGE/system/priv-app" "$STAGE/system/priv-app/GooglePackageInstaller" "$STAGE/system/etc" "$STAGE/system/etc/permissions" "$STAGE/post-fs-data.sh" "$STAGE/service.sh" "$STAGE/uninstall.sh"
chmod 0644 "$STAGE/module.prop" "$STAGE/disable" "$STAGE/install-info.txt" "$STAGE/INFO.txt" "$STAGE/VALIDATION.txt" "$STAGE/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk" "$STAGE/system/priv-app/GooglePackageInstaller/.replace" "$STAGE/system/etc/permissions/privapp-permissions-installerx-native.xml"
chown -R 0:0 "$STAGE" 2>/dev/null || true

apply_system_context "$STAGE" || abort_install "Recovery cannot apply SELinux system_file context."
verify_contexts "$STAGE" || abort_install "SELinux context verification failed in staging."

if [ -d "$MODDIR" ]; then
  mv "$MODDIR" "$OLD" || abort_install "Cannot move previous module aside."
fi
mv "$STAGE" "$MODDIR" || abort_install "Cannot commit prepared module."
verify_contexts "$MODDIR" || abort_install "Committed module lost SELinux context."
[ -f "$MODDIR/disable" ] || abort_install "Safety disable marker is missing."
[ "$(hash_file "$MODDIR/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk")" = "$EXPECTED_PAYLOAD_SHA" ] || abort_install "Committed APK hash mismatch."

rm -rf "$OLD"
sync

ui_print ""
ui_print "[OK] InstallerX Native prepared and left DISABLED."
ui_print "APK context: $(context_of "$MODDIR/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk")"
ui_print "Backup: $BACKUP"
ui_print "Log: $LOG"
ui_print "Next: flash ENABLE v1.1, then reboot."
exit 0
