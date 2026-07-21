# Reproducible build

## InstallerX

Pinned upstream commit:

```text
5a63a9465129f547031fa8d1d7f3a945beeb732b
```

The upstream Gradle configuration accepts `APP_ID`, so no source rewrite is
required.

```bash
./tools/build-installerx-from-source.sh
```

For stable future updates, provide a persistent signing keystore through:

```text
KEYSTORE_FILE
KEYSTORE_PASSWORD
KEY_ALIAS
KEY_PASSWORD
```

The signature bypass permits a different signature, but a stable project key is
still strongly recommended.

## Recovery ZIPs

The release ZIPs are assembled from `module/` and `recovery/`. Hash locks in the
scripts must be updated for a different firmware or APK.
