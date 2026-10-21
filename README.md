# 临川渡口 · 东方幻想动作 RPG

PC 单人刷宝游戏，使用 Godot 4.5.2 Standard、Forward+ 与 GDScript。以 DNF 的城镇选关、连招和装备成长为体验参考，以《八方旅人》的像素角色与立体场景融合为视觉参考，制作原创世界与内容。项目名暂定。

**当前：精修代表性战斗切片，画面尚未达到已认可的雨夜渡口参考图。源码、原创资源与测试已从校验后的 v4 检查点迁入；本轮原生引擎导入、预览与旧矿洞逻辑回归通过。**

- [项目工作总账](PROJECT_WORKLOG.md)：原始目标、真实进度、问题、优先级、每轮记录。
- [已确认设计](docs/DESIGN_BASELINE.md)：用户选择与待定提案的边界。
- [设计档案](docs/design/README.md)：7 份历史设计原稿，保留其日期与原始状态。
- [恢复与迁移](docs/RECOVERY.md)：最近检查点、额外资产、校验与导入步骤。
- [开发协作规范](AGENTS.md)：任务分工、测试、审查、合并与存档保护。

## 开发入口

Godot 工程位于 `ember-town/`。固定使用 **Godot 4.5.2**；新预览入口为 `adventure.tscn`，旧矿洞入口与旧存档需保留。安装对应引擎后可直接打开 `ember-town/project.godot`，或运行下方命令。

历史代表预览包含城镇选关、渡口三波战斗、独立三阶段首领、四人选三轮换、装备成长和结算返回；这些功能已迁入本仓库，并完成本轮自动逻辑回归；完整故事与游戏内容仍未完成。

```sh
Godot --path ember-town
python3 ember-town/tests/run_preview_qa.py --engine /absolute/path/to/Godot
python3 ember-town/tests/run_qa.py --engine /absolute/path/to/Godot
```

命令中的 Godot 应替换为本机 4.5.2 可执行程序路径。验证结果见 [本轮记录](docs/verification/2026-10-21-import/README.md)，源码来源见 [导入清单](docs/SOURCE_IMPORT.json)。运行时与导出包不随源码提交。

## 交付标准

源码提交、逻辑测试通过、静态截图可看、正常速度动作通过和可发布是不同状态。只有对照原始参考图完成实际运行及动作评审，才能宣称视觉切片通过。当前不提供新的候选画面作为达标交付。

用户已授权开发者自主提交、推送、建 PR、自审、合并，并通过 PR 与提交记录排查修复问题。检查失败先修复，不绕过必需检查；自审记录如实注明，不能伪称另一位人员批准。
