#!/usr/bin/env python3
"""Run representative-preview production checks with an isolated save profile."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', required=True, type=Path)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path)
    parser.add_argument('--case', action='append', dest='cases')
    args = parser.parse_args()
    project = args.project.resolve()
    out = (args.output or project / 'tests' / 'preview_evidence').resolve()
    out.mkdir(parents=True, exist_ok=True)
    cases = args.cases or ['progress', 'save-write', 'save-read', 'recover-main',
                           'protect-corrupt', 'combat', 'effects', 'collision', 'integration']
    results = []
    with tempfile.TemporaryDirectory(prefix='linchuan-preview-qa-') as profile:
        env = dict(os.environ, XDG_DATA_HOME=profile+'/data',
                   XDG_CONFIG_HOME=profile+'/config', XDG_CACHE_HOME=profile+'/cache')
        stages = [('version', [str(args.engine), '--version']),
                  ('import', [str(args.engine), '--headless', '--editor', '--path', str(project), '--quit'])]
        stages += [(case, [str(args.engine), '--headless', '--path', str(project),
                           '--script', 'res://tests/preview_checks.gd', '--',
                           '--preview-case='+case,
                           '--test-profile='+profile+('/persistence.json' if case in
                            ('save-write', 'save-read', 'recover-main') else '/'+case+'.json')])
                   for case in cases]
        for name, command in stages:
            started = time.monotonic()
            try:
                run = subprocess.run(command, env=env, capture_output=True, text=True, timeout=120)
                log, code = run.stdout+'\n'+run.stderr, run.returncode
            except subprocess.TimeoutExpired as exc:
                log, code = str(exc), 'TIMEOUT'
            (out/(name+'.log')).write_text(log, encoding='utf-8')
            engine_error = bool(re.search(r'SCRIPT ERROR:|Parse Error:|ERROR:', log))
            marker = re.findall(r'PREVIEW_QA_RESULT (\{[^\n]+\})', log)
            details = json.loads(marker[-1]) if marker else None
            passed = code == 0 and not engine_error and (name in ('version', 'import') or details is not None)
            results.append(dict(stage=name, command=command, exit_code=code,
                                seconds=round(time.monotonic()-started, 3),
                                passed=passed, engine_error=engine_error, details=details))
            print(f'{name}: {"PASS" if passed else "FAIL"} ({code})', flush=True)
        sources = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in sorted((project/'scripts').glob('*.gd'))}
        report = dict(scope='Native Godot production-action and isolated persistence checks; '
                            'no Windows execution or GPU performance claim',
                      completed_utc=datetime.now(timezone.utc).isoformat(),
                      source_sha256=sources, results=results)
        (out/'summary.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    return 0 if all(r['passed'] for r in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
