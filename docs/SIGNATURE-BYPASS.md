# PackageManager signature bypass dependency

InstallerX Native depends on a device-specific Android 16 `services.jar` patch
that allows replacement across different signing certificates.

The working RTWO v1.2 fix also required the complete module tree to use:

```text
u:object_r:system_file:s0
```

The proprietary framework payload is intentionally not included in this public
repository. Use the framework collector and rebuild from the exact device
firmware. Never reuse a patched `services.jar` after an OTA without verifying
the original hash.
