from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
D = ROOT / 'docs/world-polish'
levels = json.loads((ROOT / 'docs/level-design.json').read_text())
font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf', 19)
for kind, title in [('level', '关卡全景'), ('landmark', '主题模型')]:
    for page in range(5):
        sheet = Image.new('RGB', (1320, 960), '#162135')
        draw = ImageDraw.Draw(sheet)
        draw.text((20, 10), f'{title} · Godot 实拍 · {page+1}/5', font=font, fill='#f4dfb4')
        for cell, number in enumerate(range(6+page*9, min(51, 15+page*9))):
            x, y = 12+(cell%3)*436, 50+(cell//3)*300
            im = Image.open(D / f'{kind}_{number:02}.png').convert('RGB')
            im = im.resize((424, 265), Image.Resampling.LANCZOS)
            sheet.paste(im, (x,y))
            draw.text((x+5,y+268), f'{number:02}  {levels[number-1]["name"]}', font=font, fill='#e5d5b8')
        sheet.save(D / f'{kind}-board-{page+1}.png')

sheet=Image.new('RGB',(1280,870),'#162135')
draw=ImageDraw.Draw(sheet)
for cell,(phase,label) in enumerate([(80,'冷却'),(240,'预警'),(315,'起焰'),(370,'持续喷发'),(445,'喷发末段'),(480,'熄灭余烟')]):
    x,y=(cell%3)*426,(cell//3)*435
    im=Image.open(D/f'vent_{phase:03}.png').crop((400,120,860,660)).resize((414,390),Image.Resampling.LANCZOS)
    sheet.paste(im,(x+6,y+35))
    draw.text((x+14,y+7),label,font=font,fill='#f4dfb4')
sheet.save(D/'vent-cycle.png')

frames=[]
for p in sorted((D/'vent-motion').glob('*.png')):
    im=Image.open(p).convert('RGB').resize((640,400),Image.Resampling.LANCZOS)
    frames.append(im)
if len(frames)==96:
    frames[0].save(D/'vent-motion.gif',save_all=True,append_images=frames[1:],duration=42,loop=0)
print('Built 10 world boards, fire cycle and 96-frame fire animation.')
