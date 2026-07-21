RTWO PM Deep Diagnostic Collector v2.0

Purpose:
- Inspect SELinux contexts of the original and module services.jar.
- Inventory/copy services-specific OAT, VDEX, ART and profile artifacts.
- Collect Hybrid Mount / KernelSU diagnostic information and persistent logd files.

Safety:
- Read-only.
- Does not enable the disabled signature-bypass module.
- Does not relabel, delete, clean caches, modify /system, or alter /data/adb modules.

Output:
/sdcard/RTWO-PM-DEEP-DIAG/
