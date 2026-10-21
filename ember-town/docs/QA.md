# 临川代表试玩验证记录

本轮入口为 `adventure.tscn`。新版城镇、选关、渡口三波、独立舟主三阶段、四角色轮换及成长需要独立验证。下方矿井样板的历史通过数量不能视为新版通过数量。

## 当前验证依据

- 新版自动检查：`python tests/run_preview_qa.py --engine /absolute/path/to/Godot`。
- 新版命令、退出码、断言和源码 SHA256：`tests/preview_evidence/summary.json`。没有对应结果的项目视为待验，不能仅凭本文标记通过。
- 旧矿井回归：`python tests/run_qa.py --engine /absolute/path/to/Godot`，应明确加载旧 `main.tscn`。
- 逻辑检查、引擎实渲染截图、资源导出/包加载、真实 Windows 启动分开记录。
- Windows 目标机执行未验证；实体显卡性能未验证。云端 llvmpipe 软件 Vulkan 截图只能证明当前状态能够产生画面。

## 视觉修订v2的独立自动回归：2026-10-16

场景、正式镜头、人物照明、HUD绘画图标恢复并统一导入后，独立QA重新完整运行，未沿用v1或恢复前的通过记录。最终执行时间为北京时间 **2026-10-16 19:41:11**（UTC `2026-10-16T11:41:11.265190+00:00`）。固定引擎为 `4.5.2.stable.official.6ce3de25a`，版本检查、编辑器导入及9个行为用例共11阶段全部成功；**151条断言全部通过**，没有脚本、解析或引擎错误。这是本版本的功能检查，不是概念图画面质量通过证明。

| 用例 | 断言数 | 实际验证范围 |
| --- | ---: | --- |
| progress | 25 | 真实20趟清关、首通与合法重刷、重复奖励拦截、兑换、职业装备约束、锁定与保护、去重拆解、失败所得保留 |
| save-write | 3 | 新进程真实获得首通机制武器、装备、保存编队 |
| save-read | 3 | 另一引擎进程恢复已获材料、装备、编队，丢弃过期战斗状态 |
| recover-main | 3 | 损坏主档从有效备份恢复，保存后主档与备份仍有效 |
| protect-corrupt | 2 | 双损坏停用保存并保留两个原文件 |
| combat | 66 | 四角色普攻、16技能、4觉醒的真实效果与冷却；离场计时、共享资源、多目标产能上限、防御减伤、三波渡口、三阶段独立舟主 |
| effects | 15 | 后台召唤归属与寿命、不产能、来源倒地清理、全队倒地、同源替换、队友场地保留，以及四把机制武器的实际打法变化 |
| collision | 4 | 同一攻击隔墙失败与无遮挡成功、突进受墙阻挡、投射物被墙截断 |
| integration | 30 | 实际GUI点击选关、回城、独立首领与重试；面板暂停、防鼠标穿透、Esc预览优先、胜败保存、真实装备效果、HUD中文字体及四技能文字 |

GUI按钮通过 `Viewport.push_input` 的实际坐标命中调用，物理按键/鼠标状态通过注入事件并刷新后核对。多数战斗检查为生产动作接口与隔离状态夹具，并非人工完成全关的操作记录。所有存档及数据目录位于一次性的 `linchuan-preview-qa-` 临时目录，未读取或改写正式用户存档。第二进程读档、主/备份损坏检查使用真实磁盘文件。

最终被测源码 SHA256、每条命令、退出码、耗时和分项结果全部记录于 `tests/preview_evidence/summary.json`。其中主控为 `97f5cc3ddd97980b6f7b6ce4996fee898e973951c9e9979558ec9c7b8223efb8`，战斗为 `77a0c6784eb1daa9bec9be7d51ddf2922cf3c40d3c103aa9894c30b5ff9e9db2`，HUD为 `b7be53f81ccfd553473e0ed4f05ceafa374c7b9f3ea5182fc2f66961f60211ee`，世界为 `451dd858c0965d70793f616256313817a113f1b24f281f4a2b4492fa782b9d8c`。修改后须按受影响范围重新验证，不能将这次通过自动沿用到其他源码版本。

本轮画面使用真实引擎Forward+与云端软件Vulkan产生，不是概念图。它证明该云端渲染路径可产生画面，不证明实体显卡帧率、长时稳定性或人工操作手感。**Windows EXE/PCK导出与文件检查不等于Windows实际启动；本轮没有Windows目标机运行或用户GPU性能通过结论。**

`tests/preview_evidence/screens/`与 `independent-ferry.png/log` 是v1历史实机证据，不能当作视觉修订v2的新画面。v2固定渡口帧另存于 `tests/preview_evidence/visual-v2/art-world-final.png`，阶段独立美术判断详见 `tests/preview_evidence/art_review_v2.md`。新版已经实见远岸分簇屋舍／水隙、船体／系缆、错缝旧木与夜雨冷暖反射，主角／四敌、薄血条和蓝色绘画技能图标可辨。整体结论是“明显更接近目标的视觉修订”，仍未达到最初概念图的最终手工精致度；不能把固定摆位图冒充完整人工游玩或全部首领招式验收。

## 视觉修订的专项证据

以下是本轮各工程师执行、独立QA已读取原始日志的专项检查，与上面的151条用例分别记录，不相加成覆盖率或美术评分。

| 专项 | 原始结果 | 证据／复现入口 |
| --- | --- | --- |
| 世界几何与可走性 | 78项、0失败；城镇831／831可走格连通 | `tests/preview_evidence/visual-v2/world.log`；`tests/waterfront_checks.gd` |
| 正式镜头边界 | 中心、起点及四角附近共6站位头／脚投影均在检查边界内 | `tests/preview_evidence/visual-v2/camera-bounds.log`；`tests/camera_bounds_review.gd` |
| HUD绘画atlas | 实际runtime加载，20映射全部通过，纹理1402×1122，未走fallback | `tests/preview_evidence/visual-v2/hud-atlas.log`；`tests/hud_atlas_checks.gd` |

镜头专项退出时保留了 `ObjectDB instances leaked at exit` 警告，日志未删减；该专项说明六处投影检查成功，不能据此宣称内存／长时稳定性验收完成。新版连续画面的实际检查范围另记，不用固定帧或固定步长编码帧率替代用户机器实时性能。

## v2实际录像与抽帧检查

`visual-v2/movie.json`和 `visual-v2/visual-movie.log`记录了真实Godot Movie Maker输出：1440×810、161帧、20fps、时长8.05秒，Forward+／llvmpipe软件Vulkan，随后编码为H264／AAC的 `linchuan-visual-v2.mp4`。这是固定模拟步长离线录制；20fps是视频编码规格，不是实测游玩帧率。MP4 SHA256为 `acf89a0b75765c08cf8f55876070bb52bf49cd3eea582dc44c42c5e83304f6cf`。

独立QA实际打开按2秒间隔抽取的4张图，副本位于 `visual-v2/motion/`：可见江照野与祝听澜换入、实际技能图标／冷却更新、普通／精良装备的自动入囊标签、薄旗环、敌人和青色召唤／术法效果；各样本中角色、敌人和主要场景仍能辨认。另已实际打开 `town-v2.png`与 `boss-v2.png`，确认中文、城镇三名NPC、独立舟主体型与血条、技能格可见。

这段短片和4张采样图未覆盖完整四人、三波及三阶段通关，也不包含全部红色预警；独立QA未据采样帧宣称逐帧无闪烁、完整动画质量或人工键鼠手感通过。建筑／道具手工细节、重复屋式和密集掉落标签的避让仍可精修；整体仍按“更接近目标的视觉修订”交付。

## 本轮必须覆盖

| 项目 | 可复现标准 |
| --- | --- |
| 流程 | 城镇整备→选关→三波渡口/独立舟主→结算→回城→再开局；界面关闭后输入恢复 |
| 战斗 | 四人技能实际造成各自效果；鼠标方向/距离/遮挡参与命中；敌方攻击预警与实际命中一致 |
| 轮换 | 三名出战、一人在场，冷却和生命独立，共享闪避/觉醒；后台效果归原施法者 |
| 首领 | 三个阶段有实际行为变化；战败能重试，已获得成长不丢失 |
| 成长 | 击杀和通关实际增加经验/材料；装备和机制武器改变战斗；套装效果与提示一致 |
| 奖励 | 同一 run 不能重复结算；不同合法新局可继续获得奖励；指定兑换扣款与物品一致 |
| 保存 | 独立进程保存再读取；坏主档恢复、双坏档保护；旧 ember_save.json 不被覆盖 |
| 输入 | 人工键鼠体验与自动演示独立验收；E 区域预览的松开释放、取消和切换都要检查 |
| 美术 | 已批准近距离斜角、暖灯冷雨、像素人物与立体场景；角色受遮挡、技能与危险区可辨认 |

## 本轮完成边界

四名角色是代表试玩预置，尚不证明正式剧情招募、女主完整故事或五地区已完成。步行图集与程序化攻击反馈属于样板素材，完整专用攻击、受击、死亡动画与最终音效配乐仍未完成。测试通过不能推出“30 小时内容完成”或“玩家觉得好玩”。

---

# 历史记录：旧矿井样板（不作为新版通过证据）

# QA record — Ember Town visual prototype

Status: independent headless logic, save-corruption regression and real Forward+ frame capture passed on Godot 4.5.2. Ready for packaging as a mine-room prototype. Windows target-machine startup and user enjoyment have not been validated.

## Required evidence

- Record the exact engine version, command, renderer, exit code, and log.
- Keep headless logic/import results separate from rendered screenshots.
- An exported executable is not evidence of target Windows startup.
- No user enjoyment, retention, or performance claim without the corresponding trial.

## Checks against real game behavior

| Check | Procedure | Failure this detects |
|---|---|---|
| Attack direction | Attack the same-distance target on and outside the displayed arc at cardinal and 22.5°, 45°, 67.5° directions; check actual hit result | Invisible hits and cursor/weapon/damage disagreement |
| Equipment consequence | Run the same enemy encounter before and after equipping the dropped weapon, with identical state | Item tooltip changes but combat does not |
| Unique reward | Collect the same reward twice, leave/re-enter, then reload and retry | Duplicate inventory or progression grants |
| Cross-process save | Save through gameplay, exit, start a new process and compare inventory, equipped item and progress | In-memory state mistaken for persistence |
| Death retention | Acquire equipment, die, verify inventory and equipped effect survive | Death clears promised permanent growth |
| Rendered readability | Capture wall front/back, diagonal attack, loot and telegraph, summoned ally plus spell | Clipping, hidden hazards, detached weapon and unreadable pixel art |
| Demo vs player input | Check interactive input separately from scripted demo | Attractive recording but unplayable controls |

## Scope

Only implemented prototype features are eligible to pass. An unavailable feature is marked unimplemented, not passed. Automated hit tests must call actual combat logic or perform real input, rather than repeat damage formulas.

## Iteration log — 2026-10-15 UTC

1. Executed engine version: `4.5.2.stable.official.6ce3de25a`.
2. First import and the eight in-game checks passed. Independent review found that the initial Node3D hero bypassed room StaticBody3D props. Requested an actual character collision fix.
3. Developer changed hero/enemies to CharacterBody3D, added colliders and movement collision, and added projectile obstruction. Independent replay through the actual `_process` movement path now stops before the pillar at `(-9.044821, 0, -4.4)`.
4. Headless simulated physical-key injection did not update physical key state. This was a QA driver limitation, not a game defect. Replaced that driver with the existing demo movement feeding the same production movement function. Human keyboard input is still a separate rendered check.
5. Independent directional tests exercised actual `_attack` damage at 0°, 22.5°, 45°, 67.5°, 90°, 135°, 180°, 270°: forward hits, rear misses and out-of-range misses all passed. Actual weapon switching increased dealt damage and spawned the additional sword projectile. Actual lethal damage and revival preserved the equipment.
6. Separate writer and reader engine processes passed: real elite death, pickup, equip, save, process exit, reload, and duplicate reward prevention. No in-memory reload was substituted for the second-process check.
7. After the developer added line-of-sight protection, paired tests passed: the same attack cannot hit through a pillar but can hit an unobstructed target at comparable range.
8. First independent rendered launch failed before Godot started: Xvfb display 100 had an existing lock despite a free TCP port. Reported the launcher defect to the technical lead. This is not a game-render pass.
9. Independently inspected `tests/evidence/second-render.png`, produced by the team's rendering pass: original pixel hero, lit 3D mine room and readable Chinese UI are visible. The enemies and summoned ally in that image are placeholders, so that image does not pass final art consistency. New character assets are being prepared.
10. Independently launched the corrected rendering wrapper with the final enemy/summon sheets. `tests/evidence/visual-final.png` and `visual-final.log` show a real demo encounter reaching the rare weapon pickup. Exit code 0; renderer Vulkan 1.4.318 Forward+, Mesa llvmpipe.
11. Independently ran `tests/visual_checks.gd` to capture a still-active encounter at 2.02 game seconds: `tests/evidence/visual-combat.png` and `visual-combat.log`. Exit code 0. The reviewer opened the image and confirmed original pixel hero, distinct elite and ranged enemies, summoned ally, ground telegraph, Chinese UI and lit 3D mine scenery. Previous block-shaped placeholders are replaced. This is prototype art acceptance, not a claim of commercial game polish or animation quality.
12. A corrupted-primary recovery test passed all four state checks, but exposed error-level logging from `JSON.parse_string` for expected invalid input. Developer switched to error-code-based parsing rather than suppressing the runner's error check. Final regression passed: a new process restores earned equipment/kills from a valid backup, informs the player, produces a valid primary, and preserves the good backup. Double corruption disables automatic saving, informs the player, and leaves both original files unchanged. No script/engine error in the final logs.
13. A late independent technical review reproduced two previously uncovered projectile defects in the old implementation: rare sword waves born inside a pillar could exit it, and the forward spawn offset could skip an entire thin wall. The technical lead recorded actual HP loss in both cases. Developer removed the forward offsets from player sword waves/ice and enabled start-inside ray hits. QA's own execution began after that patch; it does not claim a pre-patch red run. Added eight assertions exercising actual rare attacks inside/beyond blockers, ice skipping a thin wall, projectile removal, and unobstructed ice/sword-wave damage as positive controls. All passed, then the full suite passed again. Final `summary.json` contains the updated production script hashes.

## Reproduce headless checks

Run `python tests/run_qa.py --engine /absolute/path/to/Godot` from any directory. The runner isolates data/config/cache, stores every command and exit code in `tests/evidence/summary.json`, and saves separate logs. A script error causes failure even if the engine exits with code zero. The writer and reader stages deliberately share one isolated save file across two engine processes.

Latest complete headless run: eight internal checks and 56 independent assertions passed (28 combat, 12 collision/obstruction/projectile regressions, 5 writer, 4 reader, 4 primary recovery, 3 double-corruption protection). These counts describe rule checks, not human playtests or test coverage percentages.

## Remaining acceptance limits

- Actual keyboard/mouse play and continuous-animation/diagonal-weapon alignment still need hands-on review. Final enemy/summon static consistency and representative screenshots have passed the independent rendered inspection.
- A software Vulkan renderer can prove frame production; it cannot establish target physical-GPU performance or a 60 FPS promise.
- Export and PE checks are separate from launching the Windows game on a Windows machine.
- No user enjoyment or willingness to replay claim has been made.
