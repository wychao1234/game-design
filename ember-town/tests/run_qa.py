#!/usr/bin/env python3
"""Run engine import and actual in-game tests; preserve commands and logs."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', required=True)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    out = (args.output or project / 'tests' / 'evidence').resolve()
    out.mkdir(parents=True, exist_ok=True)
    if not (project / 'project.godot').is_file():
        parser.error('project.godot is missing; no game checks were run')
    if not Path(args.engine).is_file():
        parser.error('engine path is missing; no game checks were run')
    results = []
    with tempfile.TemporaryDirectory(prefix='ember-town-qa-') as profile:
        env = os.environ.copy()
        env.update(XDG_DATA_HOME=profile + '/data', XDG_CONFIG_HOME=profile + '/config',
                   XDG_CACHE_HOME=profile + '/cache')
        stages = [('version', [args.engine, '--version']),
                  ('import', [args.engine, '--headless', '--editor', '--path', str(project), '--quit']),
                  ('logic', [args.engine, '--headless', '--path', str(project), 'res://main.tscn', '--', '--test'])]
        for case in ['combat', 'collision', 'save-write', 'save-read', 'recover-main', 'protect-corrupt']:
            save = profile + ('/persistence.json' if case.startswith('save-') or case == 'recover-main' else '/' + case + '.json')
            stages.append((case, [args.engine, '--headless', '--path', str(project), '--script', 'res://tests/independent_checks.gd', '--', '--qa-case=' + case, '--test-profile=' + save]))
        for name, command in stages:
            start = time.monotonic()
            try:
                run = subprocess.run(command, env=env, capture_output=True, text=True, timeout=90)
                log = run.stdout + '\n' + run.stderr
                code = run.returncode
            except subprocess.TimeoutExpired as exc:
                log = str(exc)
                code = 'TIMEOUT'
            (out / (name + '.log')).write_text(log, encoding='utf-8')
            engine_error = bool(re.search(r'SCRIPT ERROR:|Parse Error:|ERROR:', log))
            passed = code == 0 and not engine_error
            results.append(dict(stage=name, command=command, exit_code=code,
                                seconds=round(time.monotonic()-start, 3),
                                passed=passed, engine_error=engine_error))
            print(f'{name}: {"PASS" if passed else "FAIL"} ({code})')
            if not passed:
                break
    sources = {str(path.relative_to(project)): hashlib.sha256(path.read_bytes()).hexdigest()
               for path in sorted((project / 'scripts').glob('*.gd'))}
    report = dict(scope='headless import, in-game tests and independent production-action checks; no visual or Windows validation',
                  completed_utc=datetime.now(timezone.utc).isoformat(), source_sha256=sources,
                  results=results)
    (out / 'summary.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    return 0 if len(results) == len(stages) and all(r['passed'] for r in results) else 1


if __name__ == '__main__':
    sys.exit(main())
