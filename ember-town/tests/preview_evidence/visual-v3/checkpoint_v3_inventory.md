# checkpoint v3：实际恢复清单

本次只读检查实际文件并修复QA工具，未导入、未运行新引擎验证、未修改生产源。记录中的旧通过只对应旧SHA；当前整体仍未达最初参考图，不发候选包。

| 项目 | 实际保存情况 | 下一步 |
| --- | --- | --- |
| 原始确认图 | `docs/reference/approved-ferry-target.png`及JSON存在 | 继续以真实图对照，勿把概念图当实机成果 |
| 正式长动作取证 | `attack-motion-restored-final/`内MP4、AVI、366帧40fps／9.15秒记录、原始log、manifest/actions、四向原生序列、提取规则与实际fixture存本齐全；MP4 SHA与media.json匹配 | 不重录9秒。该片recorded combat09b1／world974c，2／14回收硬切未通过，不能当当前66cc特效证据 |
| 生产局部特效修正 | combat66cc及worldb9b7代码实际在；原attack PNG仍fb6e | 有源码不等于修正画面本轮已验证 |
| 3.1秒局部短片 | `tests/combat_feedback_visual_review.gd`源码存在且SHA8d92，包含front40度斜靶、left／right basic及种mark真实F；媒体、manifest及独立评审JSON缺失 | 统一import后唯一补录短片，重新检查白盘、弧高度、前脚可见性；上轮会话观察不可替代本轮实际媒体 |
| QA阻断工具 | 长fixture、runner、extract helper及原始基线／art_review_v3都在 | 已给runner补`--fixture feedback`复用4动作门禁，保持临时存档、真实scenery、engine／shader错误及source／shader变动阻断。仅Python语法检查完成 |
| 木纹／船／框景图 | world-foreground-4-ferry／boss及原生局部存在 | 仍有规则板缝、积水与米粒水面、规整纯色窗灯、Boss暗部粘连缺口；不能据改善放行原图 |
| 第一次回收候选 | `shen_attack_recovery_candidate.png`存在 | 该整图曾重绘其他14格，不能整套替换；不是第二轮targeted版本 |
| 第二轮回收候选2 | PNG／JSON、targeted对比图实际未见 | 请素材负责人从可靠源恢复；无法恢复则重生成并重新逐帧审，不能假称仍有f003版本 |
| loot／2.3秒新fixture | 搜索未见 | 我未看到其完整代码或可靠产物，交对应owner按完整上下文恢复，QA不臆造实现 |

上一会话确实进行过短片及候选静审，但该批实际媒体未在此checkpoint中恢复。因此只保留待验证问题：front／right回收的躯干硬切；右候选14→15也要排是否把硬切后移。大半径／背向新弧曾未覆盖，不因front／left／right局部改善推导全向通过。没有新增151项、Windows、目标显卡FPS或整体美术通过声明。
