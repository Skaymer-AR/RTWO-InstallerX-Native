#!/system/bin/sh
MODDIR="${0%/*}"
chown -R 0:0 "$MODDIR" 2>/dev/null || true
chmod 0755 "$MODDIR" "$MODDIR/system" "$MODDIR/system/priv-app" \
  "$MODDIR/system/priv-app/GooglePackageInstaller" "$MODDIR/system/etc" \
  "$MODDIR/system/etc/permissions" 2>/dev/null || true
chmod 0644 "$MODDIR/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk" \
  "$MODDIR/system/priv-app/GooglePackageInstaller/.replace" \
  "$MODDIR/system/etc/permissions/privapp-permissions-installerx-native.xml" 2>/dev/null || true
chcon -R u:object_r:system_file:s0 "$MODDIR" 2>/dev/null || true
