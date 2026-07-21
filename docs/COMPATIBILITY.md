# Compatibility

## Confirmed

- Motorola Edge 40 Pro (`rtwo`)
- Android 16 / SDK 36
- Stock installer path:
  `/system/priv-app/GooglePackageInstaller/GooglePackageInstaller.apk`
- Stock package:
  `com.google.android.packageinstaller`

## Build locks

```text
Stock GooglePackageInstaller:
c826d4f46f6180897b9246960fbbbe0b8b0a9c05259f51bbfab9e0645aca9a3f

InstallerX source APK:
b7ad13b623f421807b603a2159edc84069aa98650c270bb1615adc78770acf7d

Adapted native InstallerX:
dbae3bc57ecb130b282fed16799d46b2342db46980caab15457ac0338d32fa07

Original services.jar:
6c0d2b474ac5f98b6291c8a9cf49758027e63e32a7939e6836b78fb0e8dc6a22

Patched services.jar:
07b804d3700b83155932a398ef07caecfce3e6a19724007ad89250da0f9fdad1
```

A different OTA or firmware build must be re-collected and rebuilt.
