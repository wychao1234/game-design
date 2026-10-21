# 2026-10-21 源码恢复与导入验证

本轮在恢复后的真实执行环境重新运行，基准源码为导入提交 `07e5cb9`，非沿用旧报告。原 v4 ZIP SHA 为 `76665b1ac2ba51dac7ee430f1e61bfe63d69bd86cd7d8b7c59238ce75981526b`，归档 CRC、路径安全和关键成员 SHA 通过。

| 检查 | 本轮结果 | 证据 |
| --- | --- | --- |
| 固定引擎 | 4.5.2.stable.official.6ce3de25a | 两份 JSON 的 version 阶段 |
| 新预览 | 11 阶段全部通过，9 行为用例共151断言 | [import-preview.json](import-preview.json) |
| 旧矿洞 | 9 阶段全部通过 | [legacy-import.json](legacy-import.json) |
| 实际渲染 | Forward+ / llvmpipe，1440×810 固定渡口帧写出成功，日志无脚本/着色器错误 | 下方实际命令与日志摘录 |
| 视觉达标 | **未通过** | 水/湿木材质和收招等仍待精修 |
| Windows 真机/硬件 FPS | 未验证 | 不能由导出或软件渲染推断 |

复现（替换引擎与输出路径；runner自动隔离存档/XDG目录）：

```sh
python3 ember-town/tests/run_preview_qa.py --engine /absolute/Godot --output /absolute/qa-preview
python3 ember-town/tests/run_qa.py --engine /absolute/Godot --output /absolute/qa-legacy
```

固定帧使用工程现有 `tools/capture_art_frame.gd`，绝对隔离 profile，参数为 `--camera-x=8 --camera-y=14 --camera-z=24 --focus-x=-1 --focus-z=-2 --perspective-fov=26`，实际打印 camera=(7,14,22.5)、focus=(-1,0,-2)、actor_scale=1、action=false、stage=ferry、PNG error=0。它是受控场景检查，不是完整人工通关。

这次原始运行日志在临时验证目录，Git 保留完整结构化结果、实际命令、退出码、源哈希与摘要；不把大型隐藏日志副本或重复 AVI 纳入版本管理。历史动作证据保留在工程 tests/preview_evidence/visual-v3/attack-motion-restored-final，仍是历史失败的动态美术证据。

迁移审查发现的 runner 路径假定、打包隐藏暂存与 imported 清单偏差已作为同轮修复处理；具体自检见 [迁移审查](../../reviews/migration-20261021.md)。
