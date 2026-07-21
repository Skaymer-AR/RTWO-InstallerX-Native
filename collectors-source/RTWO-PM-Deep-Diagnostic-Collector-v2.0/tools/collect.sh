#!/sbin/sh
# RTWO PM Deep Diagnostic Collector v2.0
# Read-only collector. It does not enable, remove, relabel, or edit modules.

MODID="rtwo_pm_sigbypass"
MODDIR="/data/adb/modules/$MODID"

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

copy_if_file() {
  SRC="$1"
  DST="$2"
  [ -f "$SRC" ] || return 0
  mkdir -p "$(dirname "$DST")"
  cp -p "$SRC" "$DST" 2>/dev/null || cp "$SRC" "$DST" 2>/dev/null || true
}

copy_tree_limited() {
  SRC="$1"
  DST="$2"
  [ -d "$SRC" ] || return 0
  mkdir -p "$DST"
  find "$SRC" -maxdepth 3 -type f 2>/dev/null | head -n 200 | while IFS= read -r F; do
    REL="${F#$SRC/}"
    mkdir -p "$DST/$(dirname "$REL")"
    cp -p "$F" "$DST/$REL" 2>/dev/null || true
  done
}

hash_file() {
  F="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$F" 2>/dev/null
  elif [ -x /tmp/busybox ]; then
    /tmp/busybox sha256sum "$F" 2>/dev/null
  fi
}

show_context() {
  F="$1"
  LABEL="$2"
  {
    echo "### $LABEL"
    echo "path=$F"
    if [ -e "$F" ]; then
      ls -ld "$F" 2>&1
      ls -ldZ "$F" 2>&1 || true
      stat "$F" 2>&1 || true
      hash_file "$F" || true
      if command -v getfattr >/dev/null 2>&1; then
        getfattr -d -m- "$F" 2>&1 || true
      elif [ -x /tmp/busybox ]; then
        /tmp/busybox getfattr -d -m- "$F" 2>&1 || true
      fi
    else
      echo "MISSING"
    fi
    echo
  }
}

ui_print ""
ui_print "RTWO PM Deep Diagnostic Collector v2.0"
ui_print "--------------------------------------"
ui_print "Read-only collection. No changes will be made."

try_mount /data || true
[ -d /data/media/0 ] || {
  ui_print "[ERROR] /data is not mounted/decrypted."
  exit 1
}

try_mount /system_root || true
try_mount /system || true
try_mount /product || true
try_mount /system_ext || true
try_mount /vendor || true

STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
case "$STAMP" in 19*|20*) ;; *) STAMP="recovery-$(date +%s 2>/dev/null)" ;; esac
ROOT="/data/media/0/RTWO-PM-DEEP-DIAG"
OUT="$ROOT/$STAMP"
mkdir -p "$OUT" || {
  ui_print "[ERROR] Cannot create output directory."
  exit 1
}

SYSJAR=""
for C in /system_root/system/framework/services.jar /system/system/framework/services.jar /system/framework/services.jar /mnt/system/system/framework/services.jar; do
  [ -f "$C" ] && { SYSJAR="$C"; break; }
done

{
  echo "collector_version=2.0"
  echo "created=$STAMP"
  echo "device=$(getprop ro.product.device 2>/dev/null)"
  echo "sdk=$(getprop ro.build.version.sdk 2>/dev/null)"
  echo "slot=$(getprop ro.boot.slot_suffix 2>/dev/null)"
  echo "system_services_path=$SYSJAR"
  echo "module_dir=$MODDIR"
  echo "module_exists=$([ -d "$MODDIR" ] && echo yes || echo no)"
  echo "module_disabled=$([ -f "$MODDIR/disable" ] && echo yes || echo no)"
} > "$OUT/SUMMARY.txt"

{
  echo "getenforce:"
  getenforce 2>&1 || true
  echo
  show_context "$SYSJAR" "original services.jar"
  show_context "$MODDIR" "module directory"
  show_context "$MODDIR/system" "module system directory"
  show_context "$MODDIR/system/framework" "module framework directory"
  show_context "$MODDIR/system/framework/services.jar" "module services.jar"
  show_context "/data/adb/modules/hybrid_mount" "Hybrid Mount module directory"
} > "$OUT/contexts.txt" 2>&1

{
  echo "Module system payload contexts"
  echo "=============================="
  find /data/adb/modules -path '*/system/*' -type f 2>/dev/null | head -n 100 | while IFS= read -r F; do
    ls -lZ "$F" 2>&1 || ls -l "$F" 2>&1 || true
  done
} > "$OUT/other-module-contexts.txt" 2>&1

{
  echo "SYSTEM / PRODUCT artifacts"
  echo "=========================="
  for D in /system_root/system/framework /system/framework /system_root/system/framework/oat /system_root/system/framework/oat/arm64 /system/framework/oat /system/framework/oat/arm64 /system_root/system/framework/arm64 /system/framework/arm64 /product/framework /system_ext/framework; do
    [ -d "$D" ] || continue
    echo
    echo "## $D"
    find "$D" -maxdepth 3 -type f \( -name 'services*' -o -name '*systemserver*' -o -name '*.odex' -o -name '*.vdex' -o -name '*.art' -o -name '*.prof' \) -print 2>/dev/null
  done

  echo
  echo "DATA ART cache artifacts"
  echo "========================"
  for D in /data/dalvik-cache /data/misc/apexdata/com.android.art/dalvik-cache /data/misc/apexdata/com.android.art; do
    [ -d "$D" ] || continue
    echo
    echo "## $D"
    find "$D" -maxdepth 5 -type f \( -iname '*services*' -o -iname '*system@framework*' -o -name '*.odex' -o -name '*.vdex' -o -name '*.art' \) -print 2>/dev/null | head -n 400
  done
} > "$OUT/artifact-inventory.txt" 2>&1

mkdir -p "$OUT/artifacts"
for D in /system_root/system/framework/oat/arm64 /system/framework/oat/arm64 /system_root/system/framework/arm64 /system/framework/arm64 /data/dalvik-cache/arm64 /data/misc/apexdata/com.android.art/dalvik-cache/arm64; do
  [ -d "$D" ] || continue
  find "$D" -maxdepth 1 -type f \( -name 'services.*' -o -name 'services.jar*' -o -iname '*system@framework@services*' \) 2>/dev/null | while IFS= read -r F; do
    SAFE="$(echo "$F" | sed 's#^/##; s#/#__#g')"
    copy_if_file "$F" "$OUT/artifacts/$SAFE"
  done
done

find "$OUT/artifacts" -type f -print 2>/dev/null | while IFS= read -r F; do
  hash_file "$F"
done > "$OUT/artifacts-sha256.txt" 2>&1

copy_if_file "/data/adb/modules/hybrid_mount/module.prop" "$OUT/hybrid-mount/module.prop"
copy_if_file "/data/adb/modules/hybrid_mount/disable" "$OUT/hybrid-mount/disable"
copy_if_file "/data/adb/modules/hybrid_mount/update" "$OUT/hybrid-mount/update"
copy_tree_limited "/data/adb/hybrid-mount" "$OUT/hybrid-mount/config-and-logs"
copy_tree_limited "/data/adb/ksu/log" "$OUT/kernelsu-logs"
copy_tree_limited "/data/adb/ksud" "$OUT/ksud"

{
  echo "Persistent log directories"
  echo "=========================="
  for D in /data/misc/logd /data/vendor/log /data/system/dropbox; do
    echo
    echo "## $D"
    ls -latZ "$D" 2>&1 | head -n 120 || true
  done
} > "$OUT/persistent-log-listings.txt" 2>&1

mkdir -p "$OUT/logd"
if [ -d /data/misc/logd ]; then
  find /data/misc/logd -maxdepth 2 -type f 2>/dev/null | head -n 80 | while IFS= read -r F; do
    SAFE="$(echo "$F" | sed 's#^/##; s#/#__#g')"
    copy_if_file "$F" "$OUT/logd/$SAFE"
  done
fi

for F in /system_root/system/etc/classpaths/bootclasspath.pb /system_root/system/etc/classpaths/systemserverclasspath.pb /system/etc/classpaths/bootclasspath.pb /system/etc/classpaths/systemserverclasspath.pb /system_root/system/build.prop /product/build.prop /system_ext/build.prop; do
  [ -f "$F" ] || continue
  SAFE="$(echo "$F" | sed 's#^/##; s#/#__#g')"
  copy_if_file "$F" "$OUT/framework-meta/$SAFE"
done

getprop > "$OUT/getprop-recovery.txt" 2>&1 || true
cat /proc/mounts > "$OUT/mounts.txt" 2>&1 || true
ls -laZ /data/adb/modules > "$OUT/modules-listing-Z.txt" 2>&1 || true
dmesg > "$OUT/dmesg-recovery.txt" 2>&1 || true

ARCHIVE=""
cd "$ROOT" || true
if command -v zip >/dev/null 2>&1; then
  zip -qr "${STAMP}.zip" "$STAMP" >/dev/null 2>&1 && ARCHIVE="$ROOT/${STAMP}.zip"
elif [ -x /tmp/busybox ] && /tmp/busybox zip --help >/dev/null 2>&1; then
  /tmp/busybox zip -qr "${STAMP}.zip" "$STAMP" >/dev/null 2>&1 && ARCHIVE="$ROOT/${STAMP}.zip"
elif command -v tar >/dev/null 2>&1; then
  tar -czf "${STAMP}.tar.gz" "$STAMP" >/dev/null 2>&1 && ARCHIVE="$ROOT/${STAMP}.tar.gz"
elif [ -x /tmp/busybox ]; then
  /tmp/busybox tar -czf "${STAMP}.tar.gz" "$STAMP" >/dev/null 2>&1 && ARCHIVE="$ROOT/${STAMP}.tar.gz"
fi

sync
ui_print ""
ui_print "[OK] Deep diagnostic completed."
ui_print "Folder: $OUT"
[ -n "$ARCHIVE" ] && ui_print "Upload: $ARCHIVE"
ui_print ""
exit 0
