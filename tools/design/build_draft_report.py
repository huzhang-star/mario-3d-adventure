from pathlib import Path
import json,html
ROOT=Path(__file__).resolve().parents[2]
D=ROOT/'docs/couture-drafts'
rows=json.loads((D/'candidates.json').read_text())
selections=json.loads((D/'selections.json').read_text())
lines=['# 20 款皮肤 · 每款 20 版初稿与选稿记录','',
'共 400 张 Godot 实际建模截图，每款为 5 个主题内造型 × 4 组配色。它们是同一角色、同一主题下的参数化初稿，不是 400 个独立手工重建模型。全部使用游戏同一建模函数、同一机位和灯光。','',
'已逐张对照 20 张初稿板，按脸部清晰、轮廓完整、主题辨识、配色区分和服饰连接选出终稿。没有自动美貌评分；“入选”是这轮视觉判断，不代表客观最美。','',
'本轮重点重做最高价永恒曙光的日冕、分片欧泊礼裙和背面披帛。保留奶油色可爱脸、肩部连接与左右手臂安排。选择后再检查正侧背与走路、跳跃。','',
'[打开可切换与放大的对比画册](couture-drafts/index.html)','']
for sid in selections:
    group=[r for r in rows if r['id']==sid]
    s=selections[sid]
    selected=next(r for r in group if r['number']==s['number'])
    lines += [f'## {selected["name"]} · {selected["price"]} 金币','',f'[20 版实拍对比板](couture-drafts/{sid}-20.png)','',
      f'**入选：第 {s["number"]:02} 版**，{selected["palette_label"]} / {selected["cut_label"]}。',
      f'对比候选：{"、".join(f"{v:02}" for v in s["shortlist"])}。{s["reason"]}',f'淘汰要点：{s["rejected"]}','',
      '| 版次 | 配色 | 主题内造型 | 主色 / 辅色 | 实拍 | 选择 |','|---:|---|---|---|---|---|']
    for r in group:
        mark='**入选终稿**' if r['number']==s['number'] else ('对比候选' if r['number'] in s['shortlist'] else '未选')
        lines.append(f'| {r["number"]:02} | {r["palette_label"]} | {r["cut_label"]} | `#{r["color"]}` / `#{r["accent"]}` | [查看](couture-drafts/renders/{r["draft_id"]}.png) | {mark} |')
    lines += ['']
(ROOT/'docs/couture-drafts.md').write_text('\n'.join(lines))
# Standalone gallery with embedded data; opening the file requires no server.
payload=json.dumps({'rows':rows,'selections':selections},ensure_ascii=False).replace('<','\\u003c')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>星跃岛 · 400版皮肤初稿</title>
<style>*{box-sizing:border-box}body{margin:0;background:#101a2b;color:#e8eef5;font:16px/1.65 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}header,main{max-width:1500px;margin:auto;padding:24px}h1{font-size:32px;color:#f2dab0;margin:6px 0}p{max-width:1000px;margin:8px 0;color:#b6c7da}nav{display:flex;flex-wrap:wrap;gap:8px;margin:20px 0}button,select{background:#20334d;color:#e9eef6;border:1px solid #49627c;border-radius:10px;padding:10px 14px;font:inherit;cursor:pointer}button.active{border-color:#dfb766;color:#f2d296;background:#3d3440}#hero{display:grid;grid-template-columns:320px 1fr;gap:28px;background:#18283e;padding:24px;border-radius:18px}#hero img{width:100%;border-radius:12px}#grid{display:grid;grid-template-columns:repeat(5,1fr);gap:16px}.card{border:1px solid #2b425d;background:#17273e;border-radius:14px;overflow:hidden}.card.chosen{border:2px solid #e0bc78}.card img{display:block;width:100%;cursor:zoom-in}.caption{padding:12px}.caption strong{display:block;color:#f4e4c8}.swatch{display:inline-block;width:35px;height:9px;border-radius:3px;margin-right:5px}.tag{color:#efd095;font-size:14px}h2{margin:24px 0 8px}a{color:#c1dbf4}dialog{max-width:96vw;border:1px solid #77808d;border-radius:14px;background:#111e30;padding:12px;color:white}dialog::backdrop{background:#000b}dialog img{display:block;max-height:78vh;max-width:90vw}#filters{display:flex;gap:14px;align-items:center;flex-wrap:wrap;margin:18px 0}label{cursor:pointer}small{color:#9fb4ce}@media(max-width:900px){#grid{grid-template-columns:repeat(3,1fr)}#hero{grid-template-columns:230px 1fr}}@media(max-width:580px){header,main{padding:14px}#grid{grid-template-columns:repeat(2,1fr)}#hero{display:block}#hero img{max-width:280px}h1{font-size:26px}}
</style><header><small>星跃岛 / 造型选稿室</small><h1>20 款皮肤，每款 20 版实模初稿</h1><p>保留奶油色圆润画风，比较主题内的冠形、轮廓、裙型与配色。400 张图均由游戏模型真实渲染。</p><p>这是 5 种造型 × 4 组配色的参数化研究；金框表示这轮入选，点击任意图片可放大。</p><nav id="nav"></nav></header><main><section id="hero"></section><div id="filters"><h2 id="title"></h2><label><input type="checkbox" id="short"> 只看对比候选</label><a id="board">打开整页对比板</a></div><section id="grid"></section></main><dialog id="zoom"><button id="close">关闭</button><img id="large"><p id="alt"></p></dialog><script>
const DATA=__DATA__;let sid='eternal_dawn';const $=id=>document.getElementById(id);const unique=[...new Set(DATA.rows.map(r=>r.id))];
function pic(r){return 'renders/'+r.draft_id+'.png'}
function openImage(r){$('large').src=pic(r);$('large').alt=r.name+' 第'+r.number+'版';$('alt').textContent=r.name+' · '+r.number+' · '+r.palette_label+' / '+r.cut_label;$('zoom').showModal()}
function draw(){const rows=DATA.rows.filter(r=>r.id===sid),s=DATA.selections[sid],win=rows.find(r=>r.number===s.number);$('nav').replaceChildren();for(const id of unique){const r=DATA.rows.find(r=>r.id===id),b=document.createElement('button');b.textContent=r.name;b.className=id===sid?'active':'';b.onclick=()=>{sid=id;draw()};$('nav').append(b)}
$('hero').innerHTML='<img src="../couture/'+sid+'.png" alt="入选终稿"><div><small>'+win.price+' 金币 · 价格保持原值</small><h1>'+win.name+'</h1><h2>入选第 '+String(s.number).padStart(2,'0')+' 版</h2><p>'+s.reason+'</p><p>对比取舍：'+s.rejected+'</p><a href="../couture/'+sid+'_back.png">背面</a> · <a href="../couture/'+sid+'_angle.png">侧面</a> · <a href="../couture/'+sid+'_walk.png">走路</a> · <a href="../couture/'+sid+'_jump.png">跳跃</a></div>';
$('title').textContent=win.name+' · 20 版对比';$('board').href=sid+'-20.png';$('grid').replaceChildren();for(const r of rows){if($('short').checked&&!s.shortlist.includes(r.number))continue;const card=document.createElement('article');card.className='card'+(r.number===s.number?' chosen':'');const im=document.createElement('img');im.src=pic(r);im.loading='lazy';im.alt=r.name+' 第'+r.number+'版';im.onclick=()=>openImage(r);const c=document.createElement('div');c.className='caption';c.innerHTML='<strong>'+String(r.number).padStart(2,'0')+' · '+r.palette_label+'</strong>'+r.cut_label+'<br><i class="swatch" style="background:#'+r.color+'"></i><i class="swatch" style="background:#'+r.accent+'"></i>'+(r.number===s.number?'<span class="tag">入选终稿</span>':'');card.append(im,c);$('grid').append(card)}}
$('short').onchange=draw;$('close').onclick=()=>$('zoom').close();$('zoom').onclick=e=>{if(e.target===$('zoom'))$('zoom').close()};draw();</script></html>'''.replace('__DATA__',payload)
(D/'index.html').write_text(page)
print('Wrote review log and standalone gallery for 400 candidates.')
