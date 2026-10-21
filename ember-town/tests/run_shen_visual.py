#!/usr/bin/env python3
"""Reproduce the internal Shen production-action fixture with disposable saves."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import signal
from datetime import datetime, timezone


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', required=True, type=Path,
                        help='Path to the pinned Godot 4.5.2 executable')
    parser.add_argument('--offscreen', type=Path,
                        help='Python offscreen launcher; required with --movie')
    parser.add_argument('--movie', action='store_true')
    parser.add_argument('--fixture', choices=['body', 'feedback', 'recovery', 'front_candidate'], default='body')
    parser.add_argument('--fps', type=int, default=40)
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    engine = args.engine.expanduser().resolve()
    if not engine.is_file():
        parser.error('--engine must point to an existing Godot executable')
    if args.movie and (args.offscreen is None or not args.offscreen.expanduser().is_file()):
        parser.error('--movie requires --offscreen pointing to an existing Python launcher')
    if args.fps <= 0:
        parser.error('--fps must be positive')
    project = Path(__file__).resolve().parents[1]
    fixture = {'body': 'shen_attack_visual_review.gd',
               'feedback': 'combat_feedback_visual_review.gd',
               'recovery': 'recovery_visual_review.gd',
               'front_candidate': 'front_candidate_visual_review.gd'}[args.fixture]
    expected_actions = {'body': 10, 'feedback': 4, 'recovery': 3, 'front_candidate': 3}[args.fixture]
    movie_name = 'shen-attack.avi' if args.fixture=='body' else 'feedback.avi'
    output = (args.out or project / ('tests/preview_evidence/visual-v3/attack-motion' if args.fixture=='body' else 'tests/preview_evidence/visual-v3/feedback-short-restored')).resolve()
    output.mkdir(parents=True, exist_ok=True)
    sources = ['scripts/adventure.gd', 'scripts/adventure_combat.gd',
               'scripts/waterfront.gd', 'project.godot',
               'assets/characters/shen.png', 'assets/characters/shen_attack.png',
               'assets/characters/shen_attack.json', 'tests/shen_attack_visual_review.gd']
    sources.append('tests/'+fixture)
    sources.append('tests/recovery_visual_review.gd')
    if args.fixture == 'front_candidate':
        sources.append('../docs/candidates/shen-front-recovery-v2/front-recovery-v2.png')
    hashes = {p: hashlib.sha256((project / p).read_bytes()).hexdigest()
              for p in sources if (project / p).is_file()}
    for directory in [project/'scripts', project/'assets/environment', project/'assets/characters']:
        for path in directory.rglob('*'):
            if path.is_file() and path.suffix in ['.gd', '.gdshader', '.png', '.import', '.json']:
                hashes[str(path.relative_to(project))] = hashlib.sha256(path.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='linchuan-preview-qa-') as temp:
        env = os.environ.copy()
        env.update(XDG_DATA_HOME=temp+'/data', XDG_CONFIG_HOME=temp+'/config',
                   XDG_CACHE_HOME=temp+'/cache')
        command = [str(engine), '--path', str(project), '--fixed-fps', str(args.fps),
                   '--resolution', '1440x810', '--script', 'res://tests/'+fixture]
        if args.movie:
            command += ['--write-movie', str(output/movie_name)]
            command = [sys.executable, str(args.offscreen.expanduser().resolve())] + command
        else:
            command.insert(1, '--headless')
        command += ['--', '--test-profile='+temp+'/profile.json',
                    '--review-json='+str(output/'actions.json')]
        started = datetime.now(timezone.utc).isoformat()
        with (output/'engine.log').open('w') as log:
            try:
                process = subprocess.Popen(command, env=env, stdout=log,
                                           stderr=subprocess.STDOUT, start_new_session=True)
                code = process.wait(timeout=900 if args.movie else 45)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=10)
                code = 124
        log_text = (output/'engine.log').read_text(errors='replace')
        engine_errors = [line for line in log_text.splitlines()
                         if line.startswith(('SCRIPT ERROR:', 'SHADER ERROR:', 'ERROR:'))]
        changed = [p for p, sha in hashes.items() if not (project/p).is_file()
                   or hashlib.sha256((project/p).read_bytes()).hexdigest() != sha]
        action_result = json.loads((output/'actions.json').read_text()) if (output/'actions.json').is_file() else {}
        result_valid = (action_result.get('scenery', {}).get('valid') is True
                        and len(action_result.get('actions', [])) == expected_actions
                        and action_result.get('failures') == [])
        if code == 0:
            if engine_errors: code = 3
            elif changed: code = 4
            elif not result_valid: code = 5
        manifest = {'utc': started, 'mode': 'real engine fixed-step movie' if args.movie else 'headless fixture check',
                    'fps': args.fps, 'command': command, 'returncode': code, 'source_sha256': hashes,
                    'fixture': args.fixture, 'expected_actions': expected_actions,
                    'scope': 'Held enemies and fixed standpoints; production attacks, not full gameplay or FPS evidence',
                    'engine_errors': engine_errors, 'scenery_and_actions_valid': result_valid,
                    'acceptance': 'internal capture technically valid; visual review pending' if code==0 else 'INVALID; inspect engine_errors, changed sources and action results',
                    'source_changes_during_run': changed}
        (output/'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
        print(json.dumps({'returncode': code, 'output': str(output),
                          'changed_sources': manifest['source_changes_during_run']}))
        return code


if __name__ == '__main__':
    raise SystemExit(main())
