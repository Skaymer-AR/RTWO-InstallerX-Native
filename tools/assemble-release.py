#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import shutil
import stat
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "module-source"
VERSION = "v1.1"
OLD_PAYLOAD_HASH = "dbae3bc57ecb130b282fed16799d46b2342db46980caab15457ac0338d32fa07"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def patch_text(path: Path, payload_hash: str) -> None:
    text = path.read_text(encoding="utf-8")
    text = text.replace(OLD_PAYLOAD_HASH, payload_hash)
    path.write_text(text, encoding="utf-8", newline="\n")


def write_zip(root: Path, output: Path) -> None:
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for file in sorted(root.rglob("*")):
            if not file.is_file():
                continue
            arc = file.relative_to(root).as_posix()
            info = zipfile.ZipInfo.from_file(file, arc)
            info.external_attr = (stat.S_IFREG | (file.stat().st_mode & 0o777)) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            zf.writestr(info, file.read_bytes())
    with zipfile.ZipFile(output) as zf:
        bad = zf.testzip()
        if bad:
            raise RuntimeError(f"Corrupt ZIP member: {bad}")


def make_action(action: str, apk: Path, out: Path, payload_hash: str) -> Path:
    stage = out / f"stage-{action}"
    if stage.exists():
        shutil.rmtree(stage)
    (stage / "META-INF/com/google/android").mkdir(parents=True)
    (stage / "tools").mkdir(parents=True)

    shutil.copy2(SOURCE / f"meta/{action}/update-binary", stage / "META-INF/com/google/android/update-binary")
    shutil.copy2(SOURCE / f"meta/{action}/updater-script", stage / "META-INF/com/google/android/updater-script")
    shutil.copy2(SOURCE / f"tools/{action}.sh", stage / f"tools/{action}.sh")

    for file in stage.rglob("*"):
        if file.is_file() and (file.name == "update-binary" or file.suffix == ".sh"):
            file.chmod(0o755)

    if action == "prepare":
        payload = stage / "payload"
        payload.mkdir()
        shutil.copy2(apk, payload / "GooglePackageInstaller.apk")
        for name in [
            "module.prop",
            "post-fs-data.sh",
            "service.sh",
            "uninstall.sh",
            "privapp-permissions-installerx-native.xml",
            "INFO.txt",
            "VALIDATION.txt",
        ]:
            shutil.copy2(SOURCE / f"payload/{name}", payload / name)
        for file in payload.rglob("*"):
            if file.is_file() and file.suffix == ".sh":
                file.chmod(0o755)

    for file in stage.rglob("*"):
        if not file.is_file():
            continue
        if file.suffix in {".sh", ".txt"} or file.name == "update-binary":
            try:
                patch_text(file, payload_hash)
            except UnicodeDecodeError:
                pass

    output = out / f"RTWO-InstallerX-Native-{VERSION}-{action.upper()}.zip"
    write_zip(stage, output)
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    apk = args.apk.resolve()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    payload_hash = sha256(apk)

    outputs = [make_action(a, apk, out, payload_hash) for a in ("prepare", "enable", "disable", "remove")]

    readme = out / f"RTWO-InstallerX-Native-{VERSION}-LEEME.txt"
    readme.write_text(
        "RTWO InstallerX Native v1.1\n"
        "Build generated from public source. Keep DISABLE on external storage.\n"
        f"Adapted InstallerX APK SHA-256: {payload_hash}\n",
        encoding="utf-8",
    )
    outputs.append(readme)

    sums = out / f"RTWO-InstallerX-Native-{VERSION}-SHA256SUMS.txt"
    sums.write_text("".join(f"{sha256(p)}  {p.name}\n" for p in outputs), encoding="utf-8")
    outputs.append(sums)

    bundle = out / f"RTWO-InstallerX-Native-{VERSION}-BUNDLE.zip"
    with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for file in outputs:
            zf.write(file, file.name)

    print(f"Payload SHA-256: {payload_hash}")
    for file in outputs + [bundle]:
        print(file)


if __name__ == "__main__":
    main()
