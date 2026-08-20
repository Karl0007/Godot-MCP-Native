# Godot MCP Native (Model Context Protocol)

[中文版本](https://github.com/yurineko73/Godot-MCP-Native/blob/main/README.zh.md)

![Godot Version](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.1.0-brightgreen)

A powerful Godot Engine plugin that integrates AI assistants (Claude, etc.) via the Model Context Protocol (MCP). Enable AI to directly read and modify your Godot projects - scenes, scripts, nodes, and resources - all through natural language.

## 🚀 Features

- **Full Project Access**: AI assistants can read and modify scripts, scenes, nodes, and resources
- **Native Implementation**: No Node.js dependency required - runs entirely within Godot
- **Real-time Editing**: Apply AI suggestions directly in the editor
- **Comprehensive Tool Set** (278 tools �?33 core + 245 supplementary):
  - **Node Tools** (9 core + 11 advanced): Create, modify, manage scene nodes, duplicate, move, rename, signal connections, anchor presets, group management, batch operations, scene auditing
  - **Script Tools** (7 core + 8 advanced): Edit, analyze, create, attach, validate GDScript and C# files, execute scripts, search in files, symbol indexing, definition & reference lookup
  - **Scene Tools** (4 core + 4 advanced): Manipulate scene structure, save scenes, list/open/close scene tabs, project scene listing
  - **Editor Tools** (4 core + 12 advanced): Control editor functionality, screenshot, signal inspection, filesystem reload, node/file selection, export management, property inspector
  - **Debug Tools** (3 core + 68 advanced): Logging, debugger sessions, breakpoints, stack/variable inspection, profilers, runtime probe, animation/audio/shader/tilemap runtime control, debug execution control, await_scene_ready
  - **Project Tools** (3 core + 23 advanced): Access project settings, list resources, create resources, run tests, manage input mappings, inspect autoloads/global classes, resource diagnostics & health audit

## 🖥�?gdmcp CLI

This plugin includes a companion **gdmcp CLI** for coding agents (Codex, Claude Code, etc.)
that reduces model context usage by ~30,000 tokens compared to MCP. Install it from the
**CLI Tools** tab in the MCP dock panel, or download from
[GitHub Releases](https://github.com/Karl0007/Godot-MCP-Native/releases).

See [CLI README](https://github.com/yurineko73/Godot-MCP-Native/blob/main/cli/gdmcp/README.md) for details.

## 📦 Installation

### Method 1: Asset Library (Recommended)
1. Open your Godot project
2. Go to **AssetLib** tab in the editor
3. Search for "Godot MCP Native"
4. Click **Download** and then **Install**

### Method 2: Manual Installation
1. Download or clone this repository
2. Copy the `addons/godot_mcp` folder to your project's `addons/` directory
3. Open your project in Godot
4. Go to **Project > Project Settings > Plugins**
5. Enable "Godot MCP Native" plugin

## 🔧 Usage

### Enabling the Plugin
1. Open **Project > Project Settings > Plugins**
2. Locate "Godot MCP Native" in the list
3. Set the status to **Enable**

### Enabling Supplementary Tools

The plugin registers **278 tools** but only **33 core tools** appear in `tools/list`
by default. The remaining **245 supplementary tools** are disabled until enabled:
open the **MCP** dock panel (View > Bottom Panel > MCP), toggle the tools you need
in the **Tools** list, and the state persists to `user://mcp_tool_state.cfg`.

> Headless note: when editing `mcp_tool_state.cfg` by hand, recompute the
> `[meta] checksum` (MD5 over `tools/<key>=<value>` lines joined by `\n`) or the
> changes are ignored. Close the editor first �?it rewrites the file on exit.

Runtime tools require the `MCPRuntimeProbe` autoload; the plugin adds it to
`project.godot` automatically when enabled.

### Configuring MCP Server
The plugin provides two transport modes:

#### HTTP Mode (for remote access)
- Best for: Network-based AI integration
- Configuration: Set `transport_mode = "http"` and configure `http_port` (default: 9080)
- Optional: Enable `auth_enabled` and set `auth_token` for security

### Connecting with Claude Desktop

First, install the `mcp-remote` package:
```bash
npm install mcp-remote
```

#### HTTP Mode Configuration
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

### Connecting with Cursor / Trae

#### HTTP Mode Configuration
```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

With authentication:
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

### Connecting with Cline

#### HTTP Mode Configuration

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

### Connecting with OpenCode

#### HTTP Mode Configuration

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

### Connecting with Codex

#### HTTP Mode Configuration

```toml
[mcp_servers]

[mcp_servers.godot-mcp]
type = "streamableHttp"
url = "http://localhost:9080/mcp"
```

## 💬 Example Prompts

Once connected, you can interact with your Godot project through Claude:

```
@mcp godot-mcp read godot://script/current

I need help optimizing my player movement code. Can you suggest improvements?
```

```
@mcp godot-mcp get-scene-tree

Add a cube in the middle of the scene and create a camera that looks at it.
```

```
Create a main menu with Play, Options, and Quit buttons
```

```
Implement a day/night cycle system with dynamic lighting
```

## 📚 Available Commands

**278 tools** �?33 core + 245 supplementary.

### Node-Write (6 core)
- `create-node` - Create a new node in the Godot scene tree. Returns the node path and type.
- `delete-node` - Delete a node from the Godot scene tree. This operation is destructive and cannot be undone.
- `update-node-property` - Update a property of a specific node. Supports common property types with automatic type conversion.
- `duplicate-node` - Duplicate a node and its children in the scene tree. Returns the new node path.
- `move-node` - Move a node to a new parent in the scene tree. Optionally preserves global transform.
- `rename-node` - Rename a node in the scene tree. The new name must be unique among siblings.

### Node-Read (3 core)
- `get-node-properties` - Get all properties of a specific node in the scene tree.
- `list-nodes` - List all nodes in the current scene or under a specific parent node.
- `get-scene-tree` - Get the complete scene tree hierarchy starting from the scene root. Returns full tree structure with

### Node-Write-Advanced (5 supplementary)
- `add-resource` - Add a resource child node to a target node.
- `set-anchor-preset` - Set anchor preset for a Control node.
- `connect-signal` - Connect a signal from one node to another.
- `disconnect-signal` - Disconnect a signal from one node to another.
- `set-node-groups` - Set groups for a node.

### Node-Advanced (12 supplementary)
- `get-node-groups` - Get groups that a node belongs to.
- `find-nodes-in-group` - Find all nodes in a specific group.
- `batch-update-node-properties` - Update multiple node properties inside one editor UndoRedo action. Useful for transaction-style scen
- `batch-scene-node-edits` - Apply multiple create/delete scene node edits inside one editor UndoRedo action so the full structur
- `audit-scene-node-persistence` - Audit node owner and persistence state for the currently edited scene. Reports missing or invalid ow
- `audit-scene-inheritance` - Audit inherited or instanced scene structure for the current scene. Classifies local nodes, instance
- `batch-add-nodes` - Create multiple nodes in one UndoRedo action. Each entry: {type, name, parent_path, properties}.
- `batch-set-property` - Set a property on all nodes of a given type in the current scene (one UndoRedo action).
- `find-nodes-by-type` - Find all nodes of a given class in the current scene.
- `find-signal-connections` - Find all signal connections in the current scene, optionally filtered by signal or node.
- `find-node-references` - Search all .tscn/.gd/.tres/.gdshader files for references to a pattern.
- `cross-scene-set-property` - Set a property on nodes of a type across multiple scene files. Requires force=true to apply; dry_run

### Script (7 core)
- `list-project-scripts` - List all GDScript files (.gd) in the project. Returns paths relative to res://.
- `read-script` - Read the content of a GDScript file (.gd). Returns the complete script source code.
- `create-script` - Create a new GDScript file with optional template. GDScript files are complete programs, not resourc
- `modify-script` - Modify the content of an existing GDScript file. Can replace entire content or specific lines.
- `get-current-script` - Get the currently edited script in the Godot editor.
- `attach-script` - Attach a script to a node.
- `execute-script` - Execute a script in the editor context.

### Script-Advanced (8 supplementary)
- `analyze-script` - Analyze a GDScript file and report code quality issues.
- `validate-script` - Validate a script file for syntax errors.
- `search-in-files` - Search for text in project files.
- `list-project-script-symbols` - Index script symbols across project GDScript and C# files. Returns class, extends, functions, signal
- `find-script-symbol-definition` - Find definition locations for a script symbol across GDScript and C# project files.
- `find-script-symbol-references` - Find textual project references to a script symbol across GDScript, C#, and scene files.
- `rename-script-symbol` - Rename a script symbol across project files using identifier-boundary text replacements. Supports dr
- `open-script-at-line` - Open a script file at a specific line number in the Godot editor.

### Scene (4 core)
- `create-scene` - Create a new Godot scene with a root node. The scene is saved to the specified path.
- `save-scene` - Save the current scene to disk. If no path is provided, saves to the current scene's path.
- `open-scene` - Open a scene file from the project. Closes the current scene if one is open.
- `get-current-scene` - Get information about the currently open scene, including name, path, and root node type.

### Scene-Advanced (10 supplementary)
- `get-scene-structure` - Get the complete structure of the current scene as a tree. Returns node types, names, and hierarchy.
- `list-project-scenes` - List all scene files (.tscn) in the project. Returns paths relative to res://.
- `list-open-scenes` - List scene tabs currently open in the Godot editor.
- `close-scene-tab` - Close the active scene tab, or activate a specified scene tab and close it.
- `delete-scene` - Delete a scene file (.tscn) and its .import sidecar from the project.
- `add-scene-instance` - Instantiate a scene (.tscn) as a child of a node.
- `play-scene` - Play the main scene, current scene, or a specific scene path.
- `stop-scene` - Stop the running game scene.
- `get-scene-file-content` - Read a scene file's raw text content.
- `get-scene-exports` - List all @export properties of every scripted node in a scene file.

### Editor (4 core)
- `get-editor-state` - Get the current state of the Godot editor, including active scene and selection info.
- `run-project` - Run the current project or a specific scene. Launches the game in play mode.
- `stop-project` - Stop the currently running project and return to editor mode.
- `execute-editor-script` - Execute a script in the editor with access to editor APIs.

### Editor-Advanced (26 supplementary)
- `get-selected-nodes` - Get the list of currently selected nodes in the editor.
- `set-editor-setting` - Set an editor setting value. Requires editor restart for some settings to take effect.
- `get-editor-screenshot` - Capture a screenshot of the editor viewport and save it to a file.
- `get-signals` - Get all signals and their connections for a node.
- `reload-project` - Rescan the project filesystem and reload scripts. Useful after external file changes.
- `select-node` - Select a node in the current edited scene and focus it in the Inspector.
- `select-file` - Select a project file in the Godot FileSystem dock.
- `get-inspector-properties` - Inspect a node or resource and return property metadata and serialized values similar to the Inspect
- `list-export-presets` - List export presets from export_presets.cfg.
- `inspect-export-templates` - Inspect locally installed Godot export templates for the current editor version.
- `validate-export-preset` - Validate an export preset against export_presets.cfg and local template availability.
- `run-export` - Run a Godot CLI export for a configured preset.
- `get-editor-errors` - Collect editor errors and warnings from the Output panel, script editor analyzer panels, debugger Er
- `get-output-log` - Read the editor Output panel or log file, optionally filtered.
- `set-auto-dismiss` - Enable or disable auto-dismissal of blocking editor dialogs.
- `get-editor-camera` - Read the 3D editor viewport camera position, rotation, FOV, and clip planes.
- `set-editor-camera` - Move or rotate the 3D editor viewport camera, optionally look at a target, and set FOV.
- `get-editor-selection` - Read the current editor selection (top-level or all selected nodes).
- `select-nodes` - Select one or more nodes in the scene tree. Modes: replace, add, remove. Optionally focus/inspect a 
- `clear-editor-selection` - Clear the current editor node selection.
- `reload-plugin` - Reload the Godot MCP plugin by disabling and re-enabling it. The MCP connection will briefly drop an
- `export-project` - Generate the Godot CLI export command for a preset (debug or release). Direct export from the editor
- `get-export-info` - Read export configuration: export presets presence, Godot executable path, and templates installatio
- `list-android-devices` - List Android devices visible to adb (from Editor Settings or PATH).
- `get-android-preset-info` - Read an Android export preset's configuration from export_presets.cfg.
- `deploy-to-android` - Export an Android preset and install the APK on a connected device via adb.

### Debug (3 core)
- `get-editor-logs` - Get recent log messages from the editor or runtime. Supports filtering by source, type, and paginati
- `debug-print` - Print debug messages to the editor console.
- `clear-output` - Clear the editor output panel.

### Debug-Advanced (82 supplementary)
- `get-performance-metrics` - Get performance metrics from the editor or running game.
- `get-debugger-sessions` - List Godot editor debugger sessions and their active/break state.
- `set-debugger-breakpoint` - Enable or disable a breakpoint in active Godot debugger sessions.
- `send-debugger-message` - Send a custom debugger message to active Godot debugger sessions.
- `toggle-debugger-profiler` - Toggle an EngineProfiler in active Godot debugger sessions.
- `get-debugger-messages` - Read custom messages captured by the Godot debugger bridge.
- `add-debugger-capture-prefix` - Allow the debugger bridge to capture custom EngineDebugger messages with the given prefix.
- `get-debug-stack-frames` - Return the latest captured script stack frames and request a fresh stack dump from breaked sessions.
- `get-debug-stack-variables` - Return latest captured local/member/global variables for a stack frame and request a fresh variable 
- `install-runtime-probe` - Install a runtime probe for debugging.
- `remove-runtime-probe` - Remove a runtime probe.
- `request-debug-break` - Request the debugger to break at the current execution point.
- `send-debug-command` - Send a command to the debugger.
- `get-runtime-info` - Get runtime information about the running game.
- `await-scene-ready` - Poll the runtime until the specified scene is loaded and ready.
- `get-runtime-scene-tree` - Get the scene tree from the running game.
- `inspect-runtime-node` - Inspect a node in the running game.
- `update-runtime-node-property` - Update a node property in the running game.
- `call-runtime-node-method` - Call a method on a node in the running game.
- `evaluate-runtime-expression` - Evaluate an expression in the running game context.
- `await-runtime-condition` - Wait for a condition to be true in the running game.
- `assert-runtime-condition` - Assert a condition in the running game.
- `get-debug-threads` - Return DAP-style debugger threads visible from the active Godot debug session.
- `get-debug-state-events` - Read recorded debugger break/resume/stop state transitions from the bridge.
- `get-debug-output` - Read categorized runtime debugger output captured by the editor bridge.
- `get-debug-scopes` - Group latest captured stack variables into DAP-like scopes for a frame.
- `get-debug-variables` - Resolve a DAP-style variablesReference into child variables, with optional pagination for large arra
- `expand-debug-variable` - Expand a captured debug variable or evaluated expression value by scope and path, with pagination fo
- `evaluate-debug-expression` - Evaluate an expression in the paused script debugger context for a given frame.
- `debug-step-into` - Step into the next function call in the debugger.
- `debug-step-over` - Step over the next line in the debugger.
- `debug-step-out` - Step out of the current function in the debugger.
- `debug-continue` - Continue execution in the debugger.
- `debug-step-into-and-wait` - Step into and wait for the debugger to pause.
- `debug-step-over-and-wait` - Step over and wait for the debugger to pause.
- `debug-step-out-and-wait` - Step out and wait for the debugger to pause.
- `debug-continue-and-wait` - Continue and wait for the debugger to pause or complete.
- `await-debugger-state` - Wait for a specific debugger state.
- `get-runtime-performance-snapshot` - Get a performance snapshot from the running game.
- `get-runtime-memory-trend` - Get memory usage trends from the running game.
- `create-runtime-node` - Create a node in the running game.
- `delete-runtime-node` - Delete a node in the running game.
- `simulate-runtime-input-event` - Simulate an input event in the running game.
- `simulate-runtime-input-action` - Simulate an input action in the running game.
- `list-runtime-input-actions` - List input actions available in the running game.
- `upsert-runtime-input-action` - Create or update an input action in the running game.
- `remove-runtime-input-action` - Remove an input action from the running game.
- `list-runtime-animations` - List animations available in the running game.
- `play-runtime-animation` - Play an animation in the running game.
- `stop-runtime-animation` - Stop an animation in the running game.
- `get-runtime-animation-state` - Get the state of an animation in the running game.
- `get-runtime-animation-tree-state` - Get the state of an animation tree in the running game.
- `set-runtime-animation-tree-active` - Set an animation tree active/inactive in the running game.
- `travel-runtime-animation-tree` - Travel to a new state in an animation tree in the running game.
- `get-runtime-material-state` - Get the state of a material in the running game.
- `get-runtime-theme-item` - Get a theme item in the running game.
- `set-runtime-theme-override` - Set a theme override in the running game.
- `clear-runtime-theme-override` - Clear a theme override in the running game.
- `get-runtime-shader-parameters` - Get shader parameters in the running game.
- `set-runtime-shader-parameter` - Set a shader parameter in the running game.
- `list-runtime-tilemap-layers` - List TileMap layers in the running game.
- `get-runtime-tilemap-cell` - Get a TileMap cell in the running game.
- `set-runtime-tilemap-cell` - Set a TileMap cell in the running game.
- `list-runtime-audio-buses` - List audio buses in the running game.
- `get-runtime-audio-bus` - Get an audio bus in the running game.
- `update-runtime-audio-bus` - Update an audio bus in the running game.
- `get-runtime-screenshot` - Take a screenshot of the running game.
- `run-test-scenario` - Execute a test scenario: optionally play a scene, run steps (input, wait, assert, screenshot), retur
- `assert-node-state` - Assert a runtime node property against an expected value with an operator (eq, neq, gt, lt, gte, lte
- `assert-screen-text` - Assert that a text string appears in a runtime UI element (requires visible Control nodes with text)
- `run-stress-test` - Send random inputs to the running game for N seconds and check for crashes.
- `get-test-report` - Collect and format results from accumulated assertions into a test report.
- `start-recording` - Start recording input events (keyboard, mouse, actions) in the running game.
- `stop-recording` - Stop recording input events and return the captured event sequence.
- `replay-recording` - Replay a recorded input event sequence in the running game at a given speed.
- `find-ui-elements` - List visible UI elements (Button, Label, LineEdit, TextEdit, OptionButton, CheckBox) in the running 
- `click-button-by-text` - Click a visible Button in the running game by its text.
- `wait-for-node` - Check whether a node exists in the running game scene tree.
- `find-nearby-nodes` - Find nodes within a radius of a position in the running game (2D/3D).
- `navigate-to` - Compute navigation suggestions (keys, camera rotation, duration) to move a 3D player toward a target
- `move-to` - Move a 3D player toward a target in the running game by injecting movement keys. Returns after arriv
- `watch-signals` - Watch for signal emissions on runtime nodes for a duration. Requires runtime scene inspection via pr

### Project (3 core)
- `get-project-info` - Get general information about the Godot project, including name, version, and description.
- `get-project-settings` - Get project settings. Optionally filter by a prefix.
- `list-project-resources` - List all resource files in the project (.tres, .res, .png, .ogg, etc.).

### Project-Advanced (41 supplementary)
- `create-resource` - Create a new Godot resource file (.tres). Supports common resource types.
- `get-project-structure` - Get project structure and file organization.
- `list-project-tests` - Discover runnable project tests under the Godot project's test directories. Reports Python integrati
- `run-project-test` - Run a single project test script. Python integration tests are executed with python. GUT unit tests 
- `run-project-tests` - Discover and run multiple project tests from a directory. Reuses the same framework filters as list_
- `list-project-input-actions` - List project InputMap actions stored in ProjectSettings, including serialized input events.
- `upsert-project-input-action` - Create or update a project InputMap action in ProjectSettings and save project.godot.
- `remove-project-input-action` - Remove a project InputMap action from ProjectSettings and save project.godot.
- `list-project-autoloads` - List project autoload entries with resolved path, singleton flag, and project setting order.
- `list-project-global-classes` - List project global script classes registered through class_name metadata.
- `get-class-api-metadata` - Get typed API metadata for an engine ClassDB class or a project global script class.
- `inspect-csharp-project-support` - Inspect C# / Mono project support files such as .csproj and .sln, including target frameworks, assem
- `compare-render-screenshots` - Compare two screenshot images and report pixel differences, RMSE, and threshold-based match status.
- `inspect-tileset-resource` - Inspect a TileSet resource and summarize its sources, atlas tiles, and scene tiles.
- `reimport-resources` - Reimport project resources.
- `get-import-metadata` - Get resource import metadata.
- `get-resource-uid-info` - Get resource UID information.
- `fix-resource-uid` - Fix resource UID issues.
- `get-resource-dependencies` - Get resource dependencies.
- `scan-missing-resource-dependencies` - Scan for missing resource dependencies.
- `scan-cyclic-resource-dependencies` - Scan for cyclic resource dependencies.
- `detect-broken-scripts` - Detect broken scripts in the project.
- `audit-project-health` - Audit project health and integrity.
- `get-filesystem-tree` - Return the project filesystem tree, optionally filtered by glob and depth-limited.
- `search-files` - Search for files by name (fuzzy or glob) under a path.
- `set-project-setting` - Set a ProjectSettings value and save project.godot. Strings are type-inferred.
- `uid-to-project-path` - Convert a resource UID string to its project path.
- `project-path-to-uid` - Convert a project path to its resource UID string.
- `add-autoload` - Add an autoload singleton to ProjectSettings.
- `remove-autoload` - Remove an autoload singleton from ProjectSettings.
- `get-project-statistics` - Collect project statistics: script, scene, resource, and image file counts by extension.
- `get-autoload` - Read a project autoload singleton's properties and script path.
- `read-resource` - Read a resource file (.tres/.res) and return its editor-visible properties.
- `edit-resource` - Modify properties of a resource file and save it.
- `get-resource-preview` - Generate a PNG preview (base64) of a resource: images, textures, or any resource with a visual repre
- `get-input-actions` - List project InputMap actions with their bound input events and deadzones.
- `set-input-action` - Create or update an InputMap action with bound events, saving to ProjectSettings and updating the ru
- `analyze-signal-flow` - Analyze signal connections in the current scene: sources, targets, and connection count.
- `analyze-scene-complexity` - Analyze a scene's complexity: node count, depth, node types, scripts, and potential issues.
- `detect-circular-dependencies` - Detect circular scene dependencies (.tscn files referencing each other) using DFS cycle detection.
- `find-unused-resources` - Scan the project for resource files not referenced by any scene, script, or resource file.

### World (22 supplementary)
- `add-mesh-instance` - Create a MeshInstance3D with a primitive mesh (box, sphere, cylinder, capsule, plane, quad, prism, t
- `setup-lighting` - Add a DirectionalLight3D, OmniLight3D, or SpotLight3D with color, energy, and shadow settings.
- `set-material-3d` - Create or update a StandardMaterial3D on a MeshInstance3D surface with PBR parameters (albedo, metal
- `setup-environment` - Create or update a WorldEnvironment with background mode, procedural sky, ambient light, and tonemap
- `setup-camera-3d` - Create or configure a Camera3D with position, rotation, FOV, near/far planes, and current camera fla
- `add-gridmap` - Create a GridMap node, optionally assign a MeshLibrary resource and set cell size.
- `setup-collision` - Add a CollisionShape2D or CollisionShape3D to a physics body or area node. Supports rectangle, circl
- `set-physics-layers` - Set collision_layer and/or collision_mask on a physics node. Accepts an integer bitmask or an array 
- `get-physics-layers` - Read collision_layer and collision_mask from a physics node, including resolved layer names.
- `add-raycast` - Add a RayCast2D or RayCast3D to a node with configurable target position, collision mask, and hit se
- `setup-physics-body` - Configure physics body properties. CharacterBody: motion_mode, floor settings, max_slides, slide_on_
- `get-collision-info` - Read collision shapes, raycasts, layers, and body settings from a physics node (including children).
- `setup-navigation-region` - Create a NavigationRegion2D or NavigationRegion3D with configurable agent and cell properties.
- `bake-navigation-mesh` - Bake a NavigationRegion3D navigation mesh or build a NavigationRegion2D polygon from an outline or s
- `setup-navigation-agent` - Create a NavigationAgent2D or NavigationAgent3D with pathfinding and avoidance settings.
- `set-navigation-layers` - Set navigation_layers on a navigation region or agent. Accepts a bitmask, an array of layer numbers,
- `get-navigation-info` - List navigation regions and agents under a node, including their properties and named layers.
- `create-particles` - Create a GPUParticles2D or GPUParticles3D node with amount, lifetime, one_shot, explosiveness, and r
- `set-particle-material` - Configure the ParticleProcessMaterial of a GPUParticles node: direction, spread, velocity, gravity, 
- `set-particle-color-gradient` - Set a color gradient on a GPUParticles node's material from an array of {offset, color} stops.
- `apply-particle-preset` - Apply a predefined particle preset: explosion, fire, smoke, sparks, rain, snow, magic, or dust.
- `get-particle-info` - Read GPUParticles node state: amount, lifetime, one_shot, explosiveness, randomness, emitting, and m

### Media-Animation (14 supplementary)
- `list-animations` - List all animations on an AnimationPlayer node with length, loop mode, and track count.
- `create-animation` - Create a new animation on an AnimationPlayer node with length and loop mode.
- `add-animation-track` - Add a track to an animation. Track types: value, position_2d, rotation_2d, scale_2d, method, bezier,
- `set-animation-keyframe` - Insert or update a keyframe at a given time on an animation track.
- `get-animation-info` - Read animation details: length, loop mode, step, and per-track keyframes.
- `remove-animation` - Remove an animation from an AnimationPlayer node (undoable).
- `create-animation-tree` - Create an AnimationTree node with an AnimationNodeStateMachine root, optionally linked to an Animati
- `get-animation-tree-structure` - Read an AnimationTree structure: root node type, state machine states/transitions, or blend tree nod
- `add-state-machine-state` - Add a state to an AnimationNodeStateMachine. State types: animation, blend_tree, or state_machine.
- `remove-state-machine-state` - Remove a state from an AnimationNodeStateMachine (undoable).
- `add-state-machine-transition` - Add a transition between two states in an AnimationNodeStateMachine.
- `remove-state-machine-transition` - Remove a transition between two states in an AnimationNodeStateMachine (undoable).
- `set-blend-tree-node` - Add or replace a node inside an AnimationNodeBlendTree. Types: Animation, Add2, Blend2, Add3, Blend3
- `set-tree-parameter` - Set an AnimationTree parameter (auto-prefixed with 'parameters/').

### Media-Audio (6 supplementary)
- `get-audio-bus-layout` - Read the full AudioServer bus layout: names, volume, solo/mute, send, and per-bus effects with param
- `add-audio-bus` - Add a new audio bus to the AudioServer with volume, send, solo, and mute settings.
- `set-audio-bus` - Update audio bus properties: volume_db, solo, mute, bypass_effects, send, or rename.
- `add-audio-bus-effect` - Add an audio effect to a bus. Types: reverb, chorus, delay, compressor, limiter, phaser, distortion,
- `add-audio-player` - Add an AudioStreamPlayer, AudioStreamPlayer2D, or AudioStreamPlayer3D with stream, volume, bus, and 
- `get-audio-info` - List audio players under a node with stream, volume, bus, autoplay, and spatial properties.

### Media-Theme (7 supplementary)
- `create-theme` - Create a new Theme resource (.tres) with an optional default font size.
- `set-theme-color` - Set a theme color override on a Control node (undoable).
- `set-theme-constant` - Set a theme constant override on a Control node (undoable).
- `set-theme-font-size` - Set a theme font size override on a Control node (undoable).
- `set-theme-stylebox` - Set a StyleBoxFlat theme override on a Control node with background, border, corner radius, and padd
- `setup-control` - Configure a Control node layout: anchor preset, min size, size flags, margins, separation, and grow 
- `get-theme-info` - Read a Control node's theme path, type list, and all theme overrides (colors, constants, font sizes,

### Media-Shader (6 supplementary)
- `create-shader` - Create a shader file (.gdshader) with a template for spatial, canvas_item, particles, or sky, or wit
- `read-shader` - Read a shader file's content.
- `edit-shader` - Edit a shader file with full content replacement or search-and-replace.
- `assign-shader-material` - Create a ShaderMaterial from a shader file and assign it to a CanvasItem or MeshInstance3D node.
- `set-shader-param` - Set a shader uniform on a node's ShaderMaterial. Values are auto-parsed from strings.
- `get-shader-params` - Read all shader uniforms from a node's ShaderMaterial.

### Media-TileMap (6 supplementary)
- `tilemap-set-cell` - Set a cell on a TileMapLayer or legacy TileMap node (undoable).
- `tilemap-fill-rect` - Fill a rectangular region of a TileMapLayer or legacy TileMap with a tile (undoable).
- `tilemap-get-cell` - Read a cell from a TileMapLayer or legacy TileMap.
- `tilemap-clear` - Clear a TileMapLayer or legacy TileMap (optionally one layer), undoable.
- `tilemap-get-info` - Read TileMapLayer/TileMap info: layers, used cells, TileSet sources, and tile size.
- `tilemap-get-used-cells` - List used cells of a TileMapLayer or legacy TileMap layer with their source ids.

### Bootstrap (3 core)
- `godot-status` - Report the MCP server readiness: transport, port, auth, tool counts, and runtime probe state. Call t
- `godot-ensure-ready` - Ensure the MCP server is ready: repair the runtime probe autoload if missing and report server state
- `get-server-info` - Read MCP server infrastructure info: plugin version, transport, port, auth, tool registry counts, an

## 🔒 Security Recommendations

- �?**Production**: Always enable authentication (`auth_enabled = true`)
- �?**Token**: Use a strong token (�?6 characters with letters, numbers, special characters)
- �?**Storage**: Don't commit tokens to version control
- ⚠️ **Remote Access**: Use HTTPS (TLS/SSL) for network access

## 📋 Requirements

- Godot Engine 4.x (recommended 4.5 or higher)
- No additional dependencies (native implementation)

## 📖 Documentation

For detailed documentation, see the `docs/current/` folder:
- [Quick Start Guide](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/quickstart.md)
- [Architecture Design](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/architecture.md)
- [Tools Reference](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/tools-reference.md)
- [Testing Guide](https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/testing-guide.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/yurineko73/Godot-MCP-Native/blob/main/LICENSE) file for details.

## 👤 Author

**yurineko73**

## 🙏 Acknowledgments

- Godot Engine team for the amazing game engine
- Model Context Protocol (MCP) specification
- Claude AI by Anthropic for inspiring this integration

---

**Note**: This is a community plugin and is not officially affiliated with Godot Engine or Anthropic.
