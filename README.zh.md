# Godot MCP Native (模型上下文协�?

[English Version](https://github.com/yurineko73/Godot-MCP-Native/blob/main/README.md)

![Godot 版本](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine)
![许可证](https://img.shields.io/badge/License-MIT-green)
![版本](https://img.shields.io/badge/Version-1.1.0-brightgreen)

一个强大的 Godot 引擎插件，通过模型上下文协�?(MCP) 集成 AI 助手（如 Claude 等）。让 AI 可以直接通过自然语言读取和修改您�?Godot 项目——场景、脚本、节点和资源�?

## 🚀 功能特�?

- **完整项目访问**：AI 助手可以读取和修改脚本、场景、节点和资源
- **原生实现**：无需 Node.js 依赖——完全在 Godot 中运�?
- **实时编辑**：直接在编辑器中应用 AI 建议
- **全面的工具集**�?78 个工具—�?3 核心 + 245 补充）：
  - **节点工具**�? 核心 + 17 高级）：创建、修改、管理场景节点，复制、移动、重命名，锚点预设，信号连接，组管理，批量操作，场景审计
  - **脚本工具**�? 核心 + 8 高级）：编辑、分析、创建、附加、验�?GDScript 文件，执行脚本，文件搜索，符号索引，定义和引用查�?
  - **场景工具**�? 核心 + 10 高级）：操作场景结构、保存场景、列�?打开/关闭场景标签页，项目场景列表，播�?停止场景
  - **编辑器工�?*�? 核心 + 26 高级）：控制编辑器功能、截图、信号检查、文件系统重载，节点/文件选择，导出管理，属性检查器，编辑器相机，插件重载，Android 部署
  - **调试工具**�? 核心 + 82 高级）：日志、调试会话、断点、栈�?变量读取、性能分析器、运行时探针，测试编排、输入录�?回放、运行时 UI 检查，动画/音频/着色器/瓦片地图运行时控�?
  - **项目工具**�? 核心 + 41 高级）：访问项目设置、列出资源、创建资源，运行测试、管理输入映射、检查自动加�?全局类，资源诊断，项目健康审计，脚本符号
  - **世界工具**�? 核心 + 22 高级）：3D 场景构建、物理、导航与粒子（网格、光照、环境、相机、GridMap、碰撞、物理层、射线、导航、GPU 粒子�?
  - **媒体工具**�? 核心 + 39 高级）：动画、音频、主�?UI、着色器�?TileMap 编辑（轨�?关键�?状态机、音频总线、主题覆盖、着色器、瓦片地图）
  - **自举工具**�? 核心）：服务器就绪状态（godot_status、godot_ensure_ready、get_server_info�?

## 🖥�?gdmcp CLI（Agent 优先接口�?

对于�?Shell 访问权限的编程代理（Codex、Claude Code、Cursor），**gdmcp CLI**
是与 Godot MCP 交互的推荐方式。CLI 不会将所�?278 个工�?Schema 加载到模型上下文中，
而是使用渐进式发现——约 33 个领域命令用于常见操作，按需获取补充工具�?Schema�?

```bash
# 快速开�?
gdmcp --json doctor
gdmcp --json scenes tree --depth 4
gdmcp --json scripts read res://player.gd --lines 1:200
gdmcp --json nodes properties set /root/Player --property speed --value 300
```

**安装**：打开 Godot 编辑�?�?MCP 面板 �?**CLI Tools** 标签页，或从
[GitHub Releases](https://github.com/Karl0007/Godot-MCP-Native/releases) 下载�?
完整文档�?[CLI README](https://github.com/yurineko73/Godot-MCP-Native/blob/main/cli/gdmcp/README.md) �?[CLI Reference](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/gdmcp-cli-reference.md)�?

**Skill**：从 [skills/gdmcp/](https://github.com/yurineko73/Godot-MCP-Native/blob/main/skills/gdmcp) 安装配套 Codex Skill，教你的代理使用 CLI 工作流�?
�?[skills/gdmcp/](https://github.com/yurineko73/Godot-MCP-Native/blob/main/skills/gdmcp) 复制�?`~/.codex/skills/gdmcp/`�?

## 📦 安装

### 方法 1：资源库（推荐）
1. 打开您的 Godot 项目
2. 进入编辑器中�?**AssetLib** 标签�?
3. 搜索 "Godot MCP Native"
4. 点击 **下载** 然后 **安装**

### 方法 2：手动安�?
1. 下载或克隆此仓库
2. �?`addons/godot_mcp` 文件夹复制到项目�?`addons/` 目录
3. �?Godot 中打开项目
4. 进入 **项目 > 项目设置 > 插件**
5. 启用 "Godot MCP Native" 插件

## 🔧 使用

### 启用插件
1. 打开 **项目 > 项目设置 > 插件**
2. 在列表中找到 "Godot MCP Native"
3. 将状态设置为 **启用**

### 一键引导（scripts/gdmcp-bootstrap.ps1�?

不想读完�?README �?Agent 或用户，可以�?PowerShell 引导脚本完成安装/启动/状态检查：

```powershell
# 安装插件到项目（复制 addons/、写�?[editor_plugins]、记录端口）
.\scripts\gdmcp-bootstrap.ps1 install -ProjectPath C:\MyGame -Port 9080

# 启动�?MCP 服务器的编辑�?
.\scripts\gdmcp-bootstrap.ps1 start -ProjectPath C:\MyGame -Port 9080

# 状态检查：Godot 是否存在、插件是否安装并启用、probe 自动加载、端口是否监�?
.\scripts\gdmcp-bootstrap.ps1 doctor -ProjectPath C:\MyGame -Port 9080
```

`doctor` 逐项输出通过/失败及失败时的下一步指引（Godot 缺失 �?设置 `-GodotExe`/`GODOT4_BIN`；插件缺�?�?运行 install；端口空�?�?运行 start）。所有命令幂等�?

**Godot 引擎选择**：脚本按此顺序解析——显�?`-GodotExe` > 持久化配置（`~/.godot-mcp-bootstrap.json`，由 `install -SaveGodotExe -GodotExe <路径>` 写入�? `GODOT4_BIN` > PATH > 目录扫描。目录扫描会**优先匹配项目声明的版�?*（`config/features` 中的 `"4.x"`，例如声�?`"4.7"` 的项目会选择 `Godot_v4.7.*.exe`），`start`/`doctor` 在引擎与项目声明版本不一致时输出提示�?

**�?Godot 实例并行**：每个项目使用独立端口。每个编辑器持有自己�?`user://` 状态（设置、工具状态）并绑定自己的端口，因此不同项目甚至不�?Godot 版本可以并行运行�?

```powershell
.\scripts\gdmcp-bootstrap.ps1 install -ProjectPath C:\GameA -Port 9080
.\scripts\gdmcp-bootstrap.ps1 start  -ProjectPath C:\GameA -Port 9080
.\scripts\gdmcp-bootstrap.ps1 install -ProjectPath C:\GameB -Port 9081
.\scripts\gdmcp-bootstrap.ps1 start  -ProjectPath C:\GameB -Port 9081
```

### 启用补充工具

插件注册�?**278 个工�?*，但 `tools/list` 默认只返�?**33 个核心工�?*。其�?**245 个补充工�?*（运行时探针�?D 场景、媒体编辑、导出、分析、批量操作等）默认禁用，需要手动启用：

1. 打开 Godot 编辑器的 **MCP** 停靠面板（视�?> 底部面板 > MCP�?
2. �?**Tools** 列表中勾选需要启用的工具
3. 启用状态持久化�?`user://mcp_tool_state.cfg`，立即生�?

> 无头环境提示：手动编�?`mcp_tool_state.cfg` 后必须重�?`[meta]` 段的 `checksum`（对 `tools/<key>=<value>` 行以 `\n` 连接计算 MD5），否则改动会被忽略。先关闭编辑器再编辑——退出时会重写该文件�?

**运行时探�?*：运行时工具（播�?调试/UI 检查）需要游戏内�?`MCPRuntimeProbe` 自动加载。插件启用时会自动写�?`project.godot` �?`[autoload]` 段；卸载插件时请删除对应行�?

### 配置 MCP 服务�?
插件提供两种传输模式�?

#### HTTP 模式（用于远程访问）
- 适用场景：基于网络的 AI 集成
- 配置：在插件设置中设�?`transport_mode = "http"` 并配�?`http_port`（默认：9080�?
- 可选：启用 `auth_enabled` 并设�?`auth_token` 以保障安�?

#### 无头 / 命令行启�?
以无�?MCP 服务器模式启动编辑器�?
```bash
godot --editor --path /path/to/project -- --mcp-server
```
面板中修改的设置会保存到 `user://mcp_settings.cfg`。无�?`--mcp-server` 模式�?*读取并应用此文件**，因此你在编辑器 UI 中配置的 `http_port` / `transport_mode` / 认证等选项在无头运行时同样生效�?

若要**并行运行多个实例**（多个项目，或隔离的测试实例），可通过命令行参数按实例覆盖端口——命令行参数优先级高于配置文件：
```bash
godot --editor --path /path/to/projectA -- --mcp-server --mcp-port=9080
godot --editor --path /path/to/projectB -- --mcp-server --mcp-port=19081
```

| 参数 | 取�?| 作用 |
| --- | --- | --- |
| `--mcp-port=N` | `1024`–`65535` | 覆盖 `http_port`（超出范围的值将被忽略） |
| `--mcp-transport=MODE` | `http` \| `stdio` | 覆盖 `transport_mode`（未知值将被忽略） |

### 连接 Claude Desktop

首先安装 `mcp-remote` 包：
```bash
npm install mcp-remote
```

#### HTTP 模式配置
```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:9080/mcp"
      ]
    }
  }
}
```

### 连接 Cursor / Trae

#### HTTP 模式配置

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

带身份验证：
```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp",
      "headers": {
        "Authorization": "Bearer your-secret-token-here"
      }
    }
  }
}
```

### 连接 Cline

#### HTTP 模式配置
编辑 Cline 配置文件（`cline_mcp_settings.json`）：

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp",
      "type": "streamableHttp",
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

### 连接 OpenCode

#### HTTP 模式配置

```json
{
  "mcp": {
    "godot-mcp": {
      "type": "remote",
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

### 连接 Codex

#### HTTP 模式配置

```toml
[mcp_servers]

[mcp_servers.godot-mcp]
type = "streamableHttp"
url = "http://localhost:9080/mcp"
```

## 💬 示例提示

连接后，您可以通过 Claude �?Godot 项目交互�?

```
@mcp godot-mcp read godot://script/current

我需要帮助优化我的玩家移动代码。能提出改进建议吗？
```

```
@mcp godot-mcp get-scene-tree

在场景中间添加一个立方体，并创建一个相机看向它�?
```

```
创建一个主菜单，包含开始、选项和退出按�?
```

```
实现一个带有动态光照的昼夜循环系统
```

## 📚 可用命令

**278 个工�?*—�?3 核心 + 245 补充。核心工具默认启用；补充工具需要在 MCP 面板中启用（见「启用补充工具」）�?

### Node-Write�? 核心�?
- `create-node` - �?Godot 场景树中创建新节点。返回节点路径和类型�?
- `delete-node` - �?Godot 场景树中删除节点。此操作是破坏性的，无法撤销�?
- `update-node-property` - 更新特定节点的属性。支持常见属性类型并自动进行类型转换�?
- `duplicate-node` - 在场景树中复制节点及其子节点。返回新节点的路径�?
- `move-node` - 将节点移动到场景树中的新父节点下。可选择保留全局变换�?
- `rename-node` - 重命名场景树中的节点。新名称必须在同级节点中唯一�?

### Node-Read�? 核心�?
- `get-node-properties` - 获取场景树中特定节点的所有属性�?
- `list-nodes` - 列出当前场景或特定父节点下的所有节点�?
- `get-scene-tree` - 获取从场景根节点开始的完整场景树层级。返回包含节点类型的完整树结构�?

### Node-Write-Advanced�? 补充�?
- `add-resource` - 向目标节点添加资源子节点�?
- `set-anchor-preset` - �?Control 节点设置锚点预设�?
- `connect-signal` - 将一个节点的信号连接到另一个节点�?
- `disconnect-signal` - 断开一个节点到另一个节点的信号连接�?
- `set-node-groups` - 设置节点所属的组�?

### Node-Advanced�?2 补充�?
- `get-node-groups` - 获取节点所属的组�?
- `find-nodes-in-group` - 查找特定组中的所有节点�?
- `batch-update-node-properties` - 在一个编辑器 UndoRedo 操作中更新多个节点属性。适用于需要在单步中撤销的事务式场景编辑�?
- `batch-scene-node-edits` - 在单个编辑器 UndoRedo 操作中应用多个创�?删除场景节点编辑，使整个结构变更可在单步中撤销�?
- `audit-scene-node-persistence` - 审计当前编辑场景的节点所有者和持久化状态。报告影响场景保存和继承的缺失或无效的所有者关系�?
- `audit-scene-inheritance` - instance roots
- `batch-add-nodes` - 在一�?UndoRedo 操作中创建多个节点。每个条目：{type, name, parent_path, properties}�?
- `batch-set-property` - 在当前场景中为所有指定类型的节点设置属性（一�?UndoRedo 操作）�?
- `find-nodes-by-type` - 查找当前场景中所有指定类的节点�?
- `find-signal-connections` - 查找当前场景中的所有信号连接，可按信号或节点过滤�?
- `find-node-references` - 在所�?.tscn/.gd/.tres/.gdshader 文件中搜索对模式的引用�?
- `cross-scene-set-property` - 在多个场景文件中为指定类型的节点设置属性。需�?force=true 才能应用；dry_run 预览更改�?

### Script�? 核心�?
- `list-project-scripts` - 列出项目中所�?GDScript 文件�?gd）。返回相对于 res:// 的路径�?
- `read-script` - 读取 GDScript 文件�?gd）的内容。返回完整的脚本源代码�?
- `create-script` - not resource files.
- `modify-script` - 修改现有 GDScript 文件的内容。可以替换整个内容或特定行�?
- `get-current-script` - 获取 Godot 编辑器中当前正在编辑的脚本�?
- `attach-script` - 将脚本附加到节点�?
- `execute-script` - 在编辑器上下文中执行脚本�?

### Script-Advanced�? 补充�?
- `analyze-script` - 分析 GDScript 文件并报告代码质量问题�?
- `validate-script` - 验证脚本文件的语法错误�?
- `search-in-files` - 在项目文件中搜索文本�?
- `list-project-script-symbols` - extends
- `find-script-symbol-definition` - �?GDScript �?C# 项目文件中查找脚本符号的定义位置�?
- `find-script-symbol-references` - C#
- `rename-script-symbol` - 使用标识符边界文本替换在项目文件中重命名脚本符号。支持在应用更改前进行试运行预览�?
- `open-script-at-line` - �?Godot 编辑器中的指定行号打开脚本文件�?

### Scene�? 核心�?
- `create-scene` - 创建一个新�?Godot 场景并包含根节点。场景保存到指定路径�?
- `save-scene` - saves to the current scene's path.
- `open-scene` - 从项目中打开场景文件。如果当前有打开的场景，则先关闭它�?
- `get-current-scene` - including name

### Scene-Advanced�?0 补充�?
- `get-scene-structure` - names
- `list-project-scenes` - 列出项目中所有场景文件（.tscn）。返回相对于 res:// 的路径�?
- `list-open-scenes` - 列出 Godot 编辑器中当前打开的场景标签页�?
- `close-scene-tab` - or activate a specified scene tab and close it.
- `delete-scene` - 删除项目的场景文件（.tscn）及�?.import 附加文件�?
- `add-scene-instance` - 将场景（.tscn）实例化为节点的子节点�?
- `play-scene` - 播放主场景、当前场景或指定场景路径�?
- `stop-scene` - 停止正在运行的游戏场景�?
- `get-scene-file-content` - 读取场景文件的原始文本内容�?
- `get-scene-exports` - 列出场景文件中每个脚本节点的所�?@export 属性�?

### Editor�? 核心�?
- `get-editor-state` - including active scene and selection info.
- `run-project` - 运行当前项目或指定场景。以运行模式启动游戏�?
- `stop-project` - 停止当前正在运行的项目并返回编辑器模式�?
- `execute-editor-script` - 在编辑器中执行脚本，可访问编辑器 API�?

### Editor-Advanced�?6 补充�?
- `get-selected-nodes` - 获取编辑器中当前选中节点的列表�?
- `set-editor-setting` - 设置编辑器设置值。某些设置需要重启编辑器才能生效�?
- `get-editor-screenshot` - 截取编辑器视口的屏幕截图并保存到文件�?
- `get-signals` - 获取节点的所有信号及其连接�?
- `reload-project` - 重新扫描项目文件系统并重新加载脚本。适用于外部文件更改后�?
- `select-node` - 在当前编辑的场景中选择一个节点并在检查器中聚焦它�?
- `select-file` - �?Godot 文件系统面板中选择一个项目文件�?
- `get-inspector-properties` - 检查节点或资源并返回与检查器类似的属性元数据和序列化值�?
- `list-export-presets` - 列出 export_presets.cfg 中的导出预设�?
- `inspect-export-templates` - 检查本地安装的适用于当前编辑器版本�?Godot 导出模板�?
- `validate-export-preset` - 根据 export_presets.cfg 和本地模板可用性验证导出预设�?
- `run-export` - 为配置的预设运行 Godot CLI 导出�?
- `get-editor-errors` - 从输出面板、脚本编辑器分析面板、调试器错误标签页和日志文件收集编辑器错误和警告�?
- `get-output-log` - 读取编辑器输出面板或日志文件，可选过滤�?
- `set-auto-dismiss` - 启用或禁用阻塞编辑器对话框的自动关闭�?
- `get-editor-camera` - 读取 3D 编辑器视口相机的位置、旋转、FOV 和裁剪面�?
- `set-editor-camera` - 移动或旋�?3D 编辑器视口相机，可选择注视目标和设�?FOV�?
- `get-editor-selection` - 读取当前编辑器选区（顶层或所有选中节点）�?
- `select-nodes` - 在场景树中选择一个或多个节点。模式：replace、add、remove。可选聚�?检查单个节点�?
- `clear-editor-selection` - 清除当前编辑器节点选区�?
- `reload-plugin` - 通过禁用再启用重新加�?Godot MCP 插件。MCP 连接会短暂断开后重连�?
- `export-project` - 为预设生�?Godot CLI 导出命令（debug �?release）。Godot 4 不支持从编辑器插件直接导出�?
- `get-export-info` - 读取导出配置：导出预设是否存在、Godot 可执行文件路径和模板安装情况�?
- `list-android-devices` - 列出 adb 可见�?Android 设备（从编辑器设置或 PATH）�?
- `get-android-preset-info` - �?export_presets.cfg 读取 Android 导出预设的配置�?
- `deploy-to-android` - 导出 Android 预设并通过 adb �?APK 安装到连接的设备�?

### Debug�? 核心�?
- `get-editor-logs` - type
- `debug-print` - 向编辑器控制台输出调试消息�?
- `clear-output` - 清除编辑器输出面板�?

### Debug-Advanced�?2 补充�?
- `get-performance-metrics` - 从编辑器或运行中的游戏获取性能指标�?
- `get-debugger-sessions` - 列出 Godot 编辑器调试器会话及其活动/断点状态�?
- `set-debugger-breakpoint` - 在活动的 Godot 调试器会话中启用或禁用断点�?
- `send-debugger-message` - 向活动的 Godot 调试器会话发送自定义调试器消息�?
- `toggle-debugger-profiler` - 在活动的 Godot 调试器会话中切换引擎性能分析器�?
- `get-debugger-messages` - 读取�?Godot 调试器桥捕获的自定义消息�?
- `add-debugger-capture-prefix` - 允许调试器桥捕获具有给定前缀的自定义 EngineDebugger 消息�?
- `get-debug-stack-frames` - 返回最新捕获的脚本堆栈帧，并从已断点的会话请求新的堆栈转储�?
- `get-debug-stack-variables` - 返回堆栈帧的最新捕获的局�?成员/全局变量，并请求新的变量转储�?
- `install-runtime-probe` - 安装用于调试的运行时探针�?
- `remove-runtime-probe` - 移除运行时探针�?
- `request-debug-break` - 请求调试器在当前执行点断点�?
- `send-debug-command` - 向调试器发送命令�?
- `get-runtime-info` - 获取运行中游戏的运行时信息�?
- `await-scene-ready` - 轮询运行时直到指定场景加载就绪�?
- `get-runtime-scene-tree` - 从运行中的游戏获取场景树�?
- `inspect-runtime-node` - 检查运行中游戏中的节点�?
- `update-runtime-node-property` - 更新运行中游戏中的节点属性�?
- `call-runtime-node-method` - 调用运行中游戏中节点的方法�?
- `evaluate-runtime-expression` - 在运行中的游戏上下文中求值表达式�?
- `await-runtime-condition` - 在运行中游戏中等待条件为真�?
- `assert-runtime-condition` - 在运行中游戏中断言一个条件�?
- `get-debug-threads` - 从活动的 Godot 调试会话返回 DAP 风格的调试器线程�?
- `get-debug-state-events` - 从桥读取记录的调试器断点/恢复/停止状态转换�?
- `get-debug-output` - 读取由编辑器桥捕获的分类运行时调试器输出�?
- `get-debug-scopes` - 将最新捕获的堆栈变量分组为帧�?DAP 风格作用域�?
- `get-debug-variables` - with optional pagination for large arrays and dictionaries.
- `expand-debug-variable` - with pagination for arrays and dictionaries.
- `evaluate-debug-expression` - 在给定帧的暂停脚本调试器上下文中求值表达式�?
- `debug-step-into` - 在调试器中步入下一个函数调用�?
- `debug-step-over` - 在调试器中步过下一行�?
- `debug-step-out` - 在调试器中步出当前函数�?
- `debug-continue` - 在调试器中继续执行�?
- `debug-step-into-and-wait` - 步入并等待调试器暂停�?
- `debug-step-over-and-wait` - 步过并等待调试器暂停�?
- `debug-step-out-and-wait` - 步出并等待调试器暂停�?
- `debug-continue-and-wait` - 继续执行并等待调试器暂停或完成�?
- `await-debugger-state` - 等待特定的调试器状态�?
- `get-runtime-performance-snapshot` - 从运行中的游戏获取性能快照�?
- `get-runtime-memory-trend` - 从运行中的游戏获取内存使用趋势�?
- `create-runtime-node` - 在运行中的游戏中创建节点�?
- `delete-runtime-node` - 在运行中的游戏中删除节点�?
- `simulate-runtime-input-event` - 在运行中的游戏中模拟输入事件�?
- `simulate-runtime-input-action` - 在运行中的游戏中模拟输入动作�?
- `list-runtime-input-actions` - 列出运行中游戏中可用的输入动作�?
- `upsert-runtime-input-action` - 在运行中的游戏中创建或更新输入动作�?
- `remove-runtime-input-action` - 从运行中的游戏中移除输入动作�?
- `list-runtime-animations` - 列出运行中游戏中可用的动画�?
- `play-runtime-animation` - 播放运行中游戏中的动画�?
- `stop-runtime-animation` - 停止运行中游戏中的动画�?
- `get-runtime-animation-state` - 获取运行中游戏中动画的状态�?
- `get-runtime-animation-tree-state` - 获取运行中游戏中动画树的状态�?
- `set-runtime-animation-tree-active` - 设置运行中游戏中动画树的活动/非活动状态�?
- `travel-runtime-animation-tree` - 在运行中游戏中导航到动画树的新状态�?
- `get-runtime-material-state` - 获取运行中游戏中材质的状态�?
- `get-runtime-theme-item` - 获取运行中游戏中的主题项�?
- `set-runtime-theme-override` - 在运行中的游戏中设置主题覆盖�?
- `clear-runtime-theme-override` - 在运行中的游戏中清除主题覆盖�?
- `get-runtime-shader-parameters` - 获取运行中游戏中的着色器参数�?
- `set-runtime-shader-parameter` - 设置运行中游戏中的着色器参数�?
- `list-runtime-tilemap-layers` - 列出运行中游戏中�?TileMap 图层�?
- `get-runtime-tilemap-cell` - 获取运行中游戏中�?TileMap 单元格�?
- `set-runtime-tilemap-cell` - 设置运行中游戏中�?TileMap 单元格�?
- `list-runtime-audio-buses` - 列出运行中游戏中的音频总线�?
- `get-runtime-audio-bus` - 获取运行中游戏中的音频总线�?
- `update-runtime-audio-bus` - 更新运行中游戏中的音频总线�?
- `get-runtime-screenshot` - 截取运行中游戏的屏幕截图�?
- `run-test-scenario` - 执行测试场景：可选播放场景，运行步骤（输入、等待、断言、截图），返回通过/失败结果�?
- `assert-node-state` - 用运算符（eq、neq、gt、lt、gte、lte、contains）断言运行时节点属性与期望值�?
- `assert-screen-text` - 断言文本字符串出现在运行�?UI 元素中（需要带文本的可�?Control 节点）�?
- `run-stress-test` - 向运行中的游戏发�?N 秒随机输入并检查崩溃�?
- `get-test-report` - 将累积断言的测试结果收集并格式化为测试报告�?
- `start-recording` - 开始录制运行中游戏的输入事件（键盘、鼠标、动作）�?
- `stop-recording` - 停止录制输入事件并返回捕获的事件序列�?
- `replay-recording` - 以指定速度在运行中的游戏里回放录制的输入事件序列�?
- `find-ui-elements` - 列出运行中游戏的可见 UI 元素（Button、Label、LineEdit、TextEdit、OptionButton、CheckBox）�?
- `click-button-by-text` - 按文本点击运行中游戏的可见按钮�?
- `wait-for-node` - 检查运行中游戏场景树中是否存在节点�?
- `find-nearby-nodes` - 查找运行中游戏某个位置半径内的节点（2D/3D）�?
- `navigate-to` - 计算导航建议（按键、相机旋转、时长）以将 3D 玩家移向运行中游戏的目标�?
- `move-to` - 通过注入移动按键�?3D 玩家移向运行中游戏的目标。到达或超时后返回�?
- `watch-signals` - 在一段时间内监听运行时节点的信号发射。需要通过探针进行运行时场景检查�?

### Project�? 核心�?
- `get-project-info` - including name
- `get-project-settings` - 获取项目设置。可选择按前缀过滤�?
- `list-project-resources` - .res

### Project-Advanced�?1 补充�?
- `create-resource` - 创建新的 Godot 资源文件�?tres）。支持常见的资源类型�?
- `get-project-structure` - 获取项目结构和文件组织�?
- `list-project-tests` - including whether each test is currently runnable.
- `run-project-test` - 运行单个项目测试脚本。Python 集成测试使用 python 执行。GUT 单元测试�?addons/gut 可用时通过 Godot 无头模式执行�?
- `run-project-tests` - 从目录中发现并运行多个项目测试。使用与 list_project_tests 相同的框架过滤器，并汇总通过/失败计数�?
- `list-project-input-actions` - including serialized input events.
- `upsert-project-input-action` - �?ProjectSettings 中创建或更新项目 InputMap 动作并保�?project.godot�?
- `remove-project-input-action` - �?ProjectSettings 中移除项�?InputMap 动作并保�?project.godot�?
- `list-project-autoloads` - singleton flag
- `list-project-global-classes` - 列出通过 class_name 元数据注册的项目全局脚本类�?
- `get-class-api-metadata` - 获取引擎 ClassDB 类或项目全局脚本类的类型�?API 元数据�?
- `inspect-csharp-project-support` - including target frameworks
- `compare-render-screenshots` - RMSE
- `inspect-tileset-resource` - atlas tiles
- `reimport-resources` - 重新导入项目资源�?
- `get-import-metadata` - 获取资源导入元数据�?
- `get-resource-uid-info` - 获取资源 UID 信息�?
- `fix-resource-uid` - 修复资源 UID 问题�?
- `get-resource-dependencies` - 获取资源依赖关系�?
- `scan-missing-resource-dependencies` - 扫描缺失的资源依赖�?
- `scan-cyclic-resource-dependencies` - 扫描循环资源依赖�?
- `detect-broken-scripts` - 检测项目中的损坏脚本�?
- `audit-project-health` - 审计项目健康和完整性�?
- `get-filesystem-tree` - 返回项目文件系统树，可�?glob 过滤和深度限制�?
- `search-files` - 按名称（模糊�?glob）搜索路径下的文件�?
- `set-project-setting` - 设置 ProjectSettings 值并保存 project.godot。字符串自动推断类型�?
- `uid-to-project-path` - 将资�?UID 字符串转换为项目路径�?
- `project-path-to-uid` - 将项目路径转换为资源 UID 字符串�?
- `add-autoload` - �?ProjectSettings 添加自动加载单例�?
- `remove-autoload` - �?ProjectSettings 移除自动加载单例�?
- `get-project-statistics` - 收集项目统计：按扩展名统计脚本、场景、资源和图像文件数量�?
- `get-autoload` - 读取项目自动加载单例的属性和脚本路径�?
- `read-resource` - 读取资源文件�?tres/.res）并返回其编辑器可见属性�?
- `edit-resource` - 修改资源文件的属性并保存�?
- `get-resource-preview` - 生成资源�?PNG 预览（base64）：图像、纹理或任何有视觉表示的资源�?
- `get-input-actions` - 列出项目 InputMap 动作及其绑定的输入事件和死区�?
- `set-input-action` - 创建或更�?InputMap 动作及其绑定事件，保存到 ProjectSettings 并更新运行时 InputMap�?
- `analyze-signal-flow` - 分析当前场景中的信号连接：源、目标和连接数�?
- `analyze-scene-complexity` - 分析场景复杂度：节点数、深度、节点类型、脚本和潜在问题�?
- `detect-circular-dependencies` - 使用 DFS 循环检测检测循环场景依赖（.tscn 文件互相引用）�?
- `find-unused-resources` - 扫描项目中未被任何场景、脚本或资源文件引用的资源文件�?

### World�?2 补充�?
- `add-mesh-instance` - 创建 MeshInstance3D，支持基本体网格（box/sphere/cylinder/capsule/plane/quad/prism/torus）或�?.glb/.gltf/.obj 文件加载
- `setup-lighting` - 添加 DirectionalLight3D、OmniLight3D �?SpotLight3D，支持颜色、能量和阴影设置�?
- `set-material-3d` - �?MeshInstance3D 表面创建或更�?StandardMaterial3D，支�?PBR 参数（albedo/metallic/roughness/emission/transparenc
- `setup-environment` - 创建或更�?WorldEnvironment，支持背景模式、程序化天空、环境光和色调映射设置�?
- `setup-camera-3d` - 创建或配�?Camera3D，支持位置、旋转、FOV、近远裁剪面和当前相机标志�?
- `add-gridmap` - 创建 GridMap 节点，可指定 MeshLibrary 资源并设置单元格大小�?
- `setup-collision` - 向物理体或区域节点添�?CollisionShape2D �?CollisionShape3D。支�?2D（rectangle/circle/capsule/segment/convex）和 3D（b
- `set-physics-layers` - 设置物理节点�?collision_layer �?�?collision_mask。接受整数位掩码或层号数组（1-32）�?
- `get-physics-layers` - 读取物理节点�?collision_layer �?collision_mask，包括解析后的层名称�?
- `add-raycast` - 向节点添�?RayCast2D �?RayCast3D，支持目标位置、碰撞掩码和命中设置�?
- `setup-physics-body` - 配置物理体属性。CharacterBody：motion_mode、floor 设置、max_slides、slide_on_ceiling。RigidBody：mass、gravity_scale�?
- `get-collision-info` - 读取物理节点的碰撞形状、射线、层和物理体设置（含子节点）�?
- `setup-navigation-region` - 创建 NavigationRegion2D �?NavigationRegion3D，支持配置代理和单元格属性�?
- `bake-navigation-mesh` - 烘焙 NavigationRegion3D 导航网格，或从轮�?源几何构�?NavigationRegion2D 多边形�?
- `setup-navigation-agent` - 创建 NavigationAgent2D �?NavigationAgent3D，支持寻路和避障设置�?
- `set-navigation-layers` - 设置导航区域或代理的 navigation_layers。接受位掩码、层号数组或 ProjectSettings 中的命名层�?
- `get-navigation-info` - 列出节点下的导航区域和代理，包括其属性和命名层�?
- `create-particles` - 创建 GPUParticles2D �?GPUParticles3D 节点，支持数量、寿命、one_shot、爆发力和随机性设置�?
- `set-particle-material` - 配置 GPUParticles 节点�?ParticleProcessMaterial：方向、扩散、速度、重力、缩放、颜色、发射形状、阻尼�?
- `set-particle-color-gradient` - �?{offset, color} 停止点数组设�?GPUParticles 节点材质的颜色渐变�?
- `apply-particle-preset` - 应用预定义粒子预设：explosion、fire、smoke、sparks、rain、snow、magic �?dust�?
- `get-particle-info` - 读取 GPUParticles 节点状态：数量、寿命、one_shot、爆发力、随机性、发射状态和材质属性�?

### Media-Animation�?4 补充�?
- `list-animations` - 列出 AnimationPlayer 节点上的所有动画，包括长度、循环模式和轨道数�?
- `create-animation` - �?AnimationPlayer 节点上创建新动画，支持长度和循环模式�?
- `add-animation-track` - 向动画添加轨道。轨道类型：value、position_2d、rotation_2d、scale_2d、method、bezier、blend_shape�?
- `set-animation-keyframe` - 在动画轨道的指定时间插入或更新关键帧�?
- `get-animation-info` - 读取动画详情：长度、循环模式、步长和每个轨道的关键帧�?
- `remove-animation` - �?AnimationPlayer 节点移除动画（可撤销）�?
- `create-animation-tree` - 创建 AnimationTree 节点，根�?AnimationNodeStateMachine，可链接 AnimationPlayer�?
- `get-animation-tree-structure` - 读取 AnimationTree 结构：根节点类型、状态机状�?过渡或混合树节点�?
- `add-state-machine-state` - �?AnimationNodeStateMachine 添加状态。状态类型：animation、blend_tree �?state_machine�?
- `remove-state-machine-state` - �?AnimationNodeStateMachine 移除状态（可撤销）�?
- `add-state-machine-transition` - �?AnimationNodeStateMachine 中两个状态之间添加过渡�?
- `remove-state-machine-transition` - 移除 AnimationNodeStateMachine 中两个状态之间的过渡（可撤销）�?
- `set-blend-tree-node` - �?AnimationNodeBlendTree 中添加或替换节点。类型：Animation、Add2、Blend2、Add3、Blend3、TimeScale、TimeSeek、Transition
- `set-tree-parameter` - 设置 AnimationTree 参数（自动添�?'parameters/' 前缀）�?

### Media-Audio�? 补充�?
- `get-audio-bus-layout` - 读取完整�?AudioServer 总线布局：名称、音量、solo/mute、send 和每条总线的效果及参数�?
- `add-audio-bus` - �?AudioServer 添加新音频总线，支持音量、send、solo �?mute 设置�?
- `set-audio-bus` - 更新音频总线属性：volume_db、solo、mute、bypass_effects、send 或重命名�?
- `add-audio-bus-effect` - 向总线添加音频效果。类型：reverb、chorus、delay、compressor、limiter、phaser、distortion、lowpassfilter、highpassfilter、b
- `add-audio-player` - 添加 AudioStreamPlayer、AudioStreamPlayer2D �?AudioStreamPlayer3D，支持流、音量、总线和空间设置�?
- `get-audio-info` - 列出节点下的音频播放器，包括流、音量、总线、自动播放和空间属性�?

### Media-Theme�? 补充�?
- `create-theme` - 创建新的 Theme 资源�?tres），可设置默认字体大小�?
- `set-theme-color` - �?Control 节点上设置主题颜色覆盖（可撤销）�?
- `set-theme-constant` - �?Control 节点上设置主题常量覆盖（可撤销）�?
- `set-theme-font-size` - �?Control 节点上设置主题字体大小覆盖（可撤销）�?
- `set-theme-stylebox` - �?Control 节点上设�?StyleBoxFlat 主题覆盖，支持背景、边框、圆角和内边距（可撤销）�?
- `setup-control` - 配置 Control 节点布局：锚点预设、最小尺寸、尺寸标志、边距、间距和增长方向（可撤销）�?
- `get-theme-info` - 读取 Control 节点的主题路径、类型列表和所有主题覆盖（颜色、常量、字体大小、样式盒）�?

### Media-Shader�? 补充�?
- `create-shader` - 创建着色器文件�?gdshader），支持 spatial、canvas_item、particles、sky 模板或自定义内容�?
- `read-shader` - 读取着色器文件内容�?
- `edit-shader` - 编辑着色器文件，支持全量替换或查找替换�?
- `assign-shader-material` - 从着色器文件创建 ShaderMaterial 并分配给 CanvasItem �?MeshInstance3D 节点�?
- `set-shader-param` - 设置节点 ShaderMaterial 的着色器 uniform。值会自动从字符串解析�?
- `get-shader-params` - 读取节点 ShaderMaterial 的所有着色器 uniform�?

### Media-TileMap�? 补充�?
- `tilemap-set-cell` - �?TileMapLayer 或旧�?TileMap 节点上设置单元格（可撤销）�?
- `tilemap-fill-rect` - 用瓦片填�?TileMapLayer 或旧�?TileMap 的矩形区域（可撤销）�?
- `tilemap-get-cell` - �?TileMapLayer 或旧�?TileMap 读取单元格�?
- `tilemap-clear` - 清空 TileMapLayer 或旧�?TileMap（可选单层），可撤销�?
- `tilemap-get-info` - 读取 TileMapLayer/TileMap 信息：图层、已用单元格、TileSet 源和瓦片大小�?
- `tilemap-get-used-cells` - 列出 TileMapLayer 或旧�?TileMap 图层的已用单元格及其�?ID�?

### Bootstrap�? 核心�?
- `godot-status` - 报告 MCP 服务器就绪状态：传输、端口、认证、工具数量和运行时探针状态。首先调用以了解服务器状态�?
- `godot-ensure-ready` - 确保 MCP 服务器就绪：修复缺失的运行时探针自动加载并报告服务器状态�?
- `get-server-info` - 读取 MCP 服务器基础设施信息：插件版本、传输、端口、认证、工具注册数量和探针状态�?

## 🔒 安全建议

- �?**生产环境**：始终启用身份验证（`auth_enabled = true`�?
- �?**令牌**：使用强令牌（≥16 个字符，包含字母、数字、特殊字符）
- �?**存储**：不要将令牌提交到版本控�?
- ⚠️ **远程访问**：使�?HTTPS（TLS/SSL）进行网络访�?

## 📋 要求

- Godot Engine 4.x（推�?4.5 或更高版本）
- 无额外依赖（原生实现�?

## 📖 文档

详细文档请查�?`docs/current/` 文件夹：
- [快速开始指南](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/quickstart.md)
- [架构设计](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/architecture.md)
- [工具参考](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/tools-reference.md)
- [CLI 参考](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/gdmcp-cli-reference.md)
- [发布流程](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/development/release-workflow.md)
- [测试指南](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/testing-guide.md)

## 🤝 贡献

欢迎贡献！请随时提交 Pull Request�?

## 📄 许可�?

本项目采�?MIT 许可�?- 详见 [LICENSE](https://github.com/yurineko73/Godot-MCP-Native/blob/main/LICENSE) 文件�?

## 👤 作�?

**yurineko73**

## 🙏 致谢

- Godot 引擎团队带来的出色游戏引�?
- 模型上下文协�?(MCP) 规范
- Anthropic �?Claude AI 启发了此集成

---

**注意**：这是一个社区插件，�?Godot Engine �?Anthropic 无官方关联�?
