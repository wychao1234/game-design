#!/usr/bin/env python3
"""Check migration tool error boundaries and the resulting source archive."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile


def main():
    project = Path(__file__).resolve().parents[1]
    runner = project / 'tests/run_shen_visual.py'
    cases = [([], '--engine'),
             (['--engine', sys.executable, '--movie'], '--offscreen'),
             (['--engine', str(project / 'not-a-godot-executable')], '--engine')]
    for arguments, message in cases:
        result = subprocess.run([sys.executable, str(runner), *arguments],
                                capture_output=True, text=True, timeout=10)
        assert result.returncode == 2 and message in result.stderr, result.stderr

    spec = importlib.util.spec_from_file_location('game_build', project / 'tools/build.py')
    build = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(build)
    with tempfile.TemporaryDirectory(prefix='linchuan-migration-tools-') as temporary:
        base = Path(temporary)
        source = base / 'source'
        kept = ['.gitignore', 'project.godot', 'assets/hero.png',
                'assets/hero.png.import', 'scripts/hero.gd.uid', 'docs/engine.log']
        omitted = ['.engine.log.abc', 'tests/.movie.avi.copy',
                   'tests/.capture.tmp/frame.png', 'tests/engine.log.bak',
                   'tests/engine.log.old', 'tests/capture.tmp',
                   'ember_save.json', 'linchuan_preview_v2.json', '.godot/cache.bin']
        for name in kept + omitted:
            target = source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b'fixture')
        archive = base / 'source.zip'
        build.make_zip(source, archive, 'ember-town')
        with zipfile.ZipFile(archive) as result:
            assert set(result.namelist()) == {'ember-town/' + name for name in kept}
            assert result.testzip() is None
        (source / 'linked.png').symlink_to(source / 'assets/hero.png')
        try:
            list(build.files(source))
        except RuntimeError as error:
            assert 'Symbolic links' in str(error)
        else:
            raise AssertionError('A symlink bypassed the source boundary')
    print('MIGRATION_TOOLS PASS: CLI prerequisites, archive filtering and symlink rejection')


if __name__ == '__main__':
    main()
