#!/sbin/sh
# RTWO InstallerX Native System Installer Probe v1.0
# Read-only. It does not install, disable, replace, relabel, or delete anything.

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
  F="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$F" 2>/dev/null
  elif [ -x /tmp/busybox ]; then
    /tmp/busybox sha256sum "$F" 2>/dev/null
  fi
}

safe_name() {
  echo "$1" | sed 's#^/##; s#/#__#g; s#[^A-Za-z0-9._-]#_#g'
}

copy_file_named() {
  SRC="$1"
  DSTDIR="$2"
  [ -f "$SRC" ] || return 0
  mkdir -p "$DSTDIR"
  NAME="$(safe_name "$SRC")"
  cp -p "$SRC" "$DSTDIR/$NAME" 2>/dev/null || cp "$SRC" "$DSTDIR/$NAME" 2>/dev/null || true
}

extract_package_block() {
  XML="$1"
  PKG="$2"
  OUTFILE="$3"
  [ -f "$XML" ] || return 0
  awk -v pkg="$PKG" '
    BEGIN { capture=0; found=0 }
    {
      if (!capture && $0 ~ "<package " && $0 ~ "name=\"" pkg "\"") {
        capture=1
        found=1
      }
      if (capture) print
      if (capture && $0 ~ "</package>") {
        capture=0
        exit
      }
    }
    END {
      if (!found) exit 1
    }
  ' "$XML" > "$OUTFILE" 2>/dev/null || rm -f "$OUTFILE"
}

ui_print ""
ui_print "RTWO InstallerX Native Installer Probe v1.0"
ui_print "--------------------------------------------"
ui_print "Read-only inspection; no Android files changed."

try_mount /data || true
[ -d /data/media/0 ] || {
  ui_print "[ERROR] /data is not mounted or decrypted."
  exit 1
}

for MP in /system_root /system /product /system_ext /vendor /odm; do
  try_mount "$MP" || true
done

STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
case "$STAMP" in 19*|20*) ;; *) STAMP="recovery-$(date +%s 2>/dev/null)" ;; esac

ROOT="/data/media/0/RTWO-INSTALLERX-NATIVE-PROBE"
OUT="$ROOT/$STAMP"
mkdir -p "$OUT" || {
  ui_print "[ERROR] Cannot create output directory."
  exit 1
}

PACKAGES_XML="/data/system/packages.xml"
PACKAGES_LIST="/data/system/packages.list"

CANDIDATES="
com.android.packageinstaller
com.google.android.packageinstaller
com.motorola.packageinstaller
com.motorola.packageinstaller2
com.motorola.android.packageinstaller
com.miui.packageinstaller
com.samsung.android.packageinstaller
com.rosan.installer.x.revived
"

{
  echo "probe_version=1.0"
  echo "created=$STAMP"
  echo "device=$(getprop ro.product.device 2>/dev/null)"
  echo "vendor_device=$(getprop ro.product.vendor.device 2>/dev/null)"
  echo "sdk=$(getprop ro.build.version.sdk 2>/dev/null)"
  echo "release=$(getprop ro.build.version.release 2>/dev/null)"
  echo "fingerprint=$(getprop ro.build.fingerprint 2>/dev/null)"
  echo "incremental=$(getprop ro.build.version.incremental 2>/dev/null)"
  echo "security_patch=$(getprop ro.build.version.security_patch 2>/dev/null)"
  echo "slot=$(getprop ro.boot.slot_suffix 2>/dev/null)"
  echo "packages_xml_exists=$([ -f "$PACKAGES_XML" ] && echo yes || echo no)"
} > "$OUT/SUMMARY.txt"

getprop > "$OUT/getprop-recovery.txt" 2>&1 || true
cat /proc/mounts > "$OUT/mounts.txt" 2>&1 || true
df -h > "$OUT/df.txt" 2>&1 || df > "$OUT/df.txt" 2>&1 || true

mkdir -p "$OUT/package-records"
: > "$OUT/CANDIDATE-RESULTS.txt"

for PKG in $CANDIDATES; do
  echo "===== $PKG =====" >> "$OUT/CANDIDATE-RESULTS.txt"
  if [ -f "$PACKAGES_XML" ]; then
    grep -n "name=\"$PKG\"" "$PACKAGES_XML" >> "$OUT/CANDIDATE-RESULTS.txt" 2>/dev/null || echo "not found in packages.xml" >> "$OUT/CANDIDATE-RESULTS.txt"
    extract_package_block "$PACKAGES_XML" "$PKG" "$OUT/package-records/$PKG.xml"
  fi
  if [ -f "$PACKAGES_LIST" ]; then
    grep "^$PKG " "$PACKAGES_LIST" >> "$OUT/CANDIDATE-RESULTS.txt" 2>/dev/null || true
  fi
  echo >> "$OUT/CANDIDATE-RESULTS.txt"
done

if [ -f "$PACKAGES_XML" ]; then
  grep -inE 'packageinstaller|package.installer|installer[^"]*"' "$PACKAGES_XML" | head -n 300 > "$OUT/packages-xml-installer-hits.txt" 2>/dev/null || true
fi

mkdir -p "$OUT/system-apks"
: > "$OUT/SYSTEM-APK-INVENTORY.txt"
for BASE in /system_root/system /system /product /system_ext /vendor /odm; do
  [ -d "$BASE" ] || continue
  find "$BASE" -type f \( -iname '*PackageInstaller*.apk' -o -iname '*PermissionController*.apk' -o -iname '*Installer*.apk' \) 2>/dev/null | while IFS= read -r APK; do
    echo "$APK" >> "$OUT/SYSTEM-APK-INVENTORY.txt"
    ls -lZ "$APK" >> "$OUT/SYSTEM-APK-INVENTORY.txt" 2>&1 || ls -l "$APK" >> "$OUT/SYSTEM-APK-INVENTORY.txt" 2>&1 || true
    hash_file "$APK" >> "$OUT/SYSTEM-APK-INVENTORY.txt" 2>&1 || true
    echo >> "$OUT/SYSTEM-APK-INVENTORY.txt"
    copy_file_named "$APK" "$OUT/system-apks"
  done
done

mkdir -p "$OUT/permission-xml"
: > "$OUT/PERMISSION-XML-HITS.txt"
for DIR in /system_root/system/etc/permissions /system/etc/permissions /product/etc/permissions /system_ext/etc/permissions /vendor/etc/permissions /odm/etc/permissions /system_root/system/etc/sysconfig /system/etc/sysconfig /product/etc/sysconfig /system_ext/etc/sysconfig; do
  [ -d "$DIR" ] || continue
  find "$DIR" -maxdepth 2 -type f -name '*.xml' 2>/dev/null | while IFS= read -r XML; do
    if grep -qiE 'com\.android\.packageinstaller|com\.google\.android\.packageinstaller|com\.motorola[^"]*packageinstaller|INSTALL_PACKAGES|DELETE_PACKAGES|READ_INSTALL_SESSIONS|READ_INSTALLED_SESSION_PATHS|UPDATE_PACKAGES_WITHOUT_USER_ACTION' "$XML" 2>/dev/null; then
      echo "===== $XML =====" >> "$OUT/PERMISSION-XML-HITS.txt"
      grep -niE 'com\.android\.packageinstaller|com\.google\.android\.packageinstaller|com\.motorola[^"]*packageinstaller|INSTALL_PACKAGES|DELETE_PACKAGES|READ_INSTALL_SESSIONS|READ_INSTALLED_SESSION_PATHS|UPDATE_PACKAGES_WITHOUT_USER_ACTION' "$XML" >> "$OUT/PERMISSION-XML-HITS.txt" 2>/dev/null || true
      echo >> "$OUT/PERMISSION-XML-HITS.txt"
      copy_file_named "$XML" "$OUT/permission-xml"
    fi
  done
done

mkdir -p "$OUT/user-state"
for F in /data/system/users/0/package-restrictions.xml /data/system/users/0/runtime-permissions.xml /data/system/users/0/roles.xml /data/system/users/0/settings_secure.xml /data/system/users/0/settings_system.xml /data/system/users/0/settings_global.xml /data/misc_de/0/apexdata/com.android.permission/roles.xml /data/misc_de/0/apexdata/com.android.permission/runtime-permissions.xml; do
  copy_file_named "$F" "$OUT/user-state"
done

for F in /data/system/users/0/package-restrictions.xml /data/system/users/0/roles.xml /data/misc_de/0/apexdata/com.android.permission/roles.xml; do
  [ -f "$F" ] || continue
  echo "===== $F =====" >> "$OUT/DEFAULT-HANDLER-HITS.txt"
  grep -niE 'packageinstaller|installer|CONFIRM_INSTALL|INSTALL_PACKAGE|UNINSTALL_PACKAGE|android.intent.action.VIEW|vnd.android.package-archive' "$F" >> "$OUT/DEFAULT-HANDLER-HITS.txt" 2>/dev/null || true
  echo >> "$OUT/DEFAULT-HANDLER-HITS.txt"
done

ls -laZ /data/adb/modules > "$OUT/modules-listing-Z.txt" 2>&1 || true
find /data/adb/modules -maxdepth 3 -type f -name module.prop -print -exec cat {} \; > "$OUT/module-props.txt" 2>&1 || true

cat > "$OUT/UPLOADED-INSTALLERX.txt" <<'EOF'
Uploaded APK analysis:
package=com.rosan.installer.x.revived
versionName=26.06.5a63a94
versionCode=1422
minSdk=26
targetSdk=37
sha256=b7ad13b623f421807b603a2159edc84069aa98650c270bb1615adc78770acf7d

Requested privileged permissions include:
android.permission.INSTALL_PACKAGES
android.permission.DELETE_PACKAGES
android.permission.MANAGE_USERS
android.permission.READ_INSTALL_SESSIONS
android.permission.READ_INSTALLED_SESSION_PATHS
android.permission.UPDATE_PACKAGES_WITHOUT_USER_ACTION

Installer activity handles:
android.intent.action.VIEW
android.intent.action.INSTALL_PACKAGE
android.content.pm.action.CONFIRM_INSTALL
android.content.pm.action.CONFIRM_PERMISSIONS
android.content.pm.action.CONFIRM_PRE_APPROVAL
EOF

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
ui_print "[OK] Native installer probe completed."
ui_print "Folder: $OUT"
if [ -n "$ARCHIVE" ]; then
  ui_print "Upload: $ARCHIVE"
else
  ui_print "Compression unavailable; upload the folder."
fi
ui_print ""
exit 0
