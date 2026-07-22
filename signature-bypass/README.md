# RTWO PackageManager Signature Bypass v1.2

Public, reproducible and build-locked PackageManager signature bypass for the
Motorola Edge 40 Pro (`rtwo`) running Android 16 / SDK 36.

## Why this publication is different

The private lab ZIPs contained a complete rebuilt `services.jar` in every action
archive. The public release does **not** redistribute Motorola's framework file.
Instead, PREPARE:

1. reads the stock `services.jar` from the device;
2. requires the exact tested stock SHA-256;
3. copies it into a disabled KernelSU module staging directory;
4. applies six deterministic binary chunks to the stored `classes2.dex` entry;
5. requires the exact generated SHA-256;
6. applies `u:object_r:system_file:s0` recursively;
7. commits the module while keeping the `disable` marker.

No physical system partition is modified.

## Hash lock

```text
Stock services.jar:
6c0d2b474ac5f98b6291c8a9cf49758027e63e32a7939e6836b78fb0e8dc6a22

Public reproducible result:
cc9e49186fa56a2d144dd528133915989c4f247196d1d597b36e07e20a6d340c

Previously validated private rebuilt result:
07b804d3700b83155932a398ef07caecfce3e6a19724007ad89250da0f9fdad1
```

ENABLE accepts either patched result, so it can manage the already-installed
private module as well as the public reproducible module.

## Installation

1. Keep DISABLE on external storage.
2. Keep Thanox Zygisk disabled.
3. Flash PREPARE from TWRP.
4. Confirm it finishes prepared and disabled.
5. Flash ENABLE.
6. Reboot Android.

## Behavioral patch

- `PackageManagerServiceUtils.verifySignatures` returns without rejecting the package.
- `KeySetManagerService.shouldCheckUpgradeKeySetLocked` skips upgrade key-set validation.
- `InstallPackageHelper.preparePackage` skips the different-signature failure block.

## Security warning

This intentionally disables a core Android trust boundary. It allows an APK
signed by one certificate to replace a package signed by another certificate.
Use it only on a laboratory device, verify APK origin manually and keep a tested
recovery path available.

## Build

```bash
python3 signature-bypass/build_release.py \
  --manifest signature-bypass/patch-manifest.json \
  --out dist-signature-bypass
```
