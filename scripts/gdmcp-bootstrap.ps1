<#
.SYNOPSIS
    One-click bootstrap for Godot MCP Native: install the plugin into a
    project, launch the editor with the MCP server, and check status.

.DESCRIPTION
    Provides install / start / doctor subcommands so an agent or user can
    go from a fresh clone to a running MCP server without reading the full
    README. All commands are idempotent and print next-step guidance.

    - install:  copy addons/godot_mcp into the target project, add the
                [editor_plugins] enablement entry (4.7+ format) to
                project.godot, and record the MCP port.
    - start:    locate a Godot executable (auto-detect or -GodotExe) and
                launch the editor with `-- --mcp-server --mcp-port=N`.
    - doctor:   verify Godot, plugin installation, port state, and the
                running editor; print remediation hints for each failure.

.PARAMETER Command
    install | start | doctor

.PARAMETER ProjectPath
    Target Godot project directory (default: current directory).

.PARAMETER Port
    MCP HTTP port (default: 9080). Must be 1024-65535.

.PARAMETER GodotExe
    Path to a Godot executable. If omitted, auto-detection tries:
    1. $env:GODOT4_BIN (conventional env var)
    2. `godot` / `godot4` on PATH
    3. Common install locations (C:\Godot\*, F:\Godot\*, C:\Program Files\Godot*)

.PARAMETER EditorMode
    When starting, launch the full editor window (default $true). Pass
    -EditorMode:$false for headless console mode.

.EXAMPLE
    .\scripts\gdmcp-bootstrap.ps1 install -ProjectPath C:\MyGame
    .\scripts\gdmcp-bootstrap.ps1 start -ProjectPath C:\MyGame -Port 9087
    .\scripts\gdmcp-bootstrap.ps1 doctor -ProjectPath C:\MyGame
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('install', 'start', 'doctor')]
    [string]$Command,

    [string]$ProjectPath = (Get-Location).Path,

    [int]$Port = 9080,

    [string]$GodotExe = '',

    [switch]$EditorMode = $true,

    [switch]$SaveGodotExe
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$AddonSource = Join-Path $RepoRoot 'addons\godot_mcp'

function Write-Step { param([string]$Text) Write-Host ">>> $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "[ok] $Text" -ForegroundColor Green }
function Write-Fail { param([string]$Text) Write-Host "[fail] $Text" -ForegroundColor Red }
function Write-Info { param([string]$Text) Write-Host "[info] $Text" -ForegroundColor Yellow }

function Fail([string]$Message) {
    Write-Fail $Message
    exit 1
}

function Resolve-Project {
    $script:Project = [IO.Path]::GetFullPath($ProjectPath)
    if (-not (Test-Path -LiteralPath (Join-Path $script:Project 'project.godot') -PathType Leaf)) {
        Fail "project.godot is missing: $script:Project (pass -ProjectPath or cd into a Godot project)"
    }
}

function Get-ProjectGodotVersion {
    # Read the major.minor version the project declares in config/features
    # (e.g. PackedStringArray("4.7", "Mobile")). Returns "" when absent.
    $projectFile = Join-Path $script:Project 'project.godot'
    if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) { return '' }
    $content = [IO.File]::ReadAllText($projectFile)
    $m = [regex]::Match($content, 'config/features\s*=\s*PackedStringArray\([^)]*"(4\.[0-9]+)"')
    if ($m.Success) { return $m.Groups[1].Value }
    # Fall back to a lone quoted version in features
    $m2 = [regex]::Match($content, 'PackedStringArray\([^)]*"(4\.[0-9]+)"')
    if ($m2.Success) { return $m2.Groups[1].Value }
    return ''
}

function Get-GodotConfigPath {
    return Join-Path $env:USERPROFILE '.godot-mcp-bootstrap.json'
}

function Read-GodotConfig {
    $cfgPath = Get-GodotConfigPath
    if (Test-Path -LiteralPath $cfgPath -PathType Leaf) {
        try { return (Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json) } catch { }
    }
    return $null
}

function Write-GodotConfig([string]$ExePath) {
    $cfgPath = Get-GodotConfigPath
    $existing = Read-GodotConfig
    $cfg = [ordered]@{ godot_exe = $ExePath }
    if ($existing -and $existing.PSObject.Properties['godot_versions']) {
        $cfg.godot_versions = $existing.godot_versions
    }
    [IO.File]::WriteAllText($cfgPath, ($cfg | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "saved Godot path to $cfgPath"
}

function Find-GodotExecutable {
    # Resolution order:
    # 1. Explicit -GodotExe
    # 2. Persistent config (~/.godot-mcp-bootstrap.json)
    # 3. GODOT4_BIN env var
    # 4. PATH (godot / godot4)
    # 5. Directory scan; prefer the version the project declares
    #    (config/features "4.x"), otherwise the first match.
    if ($GodotExe) {
        if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { Fail "Godot executable not found: $GodotExe" }
        return [IO.Path]::GetFullPath($GodotExe)
    }
    $cfg = Read-GodotConfig
    if ($cfg -and $cfg.PSObject.Properties['godot_exe'] -and (Test-Path -LiteralPath $cfg.godot_exe -PathType Leaf)) {
        return [IO.Path]::GetFullPath($cfg.godot_exe)
    }
    $envBin = $env:GODOT4_BIN
    if ($envBin -and (Test-Path -LiteralPath $envBin -PathType Leaf)) { return $envBin }
    foreach ($candidate in @(
        (Get-Command 'godot' -ErrorAction SilentlyContinue),
        (Get-Command 'godot4' -ErrorAction SilentlyContinue)
    )) {
        if ($candidate) { return $candidate.Source }
    }
    $projectVersion = Get-ProjectGodotVersion
    $roots = @('C:\Godot', 'F:\Godot', 'D:\Godot', 'C:\Program Files', "$env:LOCALAPPDATA\Programs")
    $all = @()
    foreach ($root in $roots) {
        $all += @(Get-ChildItem -LiteralPath $root -Filter 'Godot*.exe' -File -Recurse -Depth 3 -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'console' })
    }
    if ($all.Count -eq 0) { return '' }
    if ($projectVersion) {
        # Prefer an executable whose name embeds the declared version (e.g. 4.7)
        $majorMinor = $projectVersion.Split('.') | Select-Object -First 2
        $verTag = ($majorMinor -join '.')
        $versionMatch = @($all | Where-Object { $_.Name -match [regex]::Escape($verTag) })
        if ($versionMatch.Count -gt 0) { return $versionMatch[0].FullName }
    }
    return $all[0].FullName
}

function Get-PluginEntry {
    # Godot 4.7+ uses [editor_plugins] enabled=PackedStringArray(...);
    # older 4.x uses [editor] plugins/uid://...=true. Prefer 4.7 format
    # (the project file is read by the same or newer editor).
    return "[editor_plugins]`n`nenabled=PackedStringArray(`"res://addons/godot_mcp/plugin.cfg`")"
}

function Install-Plugin {
    Resolve-Project
    if (-not (Test-Path -LiteralPath $AddonSource -PathType Container)) {
        Fail "addon source is missing: $AddonSource (run this script from the repo root)"
    }
    $targetAddon = Join-Path $script:Project 'addons\godot_mcp'
    New-Item -ItemType Directory -Path (Split-Path -Parent $targetAddon) -Force | Out-Null
    if (Test-Path -LiteralPath $targetAddon -PathType Container) {
        Write-Info "addon already present: $targetAddon (overwriting)"
        Remove-Item -LiteralPath $targetAddon -Recurse -Force
    }
    Copy-Item -LiteralPath $AddonSource -Destination $targetAddon -Recurse -Force
    Write-Ok "copied addon to $targetAddon"

    # Ensure [editor_plugins] entry. Handle three cases:
    # 1. No [editor_plugins] section at all            -> append fresh block
    # 2. Section exists but lacks a valid enabled= line -> replace the section
    # 3. Section already lists the plugin              -> no-op
    $projectFile = Join-Path $script:Project 'project.godot'
    $content = [IO.File]::ReadAllText($projectFile)
    $entry = "res://addons/godot_mcp/plugin.cfg"
    $hasSection = $content -match '(?m)^\[editor_plugins\]\s*$'
    $hasValidEntry = $content -match '(?m)^enabled\s*=\s*PackedStringArray\([^)]*' + [regex]::Escape($entry)
    if (-not $hasSection) {
        $content = $content.TrimEnd() + "`n`n" + (Get-PluginEntry) + "`n"
        [IO.File]::WriteAllText($projectFile, $content, (New-Object System.Text.UTF8Encoding($false)))
        Write-Ok "added [editor_plugins] enablement to project.godot"
    } elseif (-not $hasValidEntry) {
        # Replace the whole section body (keep any other sections intact)
        $content = [regex]::Replace($content, '(?ms)^\[editor_plugins\].*?(?=^\[|\z)', (Get-PluginEntry) + "`n")
        [IO.File]::WriteAllText($projectFile, $content, (New-Object System.Text.UTF8Encoding($false)))
        Write-Ok "repaired [editor_plugins] section in project.godot"
    } else {
        Write-Ok "plugin already enabled in project.godot"
    }

    # Persist port for later commands
    $stateDir = Join-Path $script:Project '.godot-mcp'
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    if ($SaveGodotExe -and $GodotExe) {
        Write-GodotConfig $GodotExe
    }
    $state = [ordered]@{
        port = $Port
        project_path = $script:Project
    }
    [IO.File]::WriteAllText((Join-Path $stateDir 'bootstrap.json'), ($state | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "recorded state to $stateDir\bootstrap.json (port $Port)"
}

function Start-Server {
    Resolve-Project
    $exe = Find-GodotExecutable
    if (-not $exe) { Fail 'No Godot executable found. Pass -GodotExe or set GODOT4_BIN.' }
    Write-Ok "using Godot: $exe"
    $projectVersion = Get-ProjectGodotVersion
    if ($projectVersion -and $exe -notmatch [regex]::Escape($projectVersion)) {
        Write-Info "note: project declares Godot $projectVersion but launching $([IO.Path]::GetFileName($exe))"
    }

    # Port: CLI arg wins, else bootstrap.json, else default
    $stateFile = Join-Path $script:Project '.godot-mcp\bootstrap.json'
    $effectivePort = $Port
    if (Test-Path -LiteralPath $stateFile -PathType Leaf) {
        $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        $effectivePort = $Port  # explicit param always wins
    }
    if ($effectivePort -lt 1024 -or $effectivePort -gt 65535) { Fail "port must be 1024-65535 (got $effectivePort)" }

    $argsList = @('--path', $script:Project, '--editor')
    if (-not $EditorMode) { $argsList += '--headless' }
    $argsList += @('--', '--mcp-server', "--mcp-port=$effectivePort")

    Write-Info "launching: $exe $($argsList -join ' ')"
    $proc = Start-Process -FilePath $exe -ArgumentList $argsList -WorkingDirectory $script:Project -PassThru
    Write-Ok "editor launched (pid $($proc.Id)) with MCP server on port $effectivePort"

    # Poll up to 20s for the port; do not block the script if it never opens
    $deadline = (Get-Date).AddSeconds(20)
    $probe = $false
    while ((Get-Date) -lt $deadline) {
        if (Test-PortOccupied $effectivePort) { $probe = $true; break }
        Start-Sleep -Seconds 2
    }
    if ($probe) {
        Write-Ok "port $effectivePort is listening (MCP server up)"
        Write-Info "next: curl -X POST http://127.0.0.1:$effectivePort/mcp -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}'"
        Write-Info "      gdmcp --json doctor  (with gdmcp CLI installed)"
    } else {
        Write-Info "port $effectivePort not listening yet (first launch imports the project; re-run doctor in ~30s)"
    }
}

function Test-PortOccupied([int]$CheckPort) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync('127.0.0.1', $CheckPort)
        if ($task.Wait(1500) -and $client.Connected) { return $true }
        return $false
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Test-EditorProcess {
    # Any Godot process running with --editor and our port in its command line
    $procs = Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.CommandLine -match "mcp-port=$($script:CheckPort)\b") { return $true }
    }
    return $false
}

function Run-Doctor {
    $failures = 0

    Write-Step 'Checking environment'
    $exe = Find-GodotExecutable
    if ($exe) {
        Write-Ok "Godot executable: $exe"
        $ver = & $exe --version 2>$null
        if ($ver) { Write-Info "version: $($ver -join ' ')" }
        $projectVersion = Get-ProjectGodotVersion
        if ($projectVersion) {
            if ($exe -match [regex]::Escape($projectVersion)) {
                Write-Ok "project declares Godot $projectVersion - matches"
            } else {
                Write-Info "MISMATCH: project declares Godot $projectVersion but executable is $([IO.Path]::GetFileName($exe))"
            }
        }
        $cfgPath = Get-GodotConfigPath
        if (Test-Path -LiteralPath $cfgPath -PathType Leaf) { Write-Info "configured path: $cfgPath" }
        else { Write-Info "no persistent Godot path configured (run install -SaveGodotExe -GodotExe <path>)" }
    } else {
        Write-Fail 'No Godot executable found (set -GodotExe, GODOT4_BIN, or PATH)'
        $failures++
    }

    Write-Step 'Checking plugin installation'
    if (-not (Test-Path -LiteralPath (Join-Path $script:Project 'project.godot') -PathType Leaf)) {
        Write-Fail "project.godot missing: $script:Project (run: .\scripts\gdmcp-bootstrap.ps1 install -ProjectPath $script:Project)"
        $failures++
    } else {
        Write-Ok "project: $script:Project"
    }
    $targetAddon = Join-Path $script:Project 'addons\godot_mcp'
    if (Test-Path -LiteralPath $targetAddon -PathType Container) {
        Write-Ok "plugin addon present: $targetAddon"
    } else {
        Write-Fail "plugin addon missing (run: .\scripts\gdmcp-bootstrap.ps1 install -ProjectPath $script:Project)"
        $failures++
    }
    $projectFile = Join-Path $script:Project 'project.godot'
    if (Test-Path -LiteralPath $projectFile -PathType Leaf) {
        $content = [IO.File]::ReadAllText($projectFile)
        if ($content -match 'editor_plugins') { Write-Ok 'plugin enabled in [editor_plugins]' }
        else {
            Write-Fail 'plugin not enabled in project.godot [editor_plugins]'
            $failures++
        }
        if ($content -match 'MCPRuntimeProbe') { Write-Ok 'runtime probe autoload configured' }
        else { Write-Info 'runtime probe autoload missing (added automatically on first editor launch)' }
    }

    Write-Step 'Checking server state'
    $script:CheckPort = $Port
    $stateFile = Join-Path $script:Project '.godot-mcp\bootstrap.json'
    if (Test-Path -LiteralPath $stateFile -PathType Leaf) {
        $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        Write-Info "configured port: $($state.port)"
    }
    if (Test-PortOccupied $Port) {
        Write-Ok "port $Port is listening"
        Write-Info "verify: curl -X POST http://127.0.0.1:$Port/mcp -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}'"
    } else {
        Write-Info "port $Port is free (editor not running)"
        Write-Info "start it: .\scripts\gdmcp-bootstrap.ps1 start -ProjectPath $script:Project -Port $Port"
    }

    if ($failures -gt 0) {
        Write-Fail "doctor found $failures failure(s)"
        exit 1
    }
    Write-Ok 'doctor: all checks passed'
}

switch ($Command) {
    'install' {
        Install-Plugin
        Write-Info "next: .\scripts\gdmcp-bootstrap.ps1 start -ProjectPath $script:Project -Port $Port"
        Write-Info "      .\scripts\gdmcp-bootstrap.ps1 doctor -ProjectPath $script:Project -Port $Port"
    }
    'start' { Start-Server }
    'doctor' {
        Resolve-Project
        Run-Doctor
    }
}
