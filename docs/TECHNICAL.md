# Technical notes

## Why the package ID is replaced

Android 16 expects a privileged package installer. Adding InstallerX as a second
privileged handler can create ambiguous installer resolution. This project
instead builds InstallerX with the stock package ID and overlays the stock path.

## Why `.replace` matters

Without:

```text
system/priv-app/GooglePackageInstaller/.replace
```

Hybrid Mount may merge the module directory with the stock directory. The stock
APK or precompiled artifacts can remain visible. With `.replace`, the complete
directory is replaced by the module view.

## SELinux

Files created from TWRP initially inherited `adb_data_file` in an earlier
experiment. Framework and systemless payloads must be labeled:

```text
u:object_r:system_file:s0
```

The recovery scripts apply and verify this recursively before activation.

## Conflict discovered during testing

Thanox Zygisk hooks `system_server` and conflicted with the patched framework,
causing failures in Viper and SIM-related processes. The installer refuses to
enable while the known Thanox module is active.
