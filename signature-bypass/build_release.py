#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import gzip
import hashlib
import json
import stat
import zipfile
from pathlib import Path

VERSION = "v1.2"
FIXED_DATE = (2008, 1, 1, 0, 0, 0)
ROOT = Path(__file__).resolve().parent


def load_templates() -> dict[str, str]:
    encoded = (ROOT / "templates.json.gz.b64").read_bytes()
    return json.loads(gzip.decompress(base64.b64decode(encoded)))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def zip_bytes(entries: dict[str, bytes], output: Path) -> None:
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in sorted(entries):
            mode = 0o755 if name.endswith(".sh") or name.endswith("update-binary") else 0o644
            info = zipfile.ZipInfo(name, FIXED_DATE)
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, entries[name])
    with zipfile.ZipFile(output) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"Corrupt member {bad} in {output}")


def validate_manifest(manifest: dict) -> None:
    assert manifest["device"] == "rtwo"
    assert manifest["sdk"] == 36
    assert len(manifest["source_sha256"]) == 64
    assert len(manifest["generated_sha256"]) == 64
    names = {item["name"] for item in manifest["patches"]}
    assert names == {
        "classes2-dex-header.bin",
        "prepare-signature-block.bin",
        "upgrade-keyset-return.bin",
        "verify-signatures-return.bin",
        "classes2-local-crc.bin",
        "classes2-central-crc.bin",
    }
    for item in manifest["patches"]:
        assert int(item["offset"]) >= 0
        assert bytes.fromhex(item["hex"])


def make_action(action: str, templates: dict[str, str], manifest: dict, out: Path) -> Path:
    entries = {
        "META-INF/com/google/android/update-binary": templates[f"meta/{action}/update-binary"].encode(),
        "META-INF/com/google/android/updater-script": templates[f"meta/{action}/updater-script"].encode(),
        f"tools/{action}.sh": templates[f"tools/{action}.sh"].encode(),
    }
    if action == "prepare":
        for name in ("module.prop", "post-fs-data.sh", "uninstall.sh", "PATCH-INFO.txt", "VALIDATION.txt"):
            entries[f"payload/{name}"] = templates[f"payload/{name}"].encode()
        for item in manifest["patches"]:
            entries[f"payload/patches/{item['name']}"] = bytes.fromhex(item["hex"])
    output = out / f"RTWO-PM-Signature-Bypass-{VERSION}-{action.upper()}.zip"
    zip_bytes(entries, output)
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=ROOT / "patch-manifest.json")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    templates = load_templates()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    validate_manifest(manifest)
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)

    outputs = [make_action(action, templates, manifest, out) for action in ("prepare", "enable", "disable", "remove")]
    readme = out / f"RTWO-PM-Signature-Bypass-{VERSION}-LEEME.txt"
    readme.write_text(
        "RTWO PackageManager Signature Bypass v1.2 - reproducible public build\n"
        "Device/build locked: Motorola Edge 40 Pro rtwo, Android 16 SDK 36.\n"
        "PREPARE reconstructs the patched services.jar from the exact stock file on-device.\n"
        "It does not redistribute Motorola's complete framework binary.\n\n"
        "Order: PREPARE -> ENABLE -> reboot. Keep DISABLE on external storage.\n"
        "Thanox Zygisk must remain disabled.\n\n"
        f"Stock SHA-256: {manifest['source_sha256']}\n"
        f"Generated SHA-256: {manifest['generated_sha256']}\n\n"
        "WARNING: this disables package-signature enforcement and materially weakens Android security.\n",
        encoding="utf-8",
    )
    outputs.append(readme)
    sums = out / f"RTWO-PM-Signature-Bypass-{VERSION}-SHA256SUMS.txt"
    sums.write_text("".join(f"{sha256(path)}  {path.name}\n" for path in outputs), encoding="utf-8")
    outputs.append(sums)
    bundle = out / f"RTWO-PM-Signature-Bypass-{VERSION}-BUNDLE.zip"
    zip_bytes({path.name: path.read_bytes() for path in outputs}, bundle)

    for path in outputs + [bundle]:
        print(f"{sha256(path)}  {path.name}  ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
