"""Contact sheets are assembled only from Godot screenshots, with no painted-over models."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parents[2]
D=ROOT/'docs/couture-drafts'
FONT='/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
def font(n): return ImageFont.truetype(FONT,n)
rows=json.loads((D/'candidates.json').read_text())
selected=json.loads((D/'selections.json').read_text()) if (D/'selections.json').exists() else {}
for sid in dict.fromkeys(r['id'] for r in rows):
    group=[r for r in rows if r['id']==sid]
    sheet=Image.new('RGB',(1500,1910),'#0f1b2d')
    d=ImageDraw.Draw(sheet)
    d.text((32,20),group[0]['name']+' · 20 版实模初稿',font=font(34),fill='#f9e8c7')
    d.text((32,68),'同一灯光 / 同一机位  ·  每行一种配色，每列一种主题内造型',font=font(20),fill='#aebfd2')
    for i,r in enumerate(group):
        x=24+(i%5)*294; y=110+(i//5)*446
        im=Image.open(D/'renders'/f'{r["draft_id"]}.png').convert('RGB')
        # Keep all silhouettes, even the widest peacock fan.
        im=im.resize((282,329),Image.Resampling.LANCZOS)
        sheet.paste(im,(x,y))
        chosen=selected.get(sid,{}).get('number')==r['number']
        if chosen:d.rounded_rectangle((x-2,y-2,x+284,y+430),radius=8,outline='#efcc82',width=3)
        d.text((x+10,y+335),f'{r["number"]:02}  '+r['palette_label'],font=font(19),fill='#f8e7c5' if chosen else '#e7edf5')
        d.text((x+10,y+364),r['cut_label'],font=font(17),fill='#b2c4d6')
        d.rectangle((x+10,y+397,x+65,y+411),fill='#'+r['color'])
        d.rectangle((x+72,y+397,x+127,y+411),fill='#'+r['accent'])
        if chosen:d.text((x+153,y+393),'入选终稿',font=font(17),fill='#efcc82')
    sheet.save(D/f'{sid}-20.png')
print('Built 20 contact sheets from 400 Godot renders.')
