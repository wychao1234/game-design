# 源码恢复与 Git 迁移

更新：2026-10-21（Asia/Shanghai）。

**本轮已恢复执行环境、校验并导入 v4 源码，工程位于 `ember-town/`。** 原归档仍用于灾后恢复；正常开发以 Git 提交与 PR 为准。导入清单见 [SOURCE_IMPORT.json](SOURCE_IMPORT.json)，本轮测试见 [验证记录](verification/2026-10-21-import/README.md)。不得用旧 v2 替代最新精修。

## 最近检查点

| 文件 | 保存标识/版本 | 大小 | 状态 |
| --- | --- | --- | --- |
| linchuan-polish-checkpoint.zip | libfile_6128829fba148191b3075fa0dd253910 / v4 | 189,817,782 bytes | 最近源码；历史 CRC 通过，340 文件；工程根 ember-town/ |
| godot452-runtime-ubuntu2404-x64.tar.gz | libfile_b75c665e85fc8191a79a6861b0d64a65 / 初始版本 | 155,877,781 bytes | 固定引擎与离线运行恢复材料；不提交到 Git |
| loot-visual-restored-bundle.zip | libfile_79e663dd27288191aa7df03682f91086 / 初始版本 | 10,587 bytes | 掉落相关三个源文件的单独补充 |
| shen_attack_recovery_candidate2.png | libfile_63e1252ccfa8819192f61679841e5dbf / 初始版本 | 1,599,829 bytes | **已拒绝**，frame13 刀身串入 frame14，不能接生产 |
| shen_attack_recovery_overrides.png | libfile_fcf01ed19e9481918c13ba7fc0c4f40e / 初始版本 | 308,515 bytes | 独立两姿态候选；标定/元数据/动态验收待做；不保证进入 v4 |

保存标识用于后续会话检索，不是公开下载地址。不要把短期签名下载 URL 写进仓库、PR、Actions 输入或日志。

旧 `linchuan-preview-source.zip`、Windows 预览、说明、截图、视频和 RELEASE_CHECKS.json 属于较早 v2 交付，不能当作 v4。

## 已记录的 SHA-256

本轮已校验 v4 ZIP CRC、340 个归档成员及关键源码字节；完整迁入成员逐项校验。v4 ZIP SHA-256 为 `76665b1ac2ba51dac7ee430f1e61bfe63d69bd86cd7d8b7c59238ce75981526b`。下表为恢复基准哈希，后续精修文件会另有新提交，不能把恢复哈希当作永远不变的当前 SHA。

| 文件/成员 | SHA-256 |
| --- | --- |
| runtime tar.gz | 1256fc326340b5986ecd0653bbc84d403db1294c8a57e848154ca52c69550513 |
| 规范 Godot 引擎二进制 | 5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae |
| loot-visual-restored-bundle.zip | 69cfda98a7be128b11acef2f1e596ec91fb618cc1ce68082a644ef9bf1c74f12 |
| ember-town/scripts/adventure.gd | 9eb99b345e933fcc729911f36033a4cf1fbc440e7078091acfe0a3640e538b14 |
| ember-town/scripts/adventure_combat.gd | 0039ef7d7349f980833a333d50727b640477b264219018a51e6e8d51ce321298 |
| ember-town/scripts/waterfront.gd | c4ea3e95ba8a3db0945084e31d3a44f1142c0b0c4b43530006c2175d2329486f |
| ember-town/assets/environment/waterfront_wetwood.gdshader | 6f729671220fcf59ca748028d6fb6e41fc652b7fea1d907d7ec55c9e6291c3b5 |
| 生产 shen_attack.png | fb6e19cf840e9851cccb412d0589d4ddc1f59de937353baa7e751f99d5c5d8fe |
| 生产 shen_attack JSON | 57470a5fda2e68895f8f5ad887b14a95c6090b85381ee3cfbe38d715ec6a8959 |
| 已拒绝 candidate2 PNG | f3d89c59adf160cfac85f14c2cd4dd5862190baeaa58955f1adee945460bcf92 |
| 独立 overrides PNG | dda41b3103c8d0f9a2daff8b23c7350e86b4050195d6f9156f90ed5080dfe190 |
| 掉落 shader | ced92164f33b891f40be26d6b60f69c7316549d30226e9cd027169a555de7acb |
| tests/loot_visual_fixture.gd | 60c95135f7364aa25167a39caff768be96268ba4a974329e656a6c11011a4d55 |

## 恢复步骤

1. 获取明确 v4 的保存文件和单独 overrides，不根据旧文件名猜版本。记录整包 SHA 与大小。
2. 解压前校验 ZIP CRC，拒绝绝对路径、上级路径穿越和越界链接；展开到独立目录，不能覆盖正在工作的仓库。
3. 检查关键成员哈希、工程入口、资产、测试、参考图和证据清单。差异先查原因，不直接覆盖正确文件。
4. 恢复固定运行时。仅按运行时清单复制文件；离线 GUI 需要对应 Xvfb/Mesa 依赖，不能因 headless 可用就说 GUI 可用。此前使用 TCP-only Xvfb 以适应 Unix socket 限制。
5. 查询真实 project.godot 与构建脚本后决定启动命令；先 Godot 编辑器导入与解析，再执行相关测试并扫描错误。
6. 以独立测试 profile 启动 adventure.tscn；确认 Mesh/MultiMesh、环境和灯光存在，进行短实际渲染。保留 main.tscn/game.gd 与 ember_save.json。
7. 建迁移分支，复制必要源码、场景、.uid、原创 PNG/音频、原始导入设置、测试、设计与参考。保留需复现导入的 .import 配置，不带 .godot/ 生成缓存。
8. 核对 Git 文件清单与大小，排除运行时、导出、存档、总 ZIP 和无关临时文件。大文件逐个决定，不整体扔进 Git。
9. PR 记录来源版本/哈希、迁入与未迁入清单、导入/启动/测试结果；自审与合并后再把工作总账 MIG-01 改为完成。

## 重要工程参数与操作

- Godot 4.5.2 Standard / Forward+ / GDScript，新入口 adventure.tscn。
- 当前相机：26° 轻透视；VIEW_FOCUS=(-1,0,-2)，VIEW_OFFSET=(8,14,24.5)，基础位置 (7,14,22.5)，人物视觉尺度 1.1。旧 orthosize=13 是遗留诊断数值，不是当前投影。
- 跟随 x×0.4 限 ±4，z×0.45 限 ±2.9，平滑 3.2。
- WASD 移动，鼠标瞄准，左键普攻，Q/E/R/F 技能，X 觉醒，1/2/3 或 Tab 换人，Space 闪避。
- T 城镇交互/战后返回，I 背包，M 地图，P 队伍；Esc 先取消预览、关面板，再暂停。战斗背包仅查看。
- 新存档 linchuan_preview_v2.json；旧 ember_save.json 不动；任何 fixture 使用绝对隔离路径。

## 候选与生产资产边界

生产攻击图仍有正面与右向收招缺陷。candidate2 即使与 v4 一起保存，也不是生产资产。独立 overrides 只覆盖前向 recovery frame2 与右向 recovery frame14；需核实源尺寸、脚点、统一人体尺度、metadata，再做正常速度和原生帧评审。

图集 16 帧并非可任意等宽等高分格。不能对整套正确 14 帧重新生成，不按含武器包围盒逐帧缩放，不滑动整个人遮盖姿态断裂。未完成上述验证前，不替换生产映射。

## 2026-10-21 本轮迁移

已恢复 4.5.2 固定运行链，并本轮实际完成预览 11 阶段和旧矿洞 9 阶段检查，Forward+ 渡口基准帧写出成功；这不构成整体美术通过。归档中大量隐藏日志暂存副本与重复 AVI 被排除，拒绝的收招候选没有迁入生产。已有原始设计文档含旧矿洞状态，均按历史记录解释，以根工作总账为准。


源码迁移 PR #2 已合并并核对 main 内容树；今后以 Git 为正常续作入口。当前运行字体为与原默认face0一致的无损WOFF2，原TTC仅作归档恢复；字体对照记录见 verification/2026-10-21-import/font-conversion.json。新精修提交的源码哈希会不同于恢复基准，不应为了匹配旧哈希覆盖已审通过的修改。
