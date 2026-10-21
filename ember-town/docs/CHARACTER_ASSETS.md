# 角色与敌人运行时图集

2026-10-16，当前恢复版。内置imagegen生成，真实透明PNG；不从战斗概念图抠图，不用Python绘制人物。Python只分析alpha边界、写JSON，PNG像素未修改。

## 恢复经过

早先四角色与敌人图集在临时环境回滚后丢失。原`generated_images`输出路径不可用，函数会话缓存消失；按原始确切文件名和角色/图集内容查询，未找到已自动提交的源图。库存中游戏相关图片仍是较早的战斗概念图与旧矿井角色。因此当前五张是沿既定人物规范**重新生成的恢复版**，并非取回旧图或保持旧SHA。旧图的裁格、主体高度和首领重复帧记录不适用于当前版。

## 已交付文件

| 图集 | 识别特征 | 行序 | 实际row_edges | 每行最大主体高度 |
| --- | --- | --- | --- | --- |
| shen.png | 黑发、炭蓝短衣、浅腰带、赭红左臂、单刃刀 | 正面/背面/左/右 | 0,313,622,931,1254 | 290/292/292/293 |
| jiang.png | 深发、宽肩旧甲、土黄布、长枪 | 正面/背面/左/右 | 0,321,610,915,1254 | 287/279/289/279 |
| zhu.png | 米白浅青、短披帛、朱符、手铃 | 正面/背面/左/右 | 0,310,619,925,1254 | 288/285/281/285 |
| lu.png | 深紫灰紧袖、铜器、短弓、箭匣 | 正面/背面/左/右 | 0,315,624,925,1254 | 287/291/278/281 |
| foes.png | 短刃纸傀/举符远程/铁钩精英/巨钩长链舟主 | 近战/远程/精英/首领 | 0,317,611,910,1254 | 240/255/270/293 |

路径均在 `assets/characters/`，每图有同名JSON；`originals/<name>-generated.png`保留原图副本。每张1254×1254 RGBA、16个独立源帧，总计80帧。当前恢复版没有排除帧或重复替代帧。敌人每行是同类型四个正面偏左的步行/待机姿态，并非四方向；左右镜像只供当前代表流程使用。

## 图集读取契约

生成器没有精确执行数学等高4×4格子。**必须按JSON每帧`region`读取AtlasTexture，不能直接hframes=4/vframes=4。** `grid:[4,4]`是逻辑布局，`cell_width/height`是名义尺寸。`row_edges`、`column_edges_by_row`取自实际透明间隙，允许各格不等宽高。

`frames`共16项，每项包含：

- `index,row,column`：逻辑动画索引。
- `region:[x,y,width,height]`：原图中的实际区域。
- `bbox:[x,y,width,height]`：区域内alpha严格大于80的主体。
- `foot_x`：主体包围框水平中心；`foot_y`：底边exclusive坐标。
- `touches_cell_boundary`：当前全部false。

JSON另含PNG SHA-256、尺寸、各行最大主体高度、播放建议FPS与排除记录。不要让alpha1/2的轻微噪声影响脚底识别。PNG最近邻采样，世界高度按角色分别校准；长枪高度不等于人物身高。

Godot Sprite3D的offset还取决于centered状态与Y轴约定；工程当前按centered=false使用 `(-foot_x, foot_y-region_height)`，不是把图像Y向下坐标直接当世界Y向上坐标。镜像时水平锚点需要相应改变为 `foot_x-region_width`。同方向`foot_x`可取中位数减轻武器包围框变动引起的横跳，`foot_y`逐帧对齐。应以实际渲染结果确认，不能由静态元数据宣称脚滑已消除。

## 检查与限制

80个运行时region已进行alpha>80主体边界检查，全部有主体且不碰裁格边界。五张RGBA透明图、JSON尺寸、帧数和PNG SHA需要随打包保留。以上是素材检查，不是游戏帧率或战斗动作验收。

我方四图只包含四向步行预览，没有独立普攻、技能、闪避、受击、倒地、换人或觉醒动作；敌图亦没有投掷、挥钩、破势或死亡动作。当前程序特效叠加站姿属于占位演出。生成姿态前后转面的衣饰、头身比例和持械细节存在差异，后续制作正式动作前需锁定源像素密度与不对称设计；不能任意镜像沈砚缠臂来替代方向。像素风图集尚未变成手工量产标准，不按这五张估算完整36技能成本。

## 生成来源与提示词

全部使用内置image_gen，`transparent_background=true`，每资产一条独立生成请求，未使用CLI/API回退。恢复版没有视觉编辑或图像重绘步骤。

| 当前资产 | 生成器实际输出文件 |
| --- | --- |
| shen | exec-9ea4ee51-d67b-4a02-9eec-e2f29c0c1cbe.png |
| jiang | exec-1929f8a2-046d-4961-9602-862a62c481ab.png |
| zhu | exec-5a35bd2f-4e4f-4796-ab7b-f07e9fae807a.png |
| lu | exec-110822bf-580b-40a3-b8da-0ad372375cf7.png |
| foes | exec-3f212852-637e-468a-a615-77888f6f7b12.png |

共同提示规范：production RPG runtime sprite atlas；square genuine transparent PNG；exactly four columns and four rows；16 fullbody isolated sprites；front/back/left/right rows for party；four walking steps per row；same scale；feet aligned per cell；character including weapon max65percent cell height/width；generous transparent margins；fixed elevated three-quarter view；detailed crisp16bit pixel clusters/dark outline；three-head-tall adult proportions；no floor/shadow/text/grid/FX/UI/scenery。

人物提示：沈砚为black tousled hair, short charcoal navy-blue Chinese coat, ivory waist sash, rust-red wrapped anatomically LEFT forearm, single-edged sword in right hand。江照野为broad shoulders, dark tied hair, worn gray iron guard armor, muted ochre waistcloth, long spear upright with complete tip inside cell。祝听澜为dark brown half-tied hair/teal ribbon, lively confident face, ivory/light celadon layered clothes, short shoulder scarf, vermilion talismans, bronze handbell, no sword/pet/summon。陆惊弦为high practical dark ponytail, deep purple-gray tight-sleeve tunic, short divided coat tails, bronze mechanisms, compact mechanical shortbow, narrow arrow case, no sword/crossbow/gun。

敌人提示：four DIFFERENT enemy types one perrow, each row four walk/idle frames facing front threequarter toLEFT；worn rustred/dirtybrown/black；row1 slim torn-strawhat masked bandit with short crooked blade；row2 hooded ranged thrower raising vermilion papers and bronze disk, no blade/spear；row3 stocky oldarmor iron-hook enforcer；row4 hulking Tidebound Boatmaster with cracked horned white mask, ropes, torn red sash, gigantic hook and compact coiled longchain；complete hook safely inside eachcell, extra outermargin；no ground/shadow/water/text/UI/grid。生成仍未严格匹配间距，因此以实际region和成图检查为准。
