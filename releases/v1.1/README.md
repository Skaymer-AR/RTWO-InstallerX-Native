# v1.1 release artifacts

The public repository is source-first. GitHub Actions builds InstallerX from the
pinned upstream commit, assembles PREPARE / ENABLE / DISABLE / REMOVE, verifies
the ZIPs and publishes them as a workflow artifact named:

```text
RTWO-InstallerX-Native-v1.1
```

The exact on-device tested APK hash was:

```text
dbae3bc57ecb130b282fed16799d46b2342db46980caab15457ac0338d32fa07
```

A fresh CI build may have a different signing certificate and therefore a
different APK hash. The assembler updates the recovery scripts automatically.
