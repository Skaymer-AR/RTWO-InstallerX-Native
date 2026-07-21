# RTWO InstallerX Native

Systemless replacement of the stock Google Package Installer with
**InstallerX Revived** on the Motorola Edge 40 Pro (`rtwo`) running Android 16.

> Estado: probado en dispositivo real. Instalación, desinstalación, autorización
> de aplicaciones y control nativo del instalador confirmados.

## Resultado

Android keeps the stock identity:

```text
com.google.android.packageinstaller
/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk
```

but Hybrid Mount exposes an InstallerX build compiled with that same package ID.
InstallerX therefore handles the standard install and uninstall intents as the
native privileged package installer.

## Entorno probado

- Motorola Edge 40 Pro (`rtwo`)
- Android 16 / SDK 36
- Bootloader desbloqueado
- KernelSU Next
- Hybrid Mount
- Zygisk Next
- TWRP funcional con desencriptación de `/data`
- RTWO PackageManager Signature Bypass v1.2
- Thanox Zygisk **desactivado**

## Arquitectura

```text
TWRP PREPARE
   └─ instala módulo desactivado + backup + validación de hashes/SELinux

TWRP ENABLE
   └─ activa overlay systemless

Hybrid Mount
   └─ reemplaza por completo GooglePackageInstaller mediante .replace

PackageManager
   └─ registra InstallerX bajo com.google.android.packageinstaller
```

## Build y descarga

El repositorio no versiona APKs ni ZIPs binarios. GitHub Actions compila InstallerX desde el commit upstream fijado y genera un artifact `RTWO-InstallerX-Native-v1.1`. También se puede ejecutar localmente `tools/build-installerx-from-source.sh` y `tools/assemble-release.py`.

Orden de instalación:

1. Desinstalar la app normal `com.rosan.installer.x.revived`.
2. Mantener `DISABLE` en el pendrive.
3. Flashear `PREPARE`.
4. Flashear `ENABLE`.
5. Reiniciar.
6. Ante problemas, flashear `DISABLE`.

## Por qué v1.1

La primera versión preparaba correctamente el módulo, pero no incluía
`GooglePackageInstaller/.replace`. En Hybrid Mount eso permitía una fusión del
directorio y Android podía continuar usando el APK stock.

v1.1 crea, etiqueta y verifica el marcador `.replace`, que fue la corrección
confirmada en el dispositivo.

## Bloqueo por build

Esta publicación está deliberadamente vinculada al firmware probado mediante:

- dispositivo `rtwo`
- SDK 36
- hash del Google Package Installer stock
- hash del APK InstallerX adaptado
- contexto SELinux `u:object_r:system_file:s0`

No es un ZIP universal.

## Compilar InstallerX desde upstream

El upstream admite cambiar el package ID sin editar su código:

```bash
git clone https://github.com/wxxsfxyzm/InstallerX-Revived.git
cd InstallerX-Revived
git checkout 5a63a9465129f547031fa8d1d7f3a945beeb732b
./gradlew :app:assembleOnlineUnstableRelease \
  -PAPP_ID=com.google.android.packageinstaller
```

Ver [`tools/build-installerx-from-source.sh`](tools/build-installerx-from-source.sh)
y [`docs/BUILD.md`](docs/BUILD.md).

## Advertencia de seguridad

El proyecto depende de un bypass nativo de verificación de firmas. Esto permite
reemplazar aplicaciones con firmas distintas y reduce una protección central de
Android. Está pensado para un teléfono laboratorio, no para un dispositivo de
producción o identidad sensible.

## Licencia

Los scripts y documentación de este repositorio se publican bajo GPL-3.0.
InstallerX Revived conserva su copyright y licencia upstream.
