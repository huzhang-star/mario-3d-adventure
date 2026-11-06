"""Review sheets from render_shop.gd -- --all; no model image retouching."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('/tmp/couture-shop-fit')
OUT = ROOT / 'docs/couture-shop'
OUT.mkdir(exist_ok=True)
rows = json.loads((ROOT / 'docs/couture-drafts/candidates.json').read_text())
skins = list({r['id']: r for r in rows}.values())
font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf', 18)

for width, crop in [(1280, (40, 127, 390, 452)), (1600, (50, 159, 487, 565))]:
    for group in range(4):
        board = Image.new('RGB', (1110, 1850), '#101a2b')
        draw = ImageDraw.Draw(board)
        draw.text((10, 5), f'衣橱 {width} · 正 / 侧 / 背', font=font, fill='#f1dab3')
        for i, row in enumerate(skins[group*5:group*5+5]):
            y = 35 + i*360
            draw.text((10, y), row['name'], font=font, fill='#f1dab3')
            for col, angle in enumerate([0, 90, 180]):
                shot = SOURCE / f"{row['id']}_{width}_{angle}.png"
                with Image.open(shot) as image:
                    preview = image.crop(crop).resize((350, 325), Image.Resampling.LANCZOS)
                    board.paste(preview, (col*365+10, y+28))
        board.save(OUT / f'{width}-{group+1}.png')
print('Eight shop review sheets from 120 Godot screenshots.')
