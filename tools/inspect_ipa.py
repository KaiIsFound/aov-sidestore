"""Inspect a launch baseline without extracting, signing, or editing the IPA."""

import argparse
import hashlib
import json
import plistlib
import struct
import sys
import uuid
import zipfile
from pathlib import Path, PurePosixPath


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def arm64_uuid(data):
    # A UUID identifies a particular binary build; it does not attest provenance.
    if len(data) < 32 or data[:4] != b"\xcf\xfa\xed\xfe":
        raise ValueError("Expected a thin, little-endian 64-bit Mach-O")
    if struct.unpack_from("<I", data, 4)[0] != 0x0100000C:
        raise ValueError("Expected ARM64 Mach-O")
    count, command_bytes = struct.unpack_from("<II", data, 16)
    end = 32 + command_bytes
    if count > 4096 or end > len(data):
        raise ValueError("Invalid Mach-O command bounds")
    position = 32
    result = None
    for _ in range(count):
        if position + 8 > end:
            raise ValueError("Truncated Mach-O command")
        command, size = struct.unpack_from("<II", data, position)
        if size < 8 or size % 8 or position + size > end:
            raise ValueError("Invalid Mach-O command size")
        if command == 0x1B:
            if size != 24 or result is not None:
                raise ValueError("Invalid or repeated LC_UUID")
            result = str(uuid.UUID(bytes=data[position + 8:position + 24]))
        position += size
    if position != end or result is None:
        raise ValueError("Missing UUID or inconsistent command lengths")
    return result


def inspect_ipa(path, expected_sha256=None):
    digest = sha256_file(path)
    if expected_sha256 and digest != expected_sha256.lower():
        raise ValueError("IPA SHA-256 differs from the selected baseline")
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Archive contains duplicate paths")
        expanded_size = 0
        for entry in archive.infolist():
            name = entry.filename
            parts = PurePosixPath(name).parts
            if name.startswith("/") or "\\" in name or ".." in parts:
                raise ValueError("Archive contains an unsafe path")
            expanded_size += entry.file_size
        if len(names) > 100000 or expanded_size > 8 * 1024**3:
            raise ValueError("Archive exceeds diagnostic size limits")
        roots = [name for name in names if name.startswith("Payload/")
                 and name.endswith(".app/Info.plist") and name.count("/") == 2]
        if len(roots) != 1:
            raise ValueError("Expected exactly one top-level app Info.plist")
        if archive.getinfo(roots[0]).file_size > 4 * 1024**2:
            raise ValueError("Info.plist exceeds size limit")
        app = roots[0].removesuffix("Info.plist")
        info = plistlib.loads(archive.read(roots[0]))
        executable = info.get("CFBundleExecutable")
        if not isinstance(executable, str) or not executable or any(
                char in executable for char in ("/", "\\")):
            raise ValueError("Invalid CFBundleExecutable")
        binaries = {}
        for relative in (executable, "Frameworks/aovnet.framework/aovnet"):
            entry = archive.getinfo(app + relative)
            if entry.file_size > 256 * 1024**2:
                raise ValueError("Binary exceeds diagnostic size limit")
            data = archive.read(entry)
            binaries[relative] = {
                "size": len(data), "uuid": arm64_uuid(data),
                "sha256": hashlib.sha256(data).hexdigest(),
            }
        bad_entry = archive.testzip()
        if bad_entry:
            raise ValueError("ZIP CRC check failed")
    return {
        "sha256": digest, "size": path.stat().st_size, "zip_crc": "passed",
        "bundle": {key: info.get(key) for key in (
            "CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion",
            "CFBundleExecutable", "MinimumOSVersion")},
        "binaries": binaries,
        "ollie_library_present": any(
            name.startswith(app) and name.endswith("/OllieAOV.dylib")
            for name in names),
        "device_launch_tested": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--expected-sha256")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = inspect_ipa(args.ipa, args.expected_sha256)
        text = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
        if args.output:
            args.output.write_text(text, encoding="utf-8")
        print(text, end="")
    except (OSError, ValueError, KeyError, zipfile.BadZipFile,
            RuntimeError, struct.error, plistlib.InvalidFileException) as error:
        print(f"Inspection failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
