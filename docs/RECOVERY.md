# Recovery

## Immediate rollback

From TWRP, flash:

```text
RTWO-InstallerX-Native-v1.1-DISABLE.zip
```

The physical stock installer was never deleted. Disabling the module makes it
visible again on the next boot.

## Permanent removal

Flash REMOVE. The module is copied to:

```text
/sdcard/RTWO-INSTALLERX-NATIVE-REMOVED/
```

before deletion.

## Important distinction

Do not disable the Android package itself:

```text
com.google.android.packageinstaller
```

The native InstallerX replacement intentionally uses that identity. Disabling
the package disables both the stock implementation and the replacement.
