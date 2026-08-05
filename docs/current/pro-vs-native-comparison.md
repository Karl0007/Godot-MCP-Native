# Godot MCP Pro 与 Godot-MCP-Native 对比分析

> 分析对象：
> - **Native**（本工程）：`C:\Godot\MCP\Godot-MCP-Native` — Godot 4.6 EditorPlugin，纯 GDScript，155 个工具（30 core + 125 supplementary）
> - **Pro**：`C:\Godot\MCP\godot-mcp-pro` — Node.js/TypeScript bridge + GDScript 插件（vendor submodule），174 个工具（manifest 计数）
>
> 分析日期：2026-08-05。工具清单以两个仓库当前源码为准。

---

## 0. 差异口径说明（重要）

本文档的"Pro 独有 144 个"是**名称级差集**（`pro 工具名 - native 工具名`）。
名称不同但功能等价的工具会被计入 144，但实际有 Native 对应物：

**语义等价（名称不同，功能相同）—— 8 个应剔除：**

| Pro | Native 等价物 |
|---|---|
| `add_node` | `create_node` |
| `update_property` | `update_node_property` |
| `edit_script` | `modify_script`（仅整文件/单行替换，无 regex/行号段） |
| `list_scripts` | `list_project_scripts` |
| `get_open_scripts` | `get_current_script`（只取当前一个，非全部打开的） |
| `simulate_key` / `simulate_mouse_click` / `simulate_mouse_move` / `simulate_sequence` | `simulate_runtime_input_event`（事件 payload 完全覆盖 key/mouse/sequence） |

**弱等价（Native 有对应物但能力弱一档）—— 8 个应降级：**

| Pro | Native 弱对应 | 差异 |
|---|---|---|
| `get_game_scene_tree` | `get_runtime_scene_tree` | 无 script_filter/type_filter/named_only 过滤 |
| `get_game_node_properties` | `inspect_runtime_node` | 支持属性过滤 |
| `set_game_node_property` | `update_runtime_node_property` | 等价 |
| `get_game_screenshot` | `get_runtime_screenshot` | 等价（仅 base64 返回 vs 落盘） |
| `get_editor_performance` | `get_performance_metrics` | 等价 |
| `compare_screenshots` | `compare_render_screenshots` | 等价 |
| `get_editor_screenshot` | `get_editor_screenshot` | 同名，等价 |
| `simulate_action` | `simulate_runtime_input_action` | 等价 |

**结论：真正的差异 = 144 − 8（语义等价）− 8（弱等价降级）= 128 个**，其中：
- **~16 个有 Native 弱对应**（Pro 能力更强或更完整，主要分布在运行时输入/截图/树查询）
- **~112 个是 Native 完全缺失的真空白**（3D 构建、物理、导航、粒子、编辑器态动画/音频/主题/着色器、TileMap 编辑器操作、游戏内测试编排、录制回放、跨场景批处理、Android/导出、自举基础设施等）

下文按"真空白 128"口径组织，但为便于对照仍列出全部名称。

---

## 1. 总览

| 维度 | **Native** | **Pro** |
|---|---|---|
| 架构 | 编辑器内原生 MCP 服务器（HTTP/SSE 9080 + stdio） | Node bridge（stdio）↔ WebSocket（6505-6509）↔ 编辑器插件 |
| 部署依赖 | 零依赖（Godot 4.6 即可） | Node 18+、npm、Git submodule |
| 工具总数 | 155（classifier 155 条） | 174（generated-manifest 174 条） |
| 工具命名 | snake_case（`create_node`） | camelCase（`add_node`） |
| 调试器 | 30+ 工具（断点/栈帧/变量/步进） | 仅 profiling 2 个 |
| 认证 | HTTP Bearer Token | 无（仅 127.0.0.1 绑定） |
| 自举 | 无（需手动打开编辑器） | `godot_ensure_ready` 全自动 |
| 日志 | 编辑器日志面板 | JSONL 请求日志 + doctor 诊断 |
| CLI | Rust gdmcp（渐进式发现） | Node CLI（26 个显式别名） |
| 测试 | GUT 单测 + 43 个 Python 集成测试 | 6 个 Node 测试文件 |

## 2. 工具集合差异

### 2.1 Pro 独有工具（名称级 144 个；语义真空白 ~128 个）

> 含语义等价与弱等价（见第 0 节）。真空白工具按类别完整列出；带 ⚠ 的为弱对应（Native 有同名/近义工具但能力较弱）。

按类别完整列出：

#### 3D 场景构建（Native 完全没有 3D 编辑工具）
| 工具 | 功能 |
|---|---|
| `add_mesh_instance` | 创建 MeshInstance3D（原语/glTF/glb 导入） |
| `setup_lighting` | Directional/Omni/Spot 灯光 |
| `set_material_3d` | StandardMaterial3D PBR（albedo/metallic/roughness/normal/emission/transparency） |
| `setup_environment` | WorldEnvironment（天空/环境光/色调映射/背景模式） |
| `setup_camera_3d` | 3D 相机配置 |
| `add_gridmap` | GridMap 节点 |

#### 物理
| 工具 | 功能 |
|---|---|
| `setup_collision` | 2D/3D 碰撞形状（rectangle/circle/capsule/segment/convex） |
| `set_physics_layers` / `get_physics_layers` | 物理层位掩码 + 命名层 |
| `add_raycast` | 射线检测节点 |
| `setup_physics_body` | 物理体配置 |
| `get_collision_info` | 碰撞信息查询 |

#### 导航
| 工具 | 功能 |
|---|---|
| `setup_navigation_region` | 2D/3D 导航区域（agent_radius/height/climb/slope/cell_size） |
| `bake_navigation_mesh` | NavMesh 烘焙（含 outline 多边形生成） |
| `setup_navigation_agent` | NavigationAgent2D/3D |
| `set_navigation_layers` | 导航层（bitmask/layer_bits/命名层三种模式） |
| `get_navigation_info` | 导航节点与层信息 |

#### 粒子
| 工具 | 功能 |
|---|---|
| `create_particles` | GPUParticles2D/3D |
| `set_particle_material` | ParticleProcessMaterial |
| `set_particle_color_gradient` | 颜色渐变 |
| `apply_particle_preset` | 预设 |
| `get_particle_info` | 粒子状态查询 |

#### 动画（编辑器态）
| 工具 | 功能 |
|---|---|
| `create_animation` / `list_animations` / `get_animation_info` / `remove_animation` | AnimationPlayer 动画管理 |
| `add_animation_track` | value/position/rotation/scale/method/bezier/blend_shape 轨道 |
| `set_animation_keyframe` | 关键帧插入 |
| `create_animation_tree` | AnimationTree 创建 |
| `get_animation_tree_structure` | 树结构读取 |
| `add_state_machine_state` / `remove_state_machine_state` | 状态机节点（animation/blend_tree/state_machine 类型） |
| `add_state_machine_transition` / `remove_state_machine_transition` | 状态机过渡 |
| `set_blend_tree_node` | BlendTree 节点 |
| `set_tree_parameter` | 树参数（自动加 `parameters/` 前缀） |

#### 音频
| 工具 | 功能 |
|---|---|
| `get_audio_bus_layout` | 总线布局（含效果参数） |
| `add_audio_bus` / `set_audio_bus` | 总线增改 |
| `add_audio_bus_effect` | 效果（reverb/delay/compressor/limiter/distortion 参数） |
| `add_audio_player` | AudioStreamPlayer |
| `get_audio_info` | 音频信息 |

#### 主题 / UI
| 工具 | 功能 |
|---|---|
| `create_theme` | Theme 资源创建 |
| `set_theme_color` / `set_theme_constant` / `set_theme_font_size` / `set_theme_stylebox` | Control 主题覆盖 |
| `setup_control` | Control 布局（anchor 预设/对齐/尺寸） |
| `get_theme_info` | 主题信息 |

#### 着色器
| 工具 | 功能 |
|---|---|
| `create_shader` | spatial/canvas_item/particles/sky 模板 |
| `read_shader` / `edit_shader` | 读写（search-replace/regex/行号） |
| `assign_shader_material` | 材质赋值（CanvasItem/MeshInstance3D） |
| `set_shader_param` / `get_shader_params` | 参数读写（Expression 解析） |

#### TileMap（编辑器态）
| 工具 | 功能 |
|---|---|
| `tilemap_set_cell` / `tilemap_get_cell` | 单元格读写 |
| `tilemap_fill_rect` | 矩形填充 |
| `tilemap_clear` | 清空 |
| `tilemap_get_info` / `tilemap_get_used_cells` | 信息查询 |

> 同时支持 `TileMapLayer` 和旧版 `TileMap`；Native 运行时 probe 仅支持旧版。

#### 编辑器操作
| 工具 | 功能 |
|---|---|
| `get_editor_errors` | 4 路抓取（Output 面板/脚本红底行/GDScript analyzer/调试器 Errors 标签） |
| `get_output_log` | 输出日志（filter） |
| `set_auto_dismiss` | 自动关闭阻塞弹窗 |
| `get_editor_camera` / `set_editor_camera` | 3D 视口相机读写 |
| `get_editor_selection` / `select_nodes` / `clear_editor_selection` | 选区管理（replace/add/remove + inspect/focus） |
| `reload_plugin` | 插件热重载 |
| `get_scene_file_content` | 读 .tscn 原文 |

#### 场景
| 工具 | 功能 |
|---|---|
| `delete_scene` | 删除场景文件（含 .import） |
| `add_scene_instance` | 实例化场景 |
| `play_scene` / `stop_scene` | 播放/停止（main/current/自定义路径） |
| `get_scene_exports` | 遍历场景所有 @export 属性 |

#### 项目
| 工具 | 功能 |
|---|---|
| `get_filesystem_tree` | 文件系统树 |
| `search_files` | 文件名模糊搜索 |
| `set_project_setting` | 设置（类型推断） |
| `uid_to_project_path` / `project_path_to_uid` | UID 双向转换 |
| `add_autoload` / `remove_autoload` | Autoload 增删 |
| `get_project_statistics` | 项目统计 |

#### 资源
| 工具 | 功能 |
|---|---|
| `read_resource` | 资源属性序列化读取 |
| `edit_resource` | 资源属性修改 |
| `get_resource_preview` | 图片缩略图（base64） |

#### 输入映射
| 工具 | 功能 |
|---|---|
| `get_input_actions` / `set_input_action` | 键盘/鼠标/手柄事件序列化 + 死区 |

#### 导出 / Android
| 工具 | 功能 |
|---|---|
| `export_project` / `get_export_info` | 导出命令生成 |
| `list_android_devices` | adb 设备列表 |
| `get_android_preset_info` | Android 预设信息 |
| `deploy_to_android` | 导出 + adb install 全链路 |

#### 运行时（游戏内）
| 工具 | 功能 |
|---|---|
| ⚠ `capture_frames` | 多帧截图（count/interval/half_resolution + 动态超时）— Native `get_runtime_screenshot` 仅单帧 |
| `monitor_properties` | 属性连续采样（最多 600 帧）— Native 无连续采样 |
| `start_recording` / `stop_recording` / `replay_recording` | 输入录制/回放 — Native 无 |
| `find_ui_elements` | 可见 UI 遍历（Button/Label/LineEdit/TextEdit/OptionButton）— Native 无 |
| `click_button_by_text` | 按文本点击按钮 — Native 无 |
| `wait_for_node` | 轮询等待节点 — Native 无（有 `await_scene_ready` 仅场景级） |
| `find_nearby_nodes` | 半径查询（2D/3D）— Native 无 |
| `navigate_to` | 导航建议（按键/相机旋转/时长估算）— Native 无 |
| `move_to` | 自动行走（W 键注入 + 相机跟随 + 到达检测 + 键释放保证）— Native 无 |
| `watch_signals` | 信号监听（多节点/filter/时序日志）— Native 无 |
| `find_nodes_by_script` / `get_autoload` / `batch_get_properties` | 批量查询 — Native 无 |
| `get_performance_monitors` | 游戏进程性能指标 — Native 有 `get_runtime_performance_snapshot` 弱对应 |
| `execute_game_script` | 游戏内执行 GDScript — Native `execute_editor_script` 仅编辑器进程 |
| `assert_node_state` / `assert_screen_text` | 运行态断言 — Native 有 `assert_runtime_condition` 弱对应 |
| `run_test_scenario` | 测试编排（steps：input/wait/assert/screenshot）— Native 无 |
| `run_stress_test` | 随机输入压力测试 — Native 无 |
| `get_test_report` | 断言汇总（pass_rate/all_passed）— Native 无 |

> ⚠ = 弱对应：Native 有功能相近但能力较弱或作用域不同的工具。

#### 静态分析 / 批处理
| 工具 | 功能 |
|---|---|
| `analyze_signal_flow` | 信号流分析 |
| `analyze_scene_complexity` | 场景复杂度 |
| `detect_circular_dependencies` | 循环依赖检测 |
| `find_unused_resources` | 未使用资源（uid:// 解析 + 自引用排除） |
| `find_script_references` / `find_node_references` | 跨文件引用搜索 |
| `batch_add_nodes` | 批量创建节点 |
| `batch_set_property` / `batch_get_properties` | 批量属性读写 |
| `find_nodes_by_type` / `find_nodes_by_script` | 类型/脚本查找 |
| `find_signal_connections` | 信号连接查找 |
| `cross_scene_set_property` | 跨场景离线修改（dry_run/force + 打开场景跳过） |
| `get_scene_dependencies` | 场景依赖 |

### 2.2 Native 独有工具（125 个，Pro 无对应物）

- **调试器全套**：`set_debugger_breakpoint`、`get_debug_stack_frames/variables/scopes`、`debug_step_into/over/out`、`debug_continue`、`debug_*_and_wait`、`await_debugger_state`、`get_debugger_sessions/messages/state_events/output/threads`、`toggle_debugger_profiler`、`expand_debug_variable`、`evaluate_debug_expression`、`send_debugger_message`、`add_debugger_capture_prefix`
- **运行态 probe**：`install/remove_runtime_probe`、`get_runtime_info`、`get_runtime_scene_tree`、`inspect_runtime_node`、`create/delete/update_runtime_node`、`call_runtime_node_method`、`evaluate_runtime_expression`、`await_runtime_condition`、`assert_runtime_condition`、`simulate_runtime_input_event/action`、`get_runtime_performance_snapshot`、`get_runtime_memory_trend`、动画/音频/主题/着色器/TileMap 运行态读写（`list/play/stop_runtime_animation`、`get_runtime_animation_tree_state`、`set/travel_runtime_animation_tree`、`get_runtime_material_state`、`get/set/clear_runtime_theme_*`、`get/set_runtime_shader_*`、`list/get/set_runtime_tilemap_cell`、`list/get/update_runtime_audio_bus`、`get_runtime_screenshot`）
- **场景审计**：`audit_scene_node_persistence`、`audit_scene_inheritance`
- **符号索引**：`list_project_script_symbols`、`find_script_symbol_definition/references`、`rename_script_symbol`、`open_script_at_line`
- **资源健康**：`get_resource_uid_info`、`fix_resource_uid`、`get_resource_dependencies`、`scan_missing/cyclic_resource_dependencies`、`detect_broken_scripts`、`audit_project_health`、`reimport_resources`、`get_import_metadata`、`inspect_tileset_resource`、`compare_render_screenshots`、`get_class_api_metadata`、`inspect_csharp_project_support`
- **项目测试**：`list_project_tests`、`run_project_test(s)`
- **编辑**：`execute_script`（编辑器 GDScript 执行）、`get_editor_logs`、`close_scene_tab`、`get_inspector_properties`、`list_open_scenes`、`get_current_scene/script`、`run/stop_project`

### 2.3 共有工具（30 个）

`get_scene_tree`、`create_node`(≈`add_node`)、`delete_node`、`duplicate_node`、`move_node`、`rename_node`、`update_node_property`(≈`update_property`)、`get_node_properties`、`list_nodes`、`add_resource`、`set_anchor_preset`、`connect/disconnect_signal`、`get/set_node_groups`、`find_nodes_in_group`、`create_scene`、`open_scene`、`save_scene`、`get_project_info`、`get_project_settings`、`create_resource`、`read_script`、`create_script`、`modify_script`(≈`edit_script`)、`attach_script`、`validate_script`、`search_in_files`、`get_editor_screenshot`、`get_signals`、`reload_project`、`clear_output`、`execute_editor_script`、`get_editor_state`、`get_selected_nodes`、`select_node`(≈`select_nodes`)、`list_export_presets`

## 3. 基础设施差异

| 特性 | Native | Pro |
|---|---|---|
| 传输 | HTTP/SSE + stdio | stdio → Node → WebSocket（仅 ws://127.0.0.1） |
| 认证 | Bearer Token | 无 |
| 自举 | 无 | `godot_status` + `godot_ensure_ready`（项目发现/addon 修复/自动启动/身份握手/`wrong_project` 检测） |
| 并发 | 直接分发 | `SerialScheduler` FIFO + 失败恢复 |
| 日志 | 编辑器面板 | `RequestLogger` JSONL（耗时/字节/脱敏）+ `doctor --json` |
| 图片 artifact | 无 | `capture_frames` → MCP image content + PNG 落盘 |
| 输出稳定性 | 直接 JSON | `stableJson` 递归键排序 |
| Schema 生成 | 手写 | `generate-manifest.ts` 从 GDScript 自动提取（类型推断/required/risk 分级） |
| 工具风险标注 | 无 | 每工具 `risk: read/write/destructive/code` |
| CLI | Rust gdmcp（~33 域命令 + 渐进式发现） | Node CLI（26 个显式别名，拒绝动态 call） |
| 多项目 | `--mcp-port` 覆盖 | 端口段 6505-6509 + projects.txt 注册 |
| 技能文档 | `skills/gdmcp/`（Codex skill） | `skills.md` × 8 语言 |
| 权限模板 | 无 | `settings.local.json` / `permissive`（Cline 授权） |
| 插件重载 | 手动 | `reload_plugin` 工具 |
| 弹窗处理 | 手动 | `set_auto_dismiss` 自动关闭阻塞弹窗 |
| 心跳 | 无 | 双向 ping/pong + inactivity 强制重连 + stale 状态 |

## 4. 关键结论与建议

1. **能力缺口最大的是内容创建管线**：3D/物理/导航/粒子/编辑器态动画树/主题/着色器/TileMap 编辑器操作，Native 全部缺失。若需要 Agent 从零搭建游戏场景，Pro 是完整方案。
2. **Pro 的运行时测试编排**（`run_test_scenario`/断言/录制回放/信号监听/压力测试）是闭环的测试框架；Native 只有零散运行时工具 + 自己的 Python 集成测试。
3. **Native 反超点**：调试器深度（断点/步进/变量）和零依赖部署。两者互补：Pro 负责"创建与验证"，Native 负责"断点级排障"。
4. **工程实践差异**：Pro 的 manifest 生成器 + 契约测试（`manifest-contract.test.mjs`）保证工具清单与源码一致；Native 靠 classifier 手工维护（有 `test_module_registration_matches_classifier_exactly` 兜底）。
5. **差异口径**：名称级 144 个中约 16 个有 Native 弱对应（运行时输入/截图/树查询），真正空白约 112 个（编辑器内容创建 + 游戏内测试编排 + 基础设施）。若按"逐工具能力对比"而非"名称对比"，差距比 144 小约 10%。

### 移植建议（若要在 Native 补齐）

优先级从高到低：
1. 3D 场景构建（`add_mesh_instance`/`setup_lighting`/`setup_environment`）— 最常见需求
2. 游戏内测试编排（`run_test_scenario` + `assert_*`）— 复用现有 runtime probe
3. 输入录制/回放（`start/stop/replay_recording`）— 复用 probe 的输入模拟
4. 编辑器态动画/主题/着色器编辑 — 工作量中等，Native 已有运行态读写可参考
5. 自举流程（`godot_ensure_ready` 等价物）— 对 Agent 自动化价值最高

---

*本文档由源码分析自动生成，工具清单以 `mcp_tool_classifier.gd`（Native）与 `generated-manifest.ts`（Pro）为准。*
