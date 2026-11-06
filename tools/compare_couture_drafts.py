"""Build reproducible, renderable studies; selections come from visual review, not scores."""
from pathlib import Path
import json, re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/couture-drafts'
# Five within-theme constructions x four deliberate palettes for every purchasable skin.
PALETTES = {
'daisy': [('蜂蜜奶油','e8b957','fff3c6'),('杏桃白花','dd976d','fff1d9'),('青柠奶油','a9bd65','fff4c2'),('香槟雏菊','d8bf83','fffaf0')],
'mint': [('薄荷奶白','56b9a8','def4dc'),('森林邮局','518977','f2ddb4'),('鼠尾草','96ad92','faf0d4'),('海玻璃','62a9b4','d9eee5')],
'bunny': [('草莓奶糖','e991af','fff1e4'),('樱桃奶冻','ce6788','fce6de'),('蜜桃绒毛','eda894','fff0da'),('玫瑰豆沙','c58e9e','f5e4d4')],
'sailor': [('海盐蓝','649dcc','f5e9c9'),('海军珍珠','425d86','f9e1b4'),('碧湾浅蓝','73b6c5','fff2df'),('雾蓝金扣','859bb0','f7d588')],
'fox': [('枫糖','d88f58','ffddaa'),('赤狐','bf6645','f6d1a2'),('杏仁焦糖','d7a773','fff0d0'),('秋枫砖红','aa604b','f4c287')],
'witch': [('暮紫金','8872c7','f1c870'),('黑莓黄铜','6e4d81','ecc484'),('葡萄月银','927baa','dbdfec'),('靛夜月金','485584','f0d197')],
'pearl': [('浅海珍珠','66bfbf','ffe8d6'),('珊瑚海沫','68aaa2','f6c6b4'),('冰水蓝贝','7fbfd4','e7f1e8'),('碧玉贝母','4d9c8f','f7dfb9')],
'angel': [('薰衣草奶油','c5afd9','fff0ba'),('月白香槟','d8d6cf','e3bd74'),('杏云淡金','e3bcb5','f9e5b2'),('雪蓝白金','b7cfdf','f4ecd8')],
'astral': [('银河靛青','6469af','9ce8ed'),('午夜星尘','394b79','97d1e5'),('蓝紫星云','7665a2','b3dcec'),('黛青银光','3e7e92','d7ece4')],
'royal': [('极光紫金','a781ce','f8cf7c'),('紫藤香槟','bc9cc4','efd8a5'),('星夜紫冠','70548b','e4be77'),('月蓝金冠','759cae','f3d593')],
'rose_seraph': [('玫瑰香槟','e6a0b2','e7c77e'),('莓红金缎','c76b8c','ebc991'),('杏粉花冠','e8b19b','d9b267'),('豆沙玫瑰','bb8099','ead4ad')],
'moon_empress': [('冰川月白','b9d8ef','f6fbff'),('银蓝霜华','8aaccf','e5f5ff'),('冷月灰蓝','a8b7c6','f2ede1'),('白霜蓝玉','d5e3e9','9cbcdc')],
'glass_butterfly': [('兰紫水青','c05d9e','76e2d9'),('紫晶银蝶','9768bc','b2dfdf'),('莓紫琉璃','a43f7e','8edad1'),('暮蝶玫金','875dab','edc996')],
'phoenix': [('朱砂赤金','d45e46','f8cc58'),('绛红金翎','ad3b48','e5b55a'),('日落橘金','e58b42','f5dc96'),('珊瑚暖金','e68b77','f7c56c')],
'ocean_pearl': [('海沫珍珠','3dbbc1','f8dca6'),('深海碧玉','248c9c','f4cfb8'),('青瓷贝母','77bfae','fff0d6'),('蓝湾香槟','5eaccc','edd3a9')],
'sakura_deity': [('香槟樱雪','d9c07a','ef9cae'),('浅樱暖金','e3abc2','ebce98'),('玉青樱枝','a6c9ad','ecc0ca'),('杏乳花簪','e8c9a7','e598ad')],
'star_weaver': [('钴蓝星穹','354aa6','72d7ff'),('午夜银星','263854','badde8'),('紫夜星尘','594185','a8d5ee'),('深海星轨','286a86','b6edee')],
'platinum_dragon': [('钢铂祖母绿','aab7c5','5fce9d'),('冷铂翡翠','8e9ba9','b8ead1'),('象牙青玉','d1cdb8','75baab'),('暗银月玉','728691','c5e6dd')],
'jade_peacock': [('翡翠鎏金','16a98d','f0cb62'),('深碧金羽','197c72','ddb45e'),('孔雀宝蓝','287bab','e7c584'),('蓝绿银金','418f92','edd59e')],
'eternal_dawn': [('欧泊曙光','7862ad','f5d39d'),('杏金日出','b88166','f3d49b'),('绛紫日冕','694876','e8c181'),('月白欧泊','b8c3cf','e8c785')],
}
CUTS = {
'daisy':['单朵发夹','三花弧簪','双花高低','五花侧冠','单花蝴蝶结'],
'mint':['平檐贝雷','斜戴窄檐','丰顶软帽','宽檐斜帽','微斜小帽'],
'bunny':['直立软耳','短软耳','修长兔耳','外展软耳','收拢长耳'],
'sailor':['圆顶水手帽','窄帽檐','高圆帽顶','宽帽檐','收边小帽'],
'fox':['枫狐尖耳','短耳小尾','高耳长尾','宽耳蓬尾','收耳圆尾'],
'witch':['柔弯尖帽','矮顶小帽','高挑尖帽','宽檐大弯','反向弯顶'],
'pearl':['七瓣贝冠','五瓣收冠','九瓣高冠','宽贝冠','五瓣低冠'],
'angel':['舒展羽冠','小环收羽','宽羽光环','大环展羽','细环软羽'],
'astral':['斜星环','收拢平环','高斜星环','大斜星轨','反斜星环'],
'royal':['七晶金冠','五晶收冠','九晶高冠','宽翼七冠','五晶小冠'],
'rose_seraph':['五花层叠裙','七花花瓣裙','高花冠细褶裙','九花宽瓣裙','疏花晶褶裙'],
'moon_empress':['长弧月冕','收弧花瓣裙','大弧晶褶裙','短弧宽绸裙','细月波褶裙'],
'glass_butterfly':['舒展双蝶翼','收拢花瓣裙','高翼细褶裙','宽翼大瓣裙','窄蝶波褶裙'],
'phoenix':['七翎层裙','九翎瓣裙','五翎细褶','十一翎宽裙','七翎波褶'],
'ocean_pearl':['九瓣贝冠','七瓣收冠','十一瓣高冠','九瓣宽冠','五瓣疏冠'],
'sakura_deity':['四花双樱枝','收枝花瓣裙','高簪细褶裙','五花宽枝裙','疏枝波褶裙'],
'star_weaver':['十二星层裙','八星花瓣裙','十星高轨裙','十六星宽轨','七星细褶裙'],
'platinum_dragon':['舒角三鳞甲','低角花瓣甲','高角四鳞甲','展角宽裙甲','收角细褶甲'],
'jade_peacock':['十一翎圆屏','九翎窄屏','十一翎高屏','十三翎宽屏','七翎疏屏'],
'eternal_dawn':['十一芒欧泊裙','九芒收冠裙','十三芒高冠裙','十五芒宽冠裙','七芒莲瓣冠'],
}

def catalog():
    s=(ROOT/'scripts/skin_style.gd').read_text()
    return [json.loads(m.group(0)) for m in re.finditer(r'\{"id"[^\n]+\}',s) if '"price":0' not in m.group(0)]

def build():
    OUT.mkdir(exist_ok=True)
    candidates=[]
    for skin in catalog():
        sid=skin['id']
        for pi,(label,base,accent) in enumerate(PALETTES[sid]):
            for ci,cut in enumerate(CUTS[sid]):
                data=skin.copy()
                n=pi*5+ci+1
                data.update(draft_id=f'{sid}_d{n:02}',number=n,palette_label=label,cut_label=cut,color=base,accent=accent,cut=ci)
                if sid=='eternal_dawn': data['opal']=['9ce8df','bbdcd1','a9dcce','baabe3'][pi]
                candidates.append(data)
    (OUT/'candidates.json').write_text(json.dumps(candidates,ensure_ascii=False,indent=2))
    print(f'{len(candidates)} renderable design candidates; no automatic beauty scores.')
if __name__=='__main__': build()
