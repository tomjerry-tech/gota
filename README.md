# 牧羊小岛

使用 Godot 4.7 制作的 2D 像素牧场经营游戏。玩家可以扩建岛屿、管理羊群、建造围栏和小屋、指挥牧羊人及牧羊犬，并处理疾病、繁育、市场订单、每日任务与狼窝夜间风险。

## 运行

1. 使用 Godot 4.7 导入本目录的 `project.godot`。
2. 运行项目后从封面开始新游戏，或读取已有存档。
3. 基础分辨率为 `1280 × 720`，渲染方式为 GL Compatibility。

## 测试

每个 `tests/*.gd` 文件都是可独立运行的 Godot 无窗口测试。例如：

```powershell
& 'D:\Apps\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tests/stamina_rest_system_test.gd
```

当前完整功能和验证状态见 [已实现.md](已实现.md)。早期设计草案保存在 [初稿.md](初稿.md)，实际进度以 `已实现.md` 为准。

## 素材

正式场景只引用 `assets/` 下已整理的游戏资源。`work/` 中保留可复现的提示词、处理脚本和视觉验收脚本；生成源图和本地缓存不会提交到仓库。
