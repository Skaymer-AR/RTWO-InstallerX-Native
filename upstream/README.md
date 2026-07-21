# Upstream source correspondence

The distributed InstallerX binary corresponds to InstallerX Revived commit:

```text
5a63a9465129f547031fa8d1d7f3a945beeb732b
```

The only project-specific build change is:

```text
-PAPP_ID=com.google.android.packageinstaller
```

Use `tools/build-installerx-from-source.sh` to obtain the complete upstream source
and build it with the replacement package ID.
