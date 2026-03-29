# Sultan-Like Demo (Godot 4.6)

一个最小可玩的“苏丹like”原型：
- 大地图地点（王都、边境、港口）
- 地点固定事件 + 周期/随机刷新事件
- 事件派遣（一个事件可分配一个或多个角色）
- 支持取消派遣（撤回单人或整队）
- 可点击地图热点选择地点，不再依赖地点列表
- 下一回合按顺序结算已派遣事件
- 资源变化（国库、粮食、稳定）与胜负条件

## 运行方式
1. 用 Godot 4.6.1 打开本目录。
2. 直接运行项目（`F5`）。
3. 主场景是 `res://scenes/main.tscn`。

## 可改位置
- 地图与事件模板：`scripts/main.gd` 的 `_build_locations()`。
- 角色与初始数值：`scripts/main.gd` 的 `_build_cards()`、`_start_new_game()`。
- 刷新与结算规则：`scripts/main.gd` 的 `_spawn_events_for_turn()`、`_resolve_assigned_events_in_order()`。
