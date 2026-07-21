#!/sbin/sh
# Read-only diagnostic collector for the RTWO services.jar bootloop.
# It writes only to /sdcard/RTWO-PM-BOOTLOOP-DIAG/.

MODULE_ID="rtwo_pm_sigbypass"
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

hash_file() {
  FILE="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$FILE" 2>/dev/null
  elif [ -x /tmp/busybox ]; then
    /tmp/busybox sha256sum "$FILE" 2>/dev/null
  fi
}

copy_file() {
  SRC="$1"
  DSTDIR="$2"
  [ -f "$SRC" ] || return 0
  mkdir -p "$DSTDIR"
  cp -p "$SRC" "$DSTDIR/" 2>/dev/null || cp "$SRC" "$DSTDIR/" 2>/dev/null || true
}

copy_dir_small() {
  SRC="$1"
  DST="$2"
  [ -d "$SRC" ] || return 0
  mkdir -p "$DST"
  cp -a "$SRC/." "$DST/" 2>/dev/null || true
}

copy_newest_matching() {
  SRC_DIR="$1"
  DST_DIR="$2"
  LIMIT="$3"
  shift 3
  [ -d "$SRC_DIR" ] || return 0
  mkdir -p "$DST_DIR"
  TMP_LIST="/tmp/rtwo-diag-list.$$"
  : > "$TMP_LIST"
  for PAT in "$@"; do
    find "$SRC_DIR" -maxdepth 1 -type f -name "$PAT" -print 2>/dev/null >> "$TMP_LIST"
  done
  if command -v sort >/dev/null 2>&1; then
    sort -r -u "$TMP_LIST" 2>/dev/null | head -n "$LIMIT" | while IFS= read -r F; do
      [ -f "$F" ] && cp -p "$F" "$DST_DIR/" 2>/dev/null || true
    done
  else
    head -n "$LIMIT" "$TMP_LIST" | while IFS= read -r F; do
      [ -f "$F" ] && cp -p "$F" "$DST_DIR/" 2>/dev/null || true
    done
  fi
  rm -f "$TMP_LIST"
}

ui_print ""
ui_print "RTWO PM Bootloop Diagnostic Collector v1.0"
ui_print "------------------------------------------"
ui_print "Read-only: no module or framework changes."

try_mount /data || true
[ -d /data/media/0 ] || {
  ui_print "[ERROR] /data is not mounted or decrypted."
  exit 1
}

STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
case "$STAMP" in 19*|20*) ;; *) STAMP="recovery-$(date +%s 2>/dev/null)" ;; esac

ROOT="/data/media/0/RTWO-PM-BOOTLOOP-DIAG"
OUT="$ROOT/$STAMP"
mkdir -p "$OUT" || {
  ui_print "[ERROR] Cannot create output directory."
  exit 1
}

{
  echo "collector_version=1.0"
  echo "created=$STAMP"
  echo "device=$(getprop ro.product.device 2>/dev/null)"
  echo "vendor_device=$(getprop ro.product.vendor.device 2>/dev/null)"
  echo "sdk=$(getprop ro.build.version.sdk 2>/dev/null)"
  echo "fingerprint=$(getprop ro.build.fingerprint 2>/dev/null)"
  echo "slot=$(getprop ro.boot.slot_suffix 2>/dev/null)"
  echo "module_dir=$MODDIR"
  echo "module_exists=$([ -d "$MODDIR" ] && echo yes || echo no)"
  echo "module_disabled=$([ -f "$MODDIR/disable" ] && echo yes || echo no)"
} > "$OUT/SUMMARY.txt"

getprop > "$OUT/getprop-recovery.txt" 2>&1 || true
cat /proc/mounts > "$OUT/mounts.txt" 2>&1 || true
cat /proc/partitions > "$OUT/proc-partitions.txt" 2>&1 || true
df -h > "$OUT/df.txt" 2>&1 || df > "$OUT/df.txt" 2>&1 || true
dmesg > "$OUT/dmesg-recovery.txt" 2>&1 || true

mkdir -p "$OUT/module"
for F in module.prop install-info.txt PATCH-INFO.txt VALIDATION.txt disable remove update; do
  copy_file "$MODDIR/$F" "$OUT/module"
done
if [ -f "$MODDIR/system/framework/services.jar" ]; then
  hash_file "$MODDIR/system/framework/services.jar" > "$OUT/module/services.jar.sha256" 2>&1 || true
  ls -l "$MODDIR/system/framework/services.jar" > "$OUT/module/services.jar.stat.txt" 2>&1 || true
fi
ls -la "$MODDIR" > "$OUT/module/module-listing.txt" 2>&1 || true
find "$MODDIR" -maxdepth 4 -type f -o -type d > "$OUT/module/module-tree.txt" 2>&1 || true

copy_newest_matching "/data/media/0/RTWO-PM-LOGS" "$OUT/rtwo-pm-logs" 30 "*.log" "*.txt"
copy_newest_matching "/data/system/dropbox" "$OUT/dropbox" 80 "*system_server*" "*SYSTEM_SERVER*" "*system_app_crash*" "*data_app_crash*" "*system_app_wtf*" "*SYSTEM_BOOT*" "*system_recovery_log*" "*tombstone*"
copy_newest_matching "/data/tombstones" "$OUT/tombstones" 30 "tombstone*" "*.pb"
copy_newest_matching "/data/anr" "$OUT/anr" 20 "traces*" "*.txt"
copy_dir_small "/data/misc/bootstat" "$OUT/bootstat"
copy_dir_small "/data/system/bootstat" "$OUT/system-bootstat"
copy_dir_small "/sys/fs/pstore" "$OUT/pstore"
copy_file "/proc/last_kmsg" "$OUT"
copy_file "/cache/recovery/last_log" "$OUT/recovery"
copy_file "/tmp/recovery.log" "$OUT/recovery"

ls -lat /data/system/dropbox > "$OUT/dropbox-listing.txt" 2>&1 || true
ls -lat /data/tombstones > "$OUT/tombstones-listing.txt" 2>&1 || true
ls -lat /data/anr > "$OUT/anr-listing.txt" 2>&1 || true
ls -la /data/adb/modules > "$OUT/modules-listing.txt" 2>&1 || true

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
ui_print "[OK] Diagnostic collection completed."
ui_print "Folder: $OUT"
if [ -n "$ARCHIVE" ]; then
  ui_print "Upload: $ARCHIVE"
else
  ui_print "Compression unavailable; upload the folder."
fi
ui_print ""
exit 0
