# 沈砚收招源覆盖与独立动态审查 · 2026-10-21

当前状态：**right14 与新版front2在各自限定的独立动态审查中局部通过，已用两份独立来源接入生产缓存**。整体画面、完整动作和全部脚底动态验收仍未通过，不得混淆。

## 迭代与裁决

1. 原生产图集前向1→2过早收拢腿部，右向13→14过早转向正侧面。
2. 首轮独立两姿态源仅覆盖2/14，整源人体311→269统一nearest。动态审查通过right14的背侧肩胯朝向；拒绝旧front2的脸/发像素簇、圆亮裸肩造成的换人感。
3. 先撤掉旧front映射、仅保留right14。旧源PNG内仍有被拒front用于来源追溯，但loader不允许这个源映射2。
4. 用built-in image_gen生成新的单独front源，原生产atlas为脸/发/深蓝肩袖主参考，旧候选只参考弓步。PNG立即保存至docs/candidates/shen-front-recovery-v2，完整PROMPT.txt、SHA和状态随同保存。
5. 独立静态审查允许隔离试用。front_candidate_visual_review.gd只在测试实例cache[2]注入候选，按实际头到鞋底965→269统一nearest，源脚点418/1102。无头3动作通过，加载证据包含源SHA与脚底误差。
6. root实际GPU录制后，独立动态复核在n13-17看到脸/发/肩袖/腰带连续，没有旧圆肩换上半身的问题，批准新版front2局部启用。范围仅固定视角普攻：腿部部分被敌遮挡，不宣称完整脚底运动已验。

## 最终实现

- 生产shen_attack.png及shen_attack.json字节完全保留，其余14帧继续引用原同一源。
- right源shen_attack_recovery_overrides.png只能映射14，保留已审查311→269统一标定，不随front停用/启用改变比例。
- 新front源shen_attack_front_recovery_v2.png从已审候选原字节复制，独立metadata只能映射2。整源965→269得到366×334，与隔离GPU试用一致。
- _prepare_shen_attack_atlas分别加载两份metadata；同一个小helper通过固定已知image名→唯一合法index映射验证来源边界，不扩展成通用框架。
- 每个源只替换一张cache，统一body.pixel_size和原动作时钟保持不变；鞋底/横向支撑由实际源脚点和原步行参考计算，重复加载不累计偏移。
- 缺源/坏metadata拒绝该次可选替换，当前cache不被部分修改，另一已接受来源保留。旧右源不能启用被拒front，新front源不能覆盖right。
- 未改伤害、冷却、切换/倒地/闪避、存档或奖励。背向Q轨迹由root另行处理。

## 本轮验证

Godot4.5.2编辑器headless导入没有SCRIPT ERROR/Parse Error/ERROR。最终sh​​en_attack_checks.gd输出 **SHEN_ATTACK_CHECKS 86 failures=[]**。

检查包含原瞬发伤害与接触帧、动作时钟、切换/倒地/闪避/离场、坏原metadata回退，以及：原14帧仍引用原源、两个批准源归一尺寸、鞋底和步行支撑锚点、坏区域/零身高拒绝、旧右源映射2拒绝、新front源映射14拒绝、各自有效重载幂等且不覆盖另一帧。

命令：

```text
Godot_v4.5.2-stable_linux.x86_64 --headless --editor --path ember-town --quit
Godot_v4.5.2-stable_linux.x86_64 --headless --path ember-town --script res://tests/shen_attack_checks.gd
```

首次两姿态验证曾因像素float32舍入与1e-5像素阈值比较而失败；后来改成原测试同样的1e-5m世界单位阈值，未移动美术脚点规避误差。

原生产PNG：fb6e19cf840e9851cccb412d0589d4ddc1f59de937353baa7e751f99d5c5d8fe
原生产JSON：57470a5fda2e68895f8f5ad887b14a95c6090b85381ee3cfbe38d715ec6a8959

## 限制与交接

两处批准都是局部动态修复。新front色表偏暖/笔触平滑仍属后续整体美术精修风险；受敌人遮挡的腿部不能过度宣称通过。完整游戏、所有人物动作、整体参考图效果和Windows实机仍需独立验证。

本岗位仅运行无头检查。GPU与局部裁决来自root组织的实际取证/独立审查，本岗位未自行运行GPU、提交或推送。源文件已冻结供root最终验证与整合。

## 冻结 SHA-256

- ember-town/scripts/adventure_combat.gd: 6ab8e9f178c3aeb1095133a341086072786ca733eba5b743b0a3171d66d0f623
- ember-town/tests/shen_attack_checks.gd: 2ed65bddff021f626bc2d20e0780fc82d2179de1da32265aa3119828638fd536
- ember-town/assets/characters/shen_attack_front_recovery_v2.png: faf497af69be46f2a6067326b4d376e9047b7a5f3dde30e31edcfc5415000f7e
- ember-town/assets/characters/shen_attack_front_recovery_v2.json: 140ca1d08520528082f133d367b94802b6aa4f8d252a504694ccd53b9675df7a
- ember-town/assets/characters/shen_attack_recovery_overrides.png: dda41b3103c8d0f9a2daff8b23c7350e86b4050195d6f9156f90ed5080dfe190
- ember-town/assets/characters/shen_attack_recovery_overrides.json: 5d703b93d2a86889cf6ffb4baa458efb9fd9637a0d837d434105306fe030fe24
