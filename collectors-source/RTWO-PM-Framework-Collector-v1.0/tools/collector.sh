#!/sbin/sh
# Solo lectura: recopila framework y metadatos para construir un parche específico.

OUTFD="${OUTFD:-1}"
ZIPFILE="${1:-unknown}"
VERSION="1.0"
BASE="/data/media/0/RTWO-PM-COLLECTOR"
STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown-time)"
OUT="$BASE/$STAMP"
LOG="$OUT/collector.log"
FILES="$OUT/files"
META="$OUT/metadata"
LISTS="$OUT/listings"

ui_print() {
  echo "ui_print $*" > "/proc/self/fd/$OUTFD" 2>/dev/null || true
  echo "ui_print" > "/proc/self/fd/$OUTFD" 2>/dev/null || true
}

log() {
  echo "[$(date +%H:%M:%S 2>/dev/null || echo time)] $*" >> "$LOG"
}

safe_mkdir() {
  mkdir -p "$1" 2>/dev/null
}

try_mount() {
  MP="$1"
  if mountpoint -q "$MP" 2>/dev/null; then
    log "$MP ya estaba montado"
    return 0
  fi
  mount "$MP" >/dev/null 2>&1 && { log "Montado $MP"; return 0; }
  log "No se pudo montar $MP por nombre; se continuará buscando rutas existentes"
  return 1
}

copy_one() {
  SRC="$1"
  LABEL="$2"
  [ -f "$SRC" ] || return 1
  DST="$FILES/$LABEL"
  safe_mkdir "$(dirname "$DST")"
  cp -p "$SRC" "$DST" 2>>"$LOG" || cp "$SRC" "$DST" 2>>"$LOG" || return 1
  log "COPIADO $SRC -> $DST"
  return 0
}

hash_file() {
  F="$1"
  [ -f "$F" ] || return 0
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$F" >> "$META/sha256sums.txt" 2>>"$LOG"
  elif command -v busybox >/dev/null 2>&1; then
    busybox sha256sum "$F" >> "$META/sha256sums.txt" 2>>"$LOG"
  else
    cksum "$F" >> "$META/cksums.txt" 2>>"$LOG" || true
  fi
}

resolve_root() {
  NAME="$1"
  for P in "/$NAME" "/system_root/$NAME" "/mnt/system/$NAME" "/mnt/$NAME"; do
    [ -d "$P" ] && { echo "$P"; return 0; }
  done
  return 1
}

ui_print "========================================"
ui_print " RTWO PM Framework Collector v$VERSION"
ui_print " Solo lectura: NO parchea Android"
ui_print "========================================"

try_mount /data || true
[ -d /data/media/0 ] || {
  ui_print "[ERROR] /data/media/0 no está disponible."
  ui_print "Desencriptá /data en TWRP y repetí."
  exit 1
}

safe_mkdir "$FILES"
safe_mkdir "$META"
safe_mkdir "$LISTS"
: > "$LOG"
: > "$META/sha256sums.txt"

log "Collector version=$VERSION zip=$ZIPFILE"
log "uname=$(uname -a 2>/dev/null)"

for MP in /system /system_root /product /system_ext /vendor /odm; do
  [ -d "$MP" ] && try_mount "$MP" || true
done

SYSTEM_ROOT="$(resolve_root system 2>/dev/null || true)"
if [ -z "$SYSTEM_ROOT" ] && [ -f /system/framework/services.jar ]; then
  SYSTEM_ROOT="/system"
fi
if [ -n "$SYSTEM_ROOT" ] && [ -d "$SYSTEM_ROOT/system/framework" ]; then
  SYSTEM_ROOT="$SYSTEM_ROOT/system"
fi

PRODUCT_ROOT="$(resolve_root product 2>/dev/null || true)"
SYSTEM_EXT_ROOT="$(resolve_root system_ext 2>/dev/null || true)"
VENDOR_ROOT="$(resolve_root vendor 2>/dev/null || true)"
ODM_ROOT="$(resolve_root odm 2>/dev/null || true)"

{
  echo "collector_version=$VERSION"
  echo "timestamp=$STAMP"
  echo "system_root=$SYSTEM_ROOT"
  echo "product_root=$PRODUCT_ROOT"
  echo "system_ext_root=$SYSTEM_EXT_ROOT"
  echo "vendor_root=$VENDOR_ROOT"
  echo "odm_root=$ODM_ROOT"
  echo "slot_suffix=$(getprop ro.boot.slot_suffix 2>/dev/null)"
  echo "twrp_version=$(getprop ro.twrp.version 2>/dev/null)"
  echo "crypto_state=$(getprop ro.crypto.state 2>/dev/null)"
  echo "device_recovery=$(getprop ro.product.device 2>/dev/null)"
  echo "sdk_recovery=$(getprop ro.build.version.sdk 2>/dev/null)"
} > "$META/collector-info.txt"

getprop > "$META/getprop-recovery.txt" 2>>"$LOG" || true
cat /proc/mounts > "$META/mounts.txt" 2>>"$LOG" || true
cat /proc/partitions > "$META/proc-partitions.txt" 2>>"$LOG" || true
ls -l /dev/block/by-name > "$META/by-name-links.txt" 2>>"$LOG" || true

FOUND_SERVICES=0
if [ -n "$SYSTEM_ROOT" ]; then
  copy_one "$SYSTEM_ROOT/framework/services.jar" "system/framework/services.jar" && FOUND_SERVICES=1
  copy_one "$SYSTEM_ROOT/framework/framework.jar" "system/framework/framework.jar" || true
  copy_one "$SYSTEM_ROOT/framework/framework-res.apk" "system/framework/framework-res.apk" || true
  copy_one "$SYSTEM_ROOT/build.prop" "system/build.prop" || true
  copy_one "$SYSTEM_ROOT/etc/classpaths/bootclasspath.pb" "system/etc/classpaths/bootclasspath.pb" || true
  copy_one "$SYSTEM_ROOT/etc/classpaths/systemserverclasspath.pb" "system/etc/classpaths/systemserverclasspath.pb" || true
  copy_one "$SYSTEM_ROOT/etc/preloaded-classes" "system/etc/preloaded-classes" || true

  find "$SYSTEM_ROOT/framework" -maxdepth 4 -type f 2>/dev/null | sort > "$LISTS/system-framework-files.txt"
  find "$SYSTEM_ROOT/etc/classpaths" -maxdepth 2 -type f 2>/dev/null | sort > "$LISTS/system-classpaths-files.txt"

  find "$SYSTEM_ROOT/framework" -maxdepth 5 -type f \
    \( -iname '*services*.odex' -o -iname '*services*.vdex' -o -iname '*services*.art' \
       -o -iname 'boot-services*.odex' -o -iname 'boot-services*.vdex' -o -iname 'boot-services*.art' \) \
    2>/dev/null | while IFS= read -r F; do
      REL="${F#$SYSTEM_ROOT/}"
      copy_one "$F" "system/$REL" || true
    done
fi

for PAIR in "$PRODUCT_ROOT|product" "$SYSTEM_EXT_ROOT|system_ext" "$VENDOR_ROOT|vendor" "$ODM_ROOT|odm"; do
  ROOT="${PAIR%%|*}"
  NAME="${PAIR##*|}"
  [ -n "$ROOT" ] || continue
  copy_one "$ROOT/build.prop" "$NAME/build.prop" || true
  if [ -d "$ROOT/framework" ]; then
    find "$ROOT/framework" -maxdepth 4 -type f 2>/dev/null | sort > "$LISTS/$NAME-framework-files.txt"
  fi
done

if [ "$FOUND_SERVICES" -ne 1 ]; then
  ui_print "[AVISO] No apareció en la ruta normal; buscando..."
  for ROOT in /system /system_root /mnt/system; do
    [ -d "$ROOT" ] || continue
    F="$(find "$ROOT" -type f -path '*/framework/services.jar' 2>/dev/null | head -n 1)"
    if [ -n "$F" ]; then
      copy_one "$F" "fallback/services.jar" && FOUND_SERVICES=1
      echo "$F" > "$META/services-source-path.txt"
      break
    fi
  done
fi

for BP in "$FILES/system/build.prop" "$FILES/product/build.prop" "$FILES/system_ext/build.prop" "$FILES/vendor/build.prop" "$FILES/odm/build.prop"; do
  [ -f "$BP" ] && grep -E '^(ro\.(build|system\.build|product\.build|vendor\.build|product\.(device|model)|build\.version\.(sdk|release|security_patch)|build\.fingerprint))=' "$BP" >> "$META/rom-properties-selected.txt" 2>/dev/null || true
done

find "$FILES" -type f 2>/dev/null | while IFS= read -r F; do hash_file "$F"; done

SERVICES_COPY=""
for C in "$FILES/system/framework/services.jar" "$FILES/fallback/services.jar"; do
  [ -f "$C" ] && { SERVICES_COPY="$C"; break; }
done
if [ -n "$SERVICES_COPY" ]; then
  if command -v unzip >/dev/null 2>&1; then
    unzip -l "$SERVICES_COPY" > "$META/services-jar-contents.txt" 2>>"$LOG" || true
  elif command -v busybox >/dev/null 2>&1; then
    busybox unzip -l "$SERVICES_COPY" > "$META/services-jar-contents.txt" 2>>"$LOG" || true
  fi
fi

cat > "$OUT/LEEME.txt" <<EOT
RTWO PM Framework Collector v$VERSION

Este paquete NO modificó Android. Solo recopiló archivos para construir un
parche específico del Package Manager de esta ROM.

Carpeta: $OUT
services.jar encontrado: $FOUND_SERVICES

Subí el archivo comprimido generado, o toda esta carpeta si TWRP no pudo
comprimirla. No borres la carpeta hasta verificar que el archivo se puede abrir.
EOT

ARCHIVE=""
PARENT="$(dirname "$OUT")"
NAME="$(basename "$OUT")"
if command -v zip >/dev/null 2>&1; then
  (cd "$PARENT" && zip -r "$NAME.zip" "$NAME" >/dev/null 2>>"$LOG") && ARCHIVE="$PARENT/$NAME.zip"
elif command -v busybox >/dev/null 2>&1 && busybox zip 2>&1 | grep -q 'Usage'; then
  (cd "$PARENT" && busybox zip -r "$NAME.zip" "$NAME" >/dev/null 2>>"$LOG") && ARCHIVE="$PARENT/$NAME.zip"
elif command -v tar >/dev/null 2>&1; then
  (cd "$PARENT" && tar -czf "$NAME.tar.gz" "$NAME" 2>>"$LOG") && ARCHIVE="$PARENT/$NAME.tar.gz"
fi

ui_print "----------------------------------------"
if [ "$FOUND_SERVICES" -eq 1 ]; then
  ui_print "[OK] services.jar fue recopilado."
else
  ui_print "[ERROR] No se encontró services.jar."
  ui_print "El log igualmente puede servir para ajustar rutas."
fi
ui_print "Salida: $OUT"
[ -n "$ARCHIVE" ] && ui_print "Comprimido: $ARCHIVE"
ui_print "No se modificó system, product ni /data/adb."
ui_print "----------------------------------------"

[ "$FOUND_SERVICES" -eq 1 ] || exit 2
exit 0
