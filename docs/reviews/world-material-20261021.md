# 渡口材质降噪 · 2026-10-21

状态：第二轮实机局部改善已接受，第三轮两组甲板补板代码/无头检查完成，待 GPU 正常尺寸审查。整体视觉未通过。

## 问题与最小改动

原始参考图的水面有疏密变化的冷蓝波面及局部暖灯倒影。恢复基线 `verification/visual-baseline/ferry.png` 中，水面存在全域重复的米粒状高光，湿木反射仍有细碎沙点。

- `waterfront_water.gdshader`：移除遍布全水面的高频 noise 法线，以较低频连贯浪面承担反射；细波仅打断部分波带；按屏幕导数将亚像素波纹收敛到平均强度。略增水面粗糙度、略降镜面强度。
- `waterfront_wetwood.gdshader`：积水核将高频木纹/扰动浮雕衰减到干木的 16%，保留干区木纹、湿区原来的形状、颜色与粗糙度分布。
- 未改变镜头、人物尺度、几何、灯光、碰撞、存档或奖励。没有新增贴图、依赖或框架。

## 校验

实际执行（工作目录仓库根）：

```text
/workspace/scratch/75c92baf237b/tools/godot/Godot_v4.5.2-stable_linux.x86_64 --headless --path ember-town --script res://tests/waterfront_checks.gd
```

结果：退出 0；`WATERFRONT_CHECKS=79 FAILURES=0`；`TOWN_CONNECTED_CELLS=831/831`；日志无 SCRIPT ERROR/ERROR。日志：`verification/world-shader-headless.log`（验证输出在工程外，未冒充仓库原始源码）。无头运行不能证明 spatial shader 的 GPU 编译或最终画面。

| 源文件 | 基线 SHA-256 | 修改后 SHA-256 |
| --- | --- | --- |
| waterfront_water.gdshader | ef5e57666c7dff8bbd0d9ac4f005d65c8068c48795e8b6927e02081f9ae4f5ec | 560f3c149f4bc2061d8e6fa11966f294a9b22d2bfbe3531410537b1ae1aacb29 |
| waterfront_wetwood.gdshader | 6f729671220fcf59ca748028d6fb6e41fc652b7fea1d907d7ec55c9e6291c3b5 | 23937de4a02847a0596fb308b4e4ce1a0e04a4b50a4e1c15e16182dcee33c2e1 |

## 第一轮 GPU A/B 只读评审

实际查看 `verification/visual-baseline/ferry.png` 与 `verification/material-after/ferry.png`：水面细碎高光与湿木沙点减少，但右后暖光倒影成为大椭圆糊团。第一轮水面不能直接接受；湿木可保留为局部改善。原因是把方向性 ripple 法线也压得过低，留下过平的镜面。

## 第二轮 · 水面与船舱窗/灯笼组

- 水面保留移除随机 fine-noise 法线的变化，将方向性 ripple 恢复到 `0.035 × (0.5 + 0.5 × ripple_band)`，期望把暖反射分为条带，而不是恢复全域随机砂粒。
- 船舱四窗重新形成两处主要暖光、一处半遮木板和一处暗内景/侧开窗扇；主窗格栅不再四格同形。最右窗收回舱壁内。薄黑内框与木框形成窗洞层次，无新增碰撞。
- 窗纸由局部坐标给出暖芯、暗边、接纸痕、上缘熏痕，主/微亮/暗三档传光，避免只对所有物件全局降 emission。
- 新增独立灯笼纸材质：暖芯、上下暗边、八向接缝、上缘局部熏痕，盖面不发光；灯笼 OmniLight 数值、全局照明、相机、人物、船体碰撞均不变。
- 没有调整远岸建筑布局；共用窗纸 shader 会改善其纸面明暗，但本轮几何精修仅近船窗组。

第二轮再次运行相同 Godot 无头命令：退出 0，`WATERFRONT_CHECKS=79 FAILURES=0`，`TOWN_CONNECTED_CELLS=831/831`，无 SCRIPT ERROR/ERROR。日志：`verification/world-round2-headless.log`。`git diff --check` 通过。无头不证明 GPU shader 编译或最终美术效果。

`waterfront.gd` 字体引用行由 root 单独迁移，世界改动未覆盖该行；最终整文件哈希以 root 录制前冻结清单为准。

| 第二轮 shader | 冻结 SHA-256 |
| --- | --- |
| waterfront_water.gdshader | 7dce23601d7531ececda98b6bda84146f9a34a8ca367126f90ccf8685e3007a3 |
| waterfront_wetwood.gdshader（沿用第一轮） | 23937de4a02847a0596fb308b4e4ce1a0e04a4b50a4e1c15e16182dcee33c2e1 |
| waterfront_window.gdshader | 2c51d8cb5e4a6cde41361036fbe3c89d47996c1d4759f6189b19518084ff88c2 |
| waterfront_lantern.gdshader | 15f3bcd2762454254ec0dce05aed4a7f99a35fa493f983be3533ef0077268af6 |

## 待整合者补充

- 固定镜头 GPU 取证前后哈希、日志、实际图像位置。
- 水面是否减少重复细高光，同时保留足够的冷蓝层次与灯下碎倒影。
- 湿木是否减少沙点，同时避免积水看起来像整齐塑料亮片。
- 第二轮窗洞深度、暖光主次、灯笼纸面/骨架是否在正常尺寸可读。
- 接受、修改或回退第二轮的实际结论；即使局部改善，也不能把整体 ART-01 改为通过。

## 第二轮只读自审结论

实际查看 `verification/world-round2/ferry.png`，并与第一轮 `verification/material-after/ferry.png` 对照：船舱两处主要暖光、半掩窗与暗内景的主次在正常画幅可辨认，窗框有内外层次；灯笼纸面有暖芯、暗边，可同时辨认骨架。水面右后暖倒影已由单个圆糊团出现方向性条带，属于局部改善；其柔软度、冷蓝疏密与最终氛围仍需继续和原图比对。不能据此解除整体视觉门槛。

## 第三轮 · 两组齐地修补

仅在 `_ground()` 与新增 `_deck_repair()` 中加入两组使用痕迹：渡船前 `(-4,-4)` 与右下卸货边 `(7,4)` 各约 2.8 × 1.6m。每组六行短横补板，每行两段错缝，板端长度与轻微偏角不同。复用现有 deck 批次、旧木材质与缺角网格，保留与原木板统一的受光和湿度。低薄暗槽只露在补板接缝，少量旧钉与三条边缘擦痕表达装卸使用，未撒全域噪点或堆杂物。

修补板顶约 0.086m，较原板面仅高约 2cm，属于低薄齐地修补；所有新增几何无碰撞。中央走道、可走边界、基础碰撞、前景、相机及人物未改变。新增 24 个补板实例、48 个小钉头、12 条低暗槽和 6 条擦痕，不增加场景级别的新物件框架。

第三轮实际检查：相同 Godot 4.5.2 无头命令退出 0，`WATERFRONT_CHECKS=79 FAILURES=0`，`TOWN_CONNECTED_CELLS=831/831`；日志 `verification/world-round3-headless.log` 无 SCRIPT ERROR/ERROR；`git diff --check` 通过。

本次冻结 `scripts/waterfront.gd` SHA-256：`d0f10c15b74355cb595540f85e4e28a1d3eb6c21e67c80b676c793e68a383be5`，包含 root 已完成的 WOFF2 字体路径更新。尚未做第三轮 GPU 取证；需检查两组修补在正常尺寸可读、确实打断长直板缝，且没有像堆叠木筏或新铺贴片。
