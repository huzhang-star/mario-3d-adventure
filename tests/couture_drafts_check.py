"""Verify the delivered studies, catalog compatibility and final selection traceability."""
from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[1]
d=root/'docs/couture-drafts'
rows=json.loads((d/'candidates.json').read_text())
selection=json.loads((d/'selections.json').read_text())
source=(root/'scripts/skin_style.gd').read_text()
catalog=[json.loads(m.group(0)) for m in re.finditer(r'\{"id"[^\n]+\}',source) if '"price":0' not in m.group(0)]
assert len(catalog)==len(selection)==20
assert len(rows)==400
assert len({r['draft_id'] for r in rows})==400
for skin in catalog:
    group=[r for r in rows if r['id']==skin['id']]
    assert len(group)==20
    assert {r['number'] for r in group}==set(range(1,21))
    assert all(r['price']==skin['price'] for r in group), 'Price changed'
    assert len({(r['cut'],r['color'],r['accent']) for r in group})==20
    win=next(r for r in group if r['number']==selection[skin['id']]['number'])
    assert all(skin[k]==win[k] for k in ('cut','color','accent')), 'Game diverges from reviewed choice'
    hashes=set()
    for r in group:
        f=d/'renders'/f'{r["draft_id"]}.png'
        raw=f.read_bytes()
        assert raw[:8]==b'\x89PNG\r\n\x1a\n' and len(raw)>10000
        hashes.add(hashlib.sha256(raw).hexdigest())
    assert len(hashes)==20, 'Duplicate rendered candidates'
    for pose in ['', '_angle','_back','_walk','_jump']:
        assert (root/'docs/couture'/f'{skin["id"]}{pose}.png').exists()
    assert (d/f'{skin["id"]}-20.png').exists()
sections=re.split(r'^## ',(root/'docs/couture-drafts.md').read_text(),flags=re.M)[1:]
assert len(sections)==20
assert all(len(re.findall(r'^\|\s*\d+\s*\|',s,flags=re.M))==20 for s in sections)
print('20 skins / 400 distinct renders / catalog and selection traceability: PASS')
