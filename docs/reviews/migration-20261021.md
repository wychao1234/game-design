# 源码迁移独立审查与工具修复

日期：2026-10-21（Asia/Shanghai）。审查基线：`07e5cb9`，来源为检查点 v4。

## 迁移核对

- 检查点总 SHA-256 为 `76665b1ac2ba51dac7ee430f1e61bfe63d69bd86cd7d8b7c59238ce75981526b`，与导入清单一致。
- 原导入清单的 209 条来源记录均与 ZIP 对应成员逐字节 SHA 一致；实际 Git 工程追踪 208 个文件，唯一差异是被根 `*.log` 规则排除的历史 `engine.log`。
- 已将该日志从 `SOURCE_IMPORT.json` 的 imported 移到 excluded。清单哈希描述最初迁入的检查点字节，不是后续修复后的文件哈希。
- 最大追踪文件为 Noto 字体，19,484,784 bytes；没有追踪 AVI、总检查点 ZIP、引擎、导出包或用户存档。凭证/私钥/签名 URL 模式检查未发现泄漏。
- 生产资源完整。静态引用扫描的缺失项是故意失败测试 `missing_pilot.png` 和旧版 `game.gd` 中有 `ResourceLoader.exists` 与程序化回退保护的可选资源，不是必需资产漏迁。
- 保留旧 `main.tscn`/`game.gd`，新预览存档独立且禁止使用旧 `ember_save.json`；Godot MIT、Noto SIL 字体许可与素材来源说明在工程内。

## 发现与修复

1. 动作验证脚本原先假设引擎与离屏启动器位于仓库内。迁移后该假设失效。现改为必需的 `--engine PATH`，录制时另需 `--offscreen PATH`，使用当前 `sys.executable` 启动 Python 入口，验证路径及正数 fps 后才创建输出目录。
2. 源码打包函数原先会收进 `.engine.log.*`、隐藏 AVI 副本和临时文件，导致检查点体积反复膨胀。现跳过隐藏临时路径（保留 `.gitignore`）、`.tmp`、`.log.bak`、`.log.old`；正常原创资源、`.import`、`.uid` 与有效证据日志不因此排除。现有符号链接拒绝边界不变。
3. 工程内 `SHEN_ATTACK_PILOT.md` 增补显式参数的复现命令；不重写旧证据中历史命令，不把旧测试算成本轮。

## 本轮工具验证

命令：

```sh
python3 ember-town/tests/migration_tools_checks.py
python3 -m py_compile ember-town/tests/run_shen_visual.py ember-town/tests/migration_tools_checks.py ember-town/tools/build.py
git diff --check
```

三项通过。小型 assert 自检实际创建 ZIP 并检查成员，验证缺失参数/无效引擎以退出码 2 拒绝，以及符号链接仍不能打包。未只复述过滤代码本身。

本岗位未运行 GPU 或 Windows，也未提交、切分支或合并。实际 Godot 无头动作验证待生产源冻结后统一执行；画面和正常速度动作验收仍未通过。迁移文档审查不替代游戏体验验收。
