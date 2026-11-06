from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parents[2]
D=ROOT/'docs'
F='/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
font=lambda n:ImageFont.truetype(F,n)
rows=json.loads((D/'couture-drafts/candidates.json').read_text())
skins=list({r['id']:r for r in rows}.values())
poses=[('','正面'),('_angle','侧面'),('_back','背面'),('_walk','走路'),('_jump','跳跃')]
for group in range(4):
    sheet=Image.new('RGB',(1500,1850),'#101a2b');draw=ImageDraw.Draw(sheet)
    draw.text((24,15),'终稿多角度与动作检查 · '+str(group+1),font=font(28),fill='#eed7ae')
    for i,r in enumerate(skins[group*5:group*5+5]):
        y=66+i*355
        draw.text((24,y),r['name'],font=font(20),fill='#e4d3b1')
        for col,(suf,label) in enumerate(poses):
            x=24+col*295
            im=Image.open(D/'couture'/f'{r["id"]}{suf}.png').convert('RGB')
            im=im.resize((276,322),Image.Resampling.LANCZOS)
            sheet.paste(im,(x,y+25))
            draw.text((x+12,y+27),label,font=font(15),fill='#b7c8dc')
    sheet.save(D/f'couture-poses-{group+1}.png')
