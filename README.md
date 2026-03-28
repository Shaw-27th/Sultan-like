# Sultan-Like Demo (Godot 4.6)

一个最小可玩的“苏丹like”原型：
- 回合推进
- 随机事件
- 双选项决策
- 资源变化（金币、粮食、影响力、动荡）
- 胜负条件

## 运行方式
1. 用 Godot 4.6.1 打开本目录。
2. 直接运行项目（`F5`）。
3. 主场景是 `res://scenes/main.tscn`。

## 可改位置
- 事件内容：`scripts/main.gd` 里的 `events` 数组。
- 初始数值：`scripts/main.gd` 的 `_start_new_game()`。
- 胜负条件：`scripts/main.gd` 的 `_check_lose_conditions()` 和 `_apply_choice()` 结尾部分。
