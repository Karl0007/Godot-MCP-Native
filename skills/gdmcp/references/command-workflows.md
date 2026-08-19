# gdmcp Command Workflows

## From zero to running (first-time onboarding)

```powershell
# 1. Install the plugin into the target project (copies addons/, writes
#    [editor_plugins], records port). Requires this repo's scripts dir.
.\scripts\gdmcp-bootstrap.ps1 install -ProjectPath C:\MyGame -Port 9080

# 2. Launch the editor with the MCP server (auto-detects Godot exe;
#    pass -GodotExe if not found by doctor).
.\scripts\gdmcp-bootstrap.ps1 start -ProjectPath C:\MyGame -Port 9080

# 3. Verify: doctor should report plugin version + listening port.
.\scripts\gdmcp-bootstrap.ps1 doctor -ProjectPath C:\MyGame -Port 9080

# 4. From inside the project dir, gdmcp auto-discovers the port:
gdmcp --json doctor
gdmcp --json editor state
```

If `gdmcp` is not installed, see SKILL.md "Installation" (build with
`cli/gdmcp/scripts/install-dev.ps1`, needs MSVC C++ workload on Windows) or
fall back to curl on the `/cli/v1` endpoints.

## Diagnose editor state

```bash
gdmcp --json doctor
gdmcp --json editor state
gdmcp --json scenes current
gdmcp --json debug logs --level Error --limit 50
```

## Resolve names to paths

```bash
gdmcp --json nodes resolve Player
gdmcp --json scenes resolve Main
gdmcp --json scripts resolve player
gdmcp --json resources resolve icon
```

## Inspect a scene

```bash
gdmcp --json scenes tree --depth 4
gdmcp --json nodes get /root/Main/Player --fields position,visible
```

## Inspect a script

```bash
gdmcp --json scripts list --limit 50
gdmcp --json scripts read res://scripts/player.gd --lines 1:200
```

## Create a script

```bash
gdmcp --json scripts create res://scripts/enemy.gd --script-type GDScript
```

## Inspect a resource

```bash
gdmcp --json resources get res://player.tres
gdmcp --json resources get res://player.tres --fields resource_path,resource_name
```

## Modify a node property

```bash
gdmcp --json nodes properties set /root/Main/Player --property speed --value 300
```

## Move or rename a node

```bash
gdmcp --json nodes move /root/Main/Enemy --new-parent /root/World
gdmcp --json nodes rename /root/Main/Enemy --new-name Boss
```

## Replace a script explicitly

```bash
gdmcp --json scripts replace res://scripts/player.gd \
  --content-file ./player.gd \
  --apply
```

## Inspect a running game

```bash
gdmcp --json runtime info
gdmcp --json runtime tree --depth 4
gdmcp --json runtime nodes get /root/Main/Player
```

## Inspect logs progressively

```bash
gdmcp --json debug logs --limit 50
gdmcp --json debug logs --limit 50 --cursor 50
gdmcp --json debug logs --limit 100 --out ./logs.json
```

## Discover an advanced runtime tool

```bash
gdmcp --json tools search "runtime shader parameter" --limit 5
gdmcp --json tools schema set_runtime_shader_parameter
gdmcp --json tool-call set_runtime_shader_parameter \
  --args-file ./shader-request.json \
  --allow-open-world
```

## Preview and apply a batch

```bash
gdmcp --json batch preview ./operations.json
gdmcp --json batch apply ./operations.json --apply
```

Batch operations use registered tool names with JSON object arguments. They are
validated before the first request, then executed sequentially and are not
atomic; a later failure does not roll back earlier operations.