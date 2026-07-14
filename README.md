# 牧羊小岛

使用 Godot 4.7 制作的 2D 像素牧场经营游戏。玩家可以扩建岛屿、管理羊群、建造并升级围栏和小屋、指挥牧羊人及牧羊犬，并处理疾病、繁育、普通订单、两步行商连单、章节目标与随牧场规模增长的狼群风险。

## 运行

1. 使用 Godot 4.7 导入本目录的 `project.godot`。
2. 运行项目后从封面开始新游戏，或读取已有存档。
3. 基础分辨率为 `1280 × 720`，渲染方式为 GL Compatibility。

## 经营目标

- 前 7 天完成新手委托，第 8 天起进入五章牧场成长目标。
- 每日任务、订单、繁育、建筑升级、狼迹巡查和走失羊救援会提供声望。
- 声望提升牧场等级；右上章节摘要中的“牧场档案”显示长期统计和成就。
- 第 20 天后可以升级小屋与围栏；扩大土地和羊群也会逐步提高狼群威胁。

## Windows 导出

项目已包含 `Windows Desktop` 导出预设。安装 Godot 4.7 导出模板后，可在编辑器的“项目 > 导出”中生成 `build/牧羊小岛.exe`，或执行：

```powershell
& 'D:\Apps\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop'
```

## 测试

每个 `tests/*.gd` 文件都是可独立运行的 Godot 无窗口测试。例如：

```powershell
& 'D:\Apps\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tests/stamina_rest_system_test.gd
```

当前版本为 `0.3.0`。完整功能和验证状态见 [已实现.md](已实现.md)。早期设计草案保存在 [初稿.md](初稿.md)，实际进度以 `已实现.md` 为准。

## 素材

正式场景只引用 `assets/` 下已整理的游戏资源。`work/` 中保留可复现的提示词、处理脚本和视觉验收脚本；生成源图和本地缓存不会提交到仓库。
