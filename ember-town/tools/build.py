#!/usr/bin/env python3
"""Local, dependency-free Godot launcher and Windows/source packager."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ENGINE_VERSION = "4.5.2.stable"
IGNORE = {".git", ".godot", "dist", "build", "__pycache__", ".pytest_cache"}


def files(root: Path):
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root)
        if path.is_symlink():
            raise RuntimeError(f"Symbolic links are not packaged: {rel}")
        # Interrupted capture copies such as .engine.log.* must never enter a checkpoint.
        if any(part.startswith(".") and part != ".gitignore" for part in rel.parts):
            continue
        if path.is_file() and not any(part in IGNORE for part in rel.parts):
            if (path.name not in {".DS_Store", "export_presets.cfg", "RECOVERY_CHECKPOINT.json",
                                  "linchuan_preview_v2.json", "ember_save.json"}
                    and not path.name.endswith(("-save.json", ".json.bak", ".tmp", ".pyc",
                                                ".log.bak", ".log.old"))):
                yield path, rel


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def engine_path(value: str | None) -> Path:
    candidate = value or os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not candidate:
        raise RuntimeError("Godot not found. Set GODOT_BIN or pass --godot PATH.")
    path = Path(candidate).expanduser().resolve()
    result = subprocess.run([str(path), "--version"], check=True, text=True, capture_output=True, timeout=20)
    actual = result.stdout.strip()
    if actual != ENGINE_VERSION and not actual.startswith(ENGINE_VERSION + "."):
        raise RuntimeError(f"Expected {ENGINE_VERSION}; got {actual}")
    print(f"Godot: {actual}", flush=True)
    return path


def checked_run(command: list[str], log: Path):
    print("Running:", subprocess.list2cmdline(command), flush=True)
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace", timeout=600)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(result.stdout, encoding="utf-8")
    if result.returncode or re.search(r"(?m)^(SCRIPT ERROR:|ERROR:)", result.stdout):
        print(result.stdout[-16000:])
        raise RuntimeError(f"Godot failed; exit={result.returncode}; log={log}")
    print(f"Log: {log}", flush=True)


def make_zip(source: Path, destination: Path, prefix: str):
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path, rel in files(source):
            if path.resolve() != destination.resolve():
                archive.write(path, str(Path(prefix) / rel))
    with zipfile.ZipFile(destination) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("ZIP integrity check failed")
    print(f"ZIP: {destination} ({destination.stat().st_size} bytes)")


def export_windows(engine: Path, template: Path | None, output: Path):
    if not (ROOT / "project.godot").is_file():
        raise RuntimeError("project.godot is missing")
    if 'run/main_scene="res://adventure.tscn"' not in (ROOT / "project.godot").read_text(encoding="utf-8"):
        raise RuntimeError("The representative release must start adventure.tscn")
    if not (ROOT / "LICENSES" / "Godot-MIT.txt").is_file():
        raise RuntimeError("The Godot MIT license is missing")
    if template:
        template = template.expanduser().resolve()
        if not template.is_file() or template.read_bytes()[:2] != b"MZ":
            raise RuntimeError("Windows release template is missing or is not a PE executable")
        marker = template.parent / "version.txt"
        if not marker.is_file() or marker.read_text().strip() != ENGINE_VERSION:
            raise RuntimeError(f"Template version.txt must equal {ENGINE_VERSION}")
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    archive_path = output / "linchuan-preview-windows-x64.zip"
    with tempfile.TemporaryDirectory(prefix="ember-town-export-") as temporary:
        base = Path(temporary)
        stage, package = base / "project", base / "package"
        stage.mkdir()
        package.mkdir()
        for path, rel in files(ROOT):
            target = stage / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
        # The preset is created only in an isolated staging copy.
        preset = '''[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json"
exclude_filter="docs/*,tools/*,tests/*"
export_path=""
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=TEMPLATE
binary_format/architecture="x86_64"
binary_format/embed_pck=false
application/modify_resources=false
application/export_angle=0
application/export_d3d12=0
debug/export_console_wrapper=0
codesign/enable=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
'''
        (stage / "export_presets.cfg").write_text(
            preset.replace("TEMPLATE", json.dumps(str(template).replace("\\", "/") if template else "")),
            encoding="utf-8")
        checked_run([str(engine), "--headless", "--path", str(stage), "--import"], output / "import.log")
        checked_run([str(engine), "--headless", "--path", str(stage), "--export-release",
                     "Windows Desktop", str(package / "Linchuan.exe")], output / "export-windows.log")
        exe, pck = package / "Linchuan.exe", package / "Linchuan.pck"
        if not exe.is_file() or exe.read_bytes()[:2] != b"MZ" or not pck.is_file() or pck.stat().st_size == 0:
            raise RuntimeError("Export did not produce the expected executable and PCK")
        shutil.copy2(stage / "docs" / "PLAY.md", package / "README.md")
        shutil.copytree(stage / "docs", package / "docs")
        if (stage / "LICENSES").is_dir():
            shutil.copytree(stage / "LICENSES", package / "LICENSES")
        if (stage / "tests" / "preview_evidence").is_dir():
            shutil.copytree(stage / "tests" / "preview_evidence", package / "test-evidence")
        (package / "Launch.bat").write_bytes(
            b'@echo off\r\ncd /d "%~dp0"\r\n"%~dp0Linchuan.exe" --log-file "%~dp0runtime.log"\r\n'
            b'if errorlevel 1 (\r\n echo Launch failed. See runtime.log.\r\n pause\r\n)\r\n')
        manifest = {
            "engine_version": ENGINE_VERSION,
            "engine_binary_sha256": digest(engine),
            "engine_upstream": "https://github.com/godotengine/godot-builds/releases/tag/4.5.2-stable",
            "main_scene": "res://adventure.tscn",
            "renderer": "forward_plus",
            "windows_target_execution_verified": False,
            "target_gpu_performance_verified": False,
            "note": "Exported on the build host; Windows target execution requires Windows testing.",
            "source_sha256": {str(rel): digest(path) for path, rel in files(stage)},
            "payload_sha256": {str(rel): digest(path) for path, rel in files(package)},
            "template_sha256": digest(template) if template else None,
        }
        (package / "BUILD_INFO.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
        make_zip(package, archive_path, "Linchuan")
    return archive_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Path to the official Godot 4.5.2 stable editor binary")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("doctor")
    commands.add_parser("run")
    export = commands.add_parser("export-windows")
    export.add_argument("--template", type=Path, help="Official windows_release_x86_64.exe beside version.txt")
    export.add_argument("--output", type=Path, default=ROOT / "dist")
    source = commands.add_parser("source")
    source.add_argument("--output", type=Path, default=ROOT / "dist" / "linchuan-preview-source.zip")
    args = parser.parse_args()
    if args.command == "source":
        make_zip(ROOT, args.output.resolve(), "ember-town")
        return
    engine = engine_path(args.godot)
    if args.command == "doctor":
        print(json.dumps({"project_exists": (ROOT / "project.godot").is_file(), "engine_sha256": digest(engine)}, indent=2))
    elif args.command == "run":
        raise SystemExit(subprocess.call([str(engine), "--path", str(ROOT)]))
    elif args.command == "export-windows":
        export_windows(engine, args.template, args.output)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
