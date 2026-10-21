#!/usr/bin/env python3
"""Extract original-size movie evidence; no rescaling or image synthesis."""
import argparse
import io
import json
from pathlib import Path
import subprocess
import re
import hashlib
from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    out = args.directory.resolve()
    data = json.loads((out/'actions.json').read_text())
    manifest = json.loads((out/'manifest.json').read_text())
    states = data['frame_states']
    if manifest['returncode'] != 0:
        raise SystemExit('Refusing to extract acceptance sheets from invalid capture')
    logical_size = data.get('scenery',{}).get('viewport_size')
    if logical_size is None:
        project = Path(__file__).resolve().parents[1]/'project.godot'
        if hashlib.sha256(project.read_bytes()).hexdigest()!=manifest['source_sha256']['project.godot']:
            raise SystemExit('Missing recorded logical viewport and project settings changed')
        settings = project.read_text()
        logical_size = [int(re.search(r'window/size/viewport_'+key+r'=(\d+)',settings).group(1)) for key in ['width','height']]
    segments = ['front_basic', 'back_basic', 'left_basic', 'right_basic']
    selections = []
    for segment in segments:
        group = [(index, f) for index, f in enumerate(states) if f['segment']==segment]
        first_pose = next(f['time'] for _, f in group if f['pose_column']==0)
        idle_before = min(group, key=lambda p: abs(p[1]['time']-(first_pose-0.075)))
        idle_after = next((index, f) for index, f in group if f['time']>first_pose+0.32 and f['pose_column']==-1)
        picks = [('idle-before', idle_before)]
        for col in range(4):
            picks.append((f'pose-{col}', next((index,f) for index,f in group if f['pose_column']==col)))
        picks.append(('idle-after',idle_after))
        tiles = []
        for name, (index, state) in picks:
            # The movie has one initial frame before the first fixture _process.
            video_frame = index+1
            png = subprocess.check_output(['ffmpeg','-v','error','-i',str(out/'shen-attack.avi'),
                  '-vf',f"select='eq(n,{video_frame})'",'-frames:v','1','-f','image2pipe','-vcodec','png','-'])
            image = Image.open(io.BytesIO(png)).convert('RGB')
            if name=='pose-0': image.save(out/(segment+'-full.png'))
            x,y = state['hero_ground_screen']
            x *= image.width/logical_size[0]
            y *= image.height/logical_size[1]
            box = (round(x)-165, round(y)-200, round(x)+165, round(y)+50)
            crop = image.crop(box)
            tile = Image.new('RGB',(330,275),'#202631')
            tile.paste(crop,(0,25))
            ImageDraw.Draw(tile).text((6,5),f'{name} t={state["time"]:.3f} n={video_frame}',fill='white')
            tiles.append(tile)
            selections.append({'segment':segment,'phase':name,'state_index':index,
                               'video_frame':video_frame,'simulation_time':state['time'],'native_crop':box})
        sheet = Image.new('RGB',(330*len(tiles),275))
        for index,tile in enumerate(tiles): sheet.paste(tile,(index*330,0))
        sheet.save(out/(segment+'-native-sequence.png'))
    (out/'extraction.json').write_text(json.dumps({'method':'Unscaled native crops from actual movie. Logical viewport points mapped to recorded image dimensions before cropping. Labelled strip; original full contact frames retained.','logical_viewport':logical_size,'selections':selections},indent=2))


if __name__=='__main__':
    main()
