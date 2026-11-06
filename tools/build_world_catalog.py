"""Expand the authored 12-world campaign with 38 distinct, fixed course plans.
Route tokens are compass directions and counts; no runtime random generation.
"""
import json, math, re
from pathlib import Path
p=Path('scripts/campaign.gd'); text=p.read_text()
a=text.index('[')
end_match=re.search(r'\n\]\s*\n', text[a:])
assert end_match is not None, 'Missing LEVELS closing bracket'
b=a+end_match.start()+2
levels=json.loads(re.sub(r",\s*([\]}])",r"\1",text[a:b]))[:12]
# name / environment / authored route / signature mechanics / briefing
specs=[
('向日葵风车岭','windmill','N2 NE3 E2 N3 NW2 N3','belt,ferry','沿风车山脊绕过花田，传送带会把你推向侧边。'),
('珊瑚珍珠礁','coral','N2 NW2 W2 N3 NE4 N2 E2','ferry,ice','在珊瑚群之间寻找珍珠浮台，注意湿滑的落脚点。'),
('蜂蜜六角谷','honey','N2 NE2 E2 NE2 N2 NW2 W2 N3','crumble,belt','蜂巢石板会下沉，沿六角形转折连续跳跃。'),
('纸飞机图书馆','library','N3 E3 N2 W2 NW2 N2 E3','lift,crumble','搭升降书页穿过书架，离开裂纹书页时不要犹豫。'),
('瀑布双拱桥','waterfall','N2 NW3 N3 NE3 N2 NW3 N2','ferry,wind','沿两段瀑布拱桥折返，留意桥面侧风。'),
('玻璃温室','greenhouse','N2 E3 N4 W3 N2 NE2 N2','ice,crumble','温室湿滑的玻璃台与脆弱踏板交错，提前停步。'),
('海盗沉船湾','pirate','N2 NE2 E3 N2 NW4 N2 W2','ferry,fire','穿过桅杆和船舷，等炮口熄灭再跳上渡台。'),
('棉花糖曲奇镇','candy','N2 W2 NW2 N2 E4 N3 NE2','spring,crumble','棉花糖弹簧通往饼干屋顶，脆饼平台很快会碎。'),
('红叶鸟居山','shrine','N2 NE4 N2 NW2 W2 NW2 N3','wind,crumble','沿红叶山路穿过鸟居，收齐钥匙再去山顶。'),
('音乐盒舞台','music','N2 E2 NE2 N2 W3 NW2 N3 E2','lift,belt','跟着升降舞台的节奏前进，留意横向移动的琴键。'),
('热气球航站','balloon','N3 NW2 N2 E3 NE2 N2 W3','lift,wind','乘吊篮升空，再迎着风走过气球之间的悬台。'),
('玉石莲花池','lotus','N2 NE3 E2 N2 W4 N2 NW2 N2','ice,ferry','莲叶旁的玉石很滑，移动小舟是安全的过渡点。'),
('琥珀化石谷','fossil','N2 W3 N2 NE4 N2 E2 N2 NW2','crumble,wind','穿行巨兽骨架，避开风口和开裂的化石台。'),
('极地冰帆港','igloo','N2 NW2 W2 N4 E4 N2 NW3','ice,ferry,wind','冰屋、帆船和浮冰之间，提前减速并看准渡台。'),
('熔岩铸剑台','anvil','N2 E3 N2 NW4 N3 NE2 N3','fire,belt,crumble','锻炉会轮流喷火，传送带把你送向开裂铁台。'),
('萤光蘑菇湖','biolume','N3 NE2 N2 W4 N2 NE3 E2 N2','spring,ferry','借发光弹菇越过湖面高差，再搭蘑菇浮台。'),
('沙漠星象仪','astrolabe','N2 NW3 W2 N2 E4 NE2 N2 NW2','lift,fire','攀升星象环，避开日照喷口，寻找出口钥匙。'),
('蒸汽火车站','train','N3 E4 N2 W2 NW2 N3 E2 N2','belt,fire,ferry','顺着铁轨转到站台另一侧，等待蒸汽间歇。'),
('钟乳石回声厅','stalactite','N2 NE2 N3 NW4 N2 E3 N2 NW2','crumble,ice','洞顶钟乳石指引折返，冰石和裂纹台越来越窄。'),
('樱花水车坊','sakura','N2 W2 N2 E4 NE2 N2 W3 N3','ferry,belt,wind','借水车渡台过溪，风口和水带会改变落点。'),
('霓虹电路城','neon','N2 E3 N2 W4 N2 E3 N3 NE2','fire,lift,ice','沿电路折线攀升，闪光警告后能量喷口会启动。'),
('翡翠巨树冠','treetop','N2 NW2 N2 NE4 E2 N2 W4 N2','spring,crumble,wind','弹上巨树枝冠，连续通过脆弱枝台和树顶风场。'),
('风筝彩带谷','kite','N3 NE3 N2 NW4 N2 NE3 N2','wind,ferry,crumble','彩带路线左右起伏，看准风中的移动平台。'),
('陶瓷茶壶村','teapot','N2 W3 N2 E4 N2 W2 NW2 N3','lift,fire,belt','茶壶间的升降杯托连接高台，提防茶炉喷口。'),
('月兔胡萝卜园','carrot','N2 NE2 E3 N2 NW4 N2 E3 N2','spring,ice,crumble','弹跳越过菜畦，湿滑石台后紧接脆弱落脚点。'),
('深海水母宫','jellyfish','N2 NW3 N2 E4 N3 W2 N2 NE2','ferry,wind,lift','水母灯照亮三层宫殿，等待升降台与浮台接近。'),
('黑曜石火山口','volcano','N3 E2 NE2 N3 W4 N2 E2 N2','fire,crumble,wind','绕火山口走一圈，喷口、裂石与热风连续出现。'),
('浮空棋盘阵','chess','N2 E4 N2 W4 N2 E3 N2 W2 N2','crumble,lift,ice','沿棋盘折返到王座，升降棋格与裂纹格交替。'),
('星沙漏回廊','hourglass','N2 NW4 N2 E4 N2 NW3 N3','crumble,fire,ferry','沿沙漏两翼快速转移，渡台连接开裂的回廊。'),
('彩虹玻璃工坊','prism','N2 NE3 E2 N2 W4 N3 NE3 N2','ice,fire,lift','棱镜映出阶梯方向，在玻璃和能量炉间找落脚点。'),
('磁力卫星港','satellite','N3 W3 N2 E4 N2 NW2 N2 E2','lift,wind,ferry','卫星升降台送你上行，风场会推偏短距离跳跃。'),
('黄金龙骨桥','dragon','N2 E3 NE2 N3 W4 N2 NE2 N3','spring,fire,crumble','跃过龙脊高台，在喷火间隙通过易碎的骨桥。'),
('深蓝旋涡塔','vortex','N2 NW3 N3 E4 N2 W3 N2 NE2','wind,ice,ferry','绕着旋涡攀升，湿滑平台与横风需要一起应对。'),
('彗星晶矿带','meteor','N3 NE2 E3 N2 NW4 N3 E2 N2','crumble,lift,fire','在陨石矿带寻找星钥，升降矿台之后立即接喷口。'),
('极光天空花园','aurora','N2 W3 N3 E4 N2 NW3 N3 E2','ice,wind,spring','沿极光下的花圃攀升，弹跳后要修正风中的落点。'),
('太阳能量核心','solar','N3 E4 N2 W3 N3 NE3 N3','fire,belt,lift','核心喷口的间隔更短，利用升降环和传送带前进。'),
('时空折叠之门','portal','N2 NW4 N3 E4 N2 W3 N3 NE2','lift,crumble,wind,fire','穿过层层时空环，在移动与坍塌之间保持节奏。'),
('万象星冠终章','crown','N3 E4 N3 W5 N3 E4 N3 NW3 N3','spring,fire,ferry,wind,crumble,lift,ice,belt','最后的星冠长路：集齐三把钥匙，综合所有机关登顶。'),
]
assert len(specs)==38
palettes=[['80aa70','e1d7ae','596754','669ca0','dce9ca','f4c96c'],['63bdb2','f1ceb9','416478','31587c','9bd5d7','fa9e90'],['dca54d','fff0ae','865435','ac8267','f4d6a3','a9e0b4'],['69759d','d9c8a5','34394c','435576','a0bec7','efbf78'],['629f9d','d2ebe6','426c76','497e9d','b6d9e7','83d9e0'],['70a894','dfedcb','4f685e','71948a','dbe9c4','edb66c'],['957d57','d4bc7b','3a515f','536675','a4b8b6','de8766'],['d8a0b0','f4ddb0','946d7b','9985b0','f0d4da','98dacf'],['b77b5d','e8bc89','624842','656985','d6c3b4','d76055'],['667891','eac990','334858','625875','bfc1d2','eeae66']]
def route_from(tokens, rank):
    dirs={'N':(0,-1),'NE':(1,-1),'E':(1,0),'NW':(-1,-1),'W':(-1,0)}
    points=[[0,0,4]]
    for name, count in re.findall(r'(NW|NE|N|E|W)(\d+)',tokens):
        dx,dz=dirs[name];norm=math.hypot(dx,dz)
        for _ in range(int(count)):
            i=len(points); step=6.0+(rank-12)*.015+.12*math.sin(i*1.6+rank)
            # Low terraces interspersed with flat run-ups. Every plan is fixed.
            rise=.18+(rank-12)*.004 if i%4 else .35
            if i%7==0: rise=-.3
            x,y,z=points[-1];points.append([round(x+dx/norm*step,3),round(y+rise,3),round(z+dz/norm*step,3)])
    return points
for offset,(name,theme,plan,mechanic_text,hint) in enumerate(specs):
    rank=offset+13
    route=route_from(plan,rank)
    n=len(route); checkpoint=n//2
    mechanics=mechanic_text.split(','); features={}; springs=[]
    # Denser sequences are introduced chapter by chapter, with a safe spawn,
    # checkpoint, landing after spring/lift, and a broad final island.
    candidates=[i for i in range(2,n-2) if i not in [checkpoint,checkpoint-1,checkpoint+1]]
    desired=min(len(candidates),5+offset//5)
    ordered=sorted(candidates,key=lambda i: ((i*7+rank*3)%n,i))[:desired]
    ordered.sort()
    last=-10
    for j,index in enumerate(ordered):
        mech=mechanics[j%len(mechanics)]
        if mech in ['spring','lift'] and (index-last<=1 or index+1 in ordered):
            mech=next((m for m in mechanics if m not in ['spring','lift']), 'ferry')
        if mech=='spring': springs.append(index)
        else: features[str(index)]=mech
        if mech in ['spring','lift']:
            rise=3.0 if mech=='spring' else 2.45
            old=route[index+1][1]-route[index][1]
            for k in range(index+1,n): route[k][1]=round(route[k][1]+rise-old,3)
        last=index
    # Ensure signature mechanics appear, even when the dense selection skipped a lift.
    for mech in mechanics:
        if mech=='spring' and springs: continue
        if mech!='spring' and mech in features.values(): continue
        eligible=[i for i in candidates if i not in springs and str(i) not in features and i-1 not in springs and features.get(str(i-1))!='lift']
        if mech in ['spring','lift']: eligible=[i for i in eligible if i+1 not in springs and str(i+1) not in features]
        if not eligible: continue
        index=eligible[len(eligible)//2]
        if mech=='spring': springs.append(index)
        else: features[str(index)]=mech
        if mech in ['spring','lift']:
            rise=3 if mech=='spring' else 2.45;old=route[index+1][1]-route[index][1]
            for k in range(index+1,n):route[k][1]=round(route[k][1]+rise-old,3)
    safe=[i for i in range(1,n-1) if i not in springs and features.get(str(i),'normal') in ['normal','ice','belt','wind'] and i!=checkpoint]
    target_enemies=5+offset//10
    enemies=[safe[round(k*(len(safe)-1)/(min(target_enemies,len(safe))-1))] for k in range(min(target_enemies,len(safe)))]
    # Keys only sit on safe permanent islands and never require a disappearing pad.
    key_count=3 if rank>=40 else (2 if rank%3==1 else 0)
    key_pool=[i for i in range(2,n-2) if i not in springs and features.get(str(i),'normal') not in ['lift','ferry','crumble','fire']]
    keys=sorted(set(key_pool[round((k+1)*(len(key_pool)-1)/(key_count+1))] for k in range(key_count))) if key_count else []
    pal=palettes[offset%10].copy()
    # Different ambience per world; landforms and landmark geometry are independent.
    if theme in ['biolume','neon','jellyfish','vortex','satellite','meteor','portal','crown']:
        pal[3]='19253e';pal[4]=['526985','636085','426e79','655b83'][offset%4]
    levels.append(dict(name=name,theme=theme,hint=hint,route=route,features=features,enemy_nodes=enemies,key_nodes=keys,spring_nodes=sorted(springs),width=round(4.4-(offset+1)*.026,3),time=420.0,checkpoint=checkpoint,palette=pal,course_plan=plan,mechanics=mechanics,difficulty=rank,enemy_speed=round(1.44+offset*.021,3),moving_period=round(4.75-offset*.025,3),crumble_delay=round(.94-offset*.007,3),hazard_rate=round(1+offset*.011,3)))
for i,l in enumerate(levels[:12]):
    l['difficulty']=i+1;l['enemy_speed']=round(.7+(6.2-l['width'])*.4,3);l['moving_period']=4.8;l['crumble_delay']=.95;l['hazard_rate']=1.0
assert len(levels)==50
assert len({str(l['route']) for l in levels})==50
# Emit compact readable fixed arrays, preserving the existing save API.
lines=['extends Node','','# Fixed, authored routes. Each coordinate is a walkable platform top.','const LEVELS := [']
for l in levels:
    lines.append('  {')
    items=list(l.items())
    for j,(k,v) in enumerate(items): lines.append('    '+json.dumps(k)+': '+json.dumps(v,ensure_ascii=False)+(',' if j<len(items)-1 else ''))
    lines.append('  },')
lines.append(']')
p.write_text('\n'.join(lines)+text[b:])
Path('docs').mkdir(exist_ok=True)
Path('docs/level-design.json').write_text(json.dumps(levels,ensure_ascii=False,indent=2))
print('Authored worlds:',len(levels),'route segments:',sum(len(l['route'])-1+6 for l in levels))
