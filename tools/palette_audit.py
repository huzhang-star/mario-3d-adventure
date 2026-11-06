from pathlib import Path
import re, math
s=Path('scripts/skin_style.gd').read_text()
rows=[]
for m in re.finditer(r'\{"id": "([^"]+)".*?"color": "([0-9a-f]+)".*?"accent": "([0-9a-f]+)".*?(?:"couture": true)?', s):
    if m.group(1) in {'rose_seraph','moon_empress','glass_butterfly','phoenix','ocean_pearl','sakura_deity','star_weaver','platinum_dragon','jade_peacock','eternal_dawn'}:
        rows.append((m.group(1),m.group(2),m.group(3)))
def rgb(h): return tuple(int(h[i:i+2],16) for i in (0,2,4))
def dist(a,b): return math.sqrt(sum((x-y)**2 for x,y in zip(rgb(a),rgb(b))))
lines=['# 典藏终稿色彩审计','', '| 皮肤 | 主色 | 辅色 | 与最近其他主色距离 |','|---|---|---|---:|']
for sid,c,a in rows:
    nearest=min((dist(c,cc),other) for other,cc,_ in rows if other!=sid)
    lines.append(f'| {sid} | `#{c}` | `#{a}` | {nearest[0]:.1f}（{nearest[1]}） |')
lines += ['', '主色距离按 RGB 欧氏距离计算，仅用于发现重复配色；终稿仍以实际 Godot 渲染和轮廓辨识度为准。']
Path('docs/couture-palette-audit.md').write_text('\n'.join(lines),encoding='utf-8')
