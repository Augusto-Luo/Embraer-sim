# Embraer sim

Godot 4.7 / GDScript / Forward Plus 的桌面飞行训练原型，包含 KC-390 与 EMB-314 的飞行、追击和拦截任务。全部运行资产已随工程附带，无需额外插件。

## 启动

1. 用 **Godot 4.7 或兼容版本**导入根目录的 `project.godot`。
2. 等待首次资源导入完成，按 **F5** 运行，进入任务选择界面。
3. 也可以在工程目录执行：

```bash
# Godot 已在 PATH 中
./run.sh

# 或显式指定 Godot 可执行文件
GODOT_BIN=/path/to/Godot ./run.sh
```

`run.sh` 不包含任何个人机器路径。工程根目录就是 Git 仓库根目录。

## 任务

- **01 / AIRFIELD**：KC-390 机场滑跑、起飞、绕场、进近与着陆。
- **02 / PURSUIT**：高空追击 KC-390，完成尾后保持后进行武器练习。
- **03 / FREE COMBAT**：海岸自由飞行与模拟空战。
- **04 / GROUND ATTACK**：城市海岛地图与对地攻击任务。
- **05 / INTERCEPT**：加速追击、尾后保持、解锁武器并阻止目标越境。人物与剧情均为虚构。

## 操作

| 输入 | 功能 |
|---|---|
| ↑ / ↓ | 增加 / 减少油门 |
| W / S | 俯仰，方向取决于设置中的 Invert pitch |
| A / D | 左右滚转 |
| Q / E | 左右偏航 |
| Shift | 减速板 / 第一关地面刹车 |
| G | 第一关起落架 |
| C | 标准 / 远景镜头 |
| 按住鼠标右键并移动 | 自由观察左右与后方 |
| M | 回正追机视角 |
| V | 静态观察模式 |
| T | 切换目标 |
| Space | 机炮 |
| F | 发射导弹 / 火箭弹 |
| P | 暂停 / 继续 |
| R | 重新开始当前任务 |
| Tab / Esc | 打开 / 关闭设置 |

键位、飞行手感、视角、云景和辅助瞄准可在右侧设置页调整。设置保存到各关对应的 `settings-level*.cfg`。

## 发布内容

- `project.godot`：工程入口与渲染配置。
- `scenes/`：任务选择与飞行场景。
- `scripts/`：飞控、任务、镜头、HUD、武器与设置逻辑。
- `shaders/`：云层、地面、海面、引导和特效材质。
- `assets/`：模型、纹理、字体、音频及署名文件。
- `settings*.cfg`：当前各关的默认手感配置。
- `run.sh`：可移植启动脚本。

`.godot/`、测试预览、历史工程、日志、截图、备份与其他临时文件不属于发布内容，并已在 `.gitignore` 中排除。首次导入产生的本地缓存不应提交。

## 资产与剧情说明

第三方模型、城市和机场资源的来源与署名见：

- `assets/kc390-ATTRIBUTION.md`
- `assets/aerodrome-ATTRIBUTION.md`
- `assets/jamsil/ATTRIBUTION.md`
- `assets/jamsil/OPTIMIZATION.md`

全息头像为本项目生成资源。第五关任务明确标记为虚构情境，不表示真实事件或现实指控。
