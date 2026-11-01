# =====================================================================
#  PI PORTABLE INSTALLER (one click)
#  Double-click "Install Pi.cmd" (this file must sit next to it).
#
#  Everything is installed INSIDE ONE folder (miniconda-like, portable):
#    <root>\node         portable Node.js (pi requires >= 22.19)
#    <root>\git          Git for Windows Portable (registry-free, PATH-free)
#    <root>\npm-global   pi itself (npm -g with --prefix INSIDE the folder)
#    <root>\pi-home      ALL pi config: settings, sessions, packages, caches
#    <root>\cache\npm    npm cache (npm never writes in %USERPROFILE%)
#
#  Nothing is written system-wide. Uninstall = mode 3, or simply delete the folder.
# =====================================================================

param([switch] $AutoYes)

$ErrorCount = 0

$PKG_PI     = '@earendil-works/pi-coding-agent'
$PKG_SEARCH = 'npm:pi-web-access'   # web search + page fetch: installed ALWAYS

$MENU_PACKAGES = @(
    @{ id = 'npm:pi-lens';                  desc = 'Code diagnostics: errors/types, AST search, symbol navigation' },
    @{ id = 'npm:pi-mcp-adapter';           desc = 'MCP: connect external MCP servers to pi' },
    @{ id = 'npm:pi-subagents';              desc = 'Sub-agents and parallel workflows' },
    @{ id = 'npm:pi-browser-cdp-extension';  desc = 'Browser: drive a Chrome via DevTools protocol' },
    @{ id = 'npm:pi-local-rag';              desc = 'Local RAG: ask questions about your own documents' }
)

# ------------------------------------------------------------- helpers
function Say([string]$m)             { Write-Host $m }
function Step([string]$m, [int]$n)   { Write-Host ''; Write-Host ("[{0}] {1}" -f $n, $m) -ForegroundColor Cyan }
function Good([string]$m)            { Write-Host ("  -> {0}" -f $m) -ForegroundColor Green }
function Bad([string]$m)             { Write-Host ("  !! {0}" -f $m) -ForegroundColor Red }
function AskYN([string]$q) {
    $r = Read-Host $q
    return ($r -match '^(y|s)')
}
function EnsureDir([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
        Good ("Created: $p")
    }
}
function Download([string]$url, [string]$dest) {
    Say "  Downloading: $url"
    Say "  Saving to :  $dest"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $dest
        $mb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
        Good ("Saved: $mb MB")
        return $true
    } catch {
        Bad "Download failed: $($_.Exception.Message)"
        return $false
    }
}
function GetPiPaths([string]$r) {
    @{
        node     = Join-Path $r 'node\node.exe'
        nodeCli  = Join-Path $r 'node\node_modules\npm\bin\npm-cli.js'
        npmDir   = Join-Path $r 'npm-global'
        cli      = Join-Path $r 'npm-global\node_modules\@earendil-works\pi-coding-agent\dist\bundle\cli.js'
        gitExe   = Join-Path $r 'git\cmd\git.exe'
        bashExe  = Join-Path $r 'git\bin\bash.exe'
        settings = Join-Path $r 'pi-home\settings.json'
        gitconfig = Join-Path $r 'pi-home\gitconfig'
    }
}
function SetPiEnv([string]$r) {
    $env:PI_CODING_AGENT_DIR         = Join-Path $r 'pi-home'
    $env:PI_CODING_AGENT_SESSION_DIR = Join-Path $r 'pi-home\sessions'
    $env:NPM_CONFIG_CACHE            = Join-Path $r 'cache\npm'
    $env:GIT_CONFIG_GLOBAL           = Join-Path $r 'pi-home\gitconfig'
    $env:PATH = (Join-Path $r 'node') + ';' + (Join-Path $r 'git\cmd') + ';' + (Join-Path $r 'npm-global') + ';' + $env:PATH
}

# ------------------------------------------------------------- menu
Write-Host ''
Write-Host '================  PI PORTABLE INSTALLER  ================' -ForegroundColor Yellow
Write-Host 'pi = a coding assistant ("vibe coding") that runs in a terminal window.'
Write-Host 'Everything goes inside ONE folder. No system install, no registry writes.'
Write-Host 'The folder can be moved anywhere, or deleted at any time.'
Write-Host ''
$choice = Read-Host 'Action:  1 = install / repair    2 = update pi + packages    3 = UNINSTALL everything'

# ==================================================================== MODE 3: UNINSTALL
if ($choice -match '^3') {
    $root = Read-Host 'Folder to remove (Enter = default)'
    if (-not $root) { $root = "$env:USERPROFILE\PiPortable" }
    if (-not (Test-Path -LiteralPath $root)) {
        Bad "Folder not found: $root"
        Say 'Nothing to do.'
        return
    }
    Say ''
    Say 'This is what will be DELETED:'
    foreach ($item in (Get-ChildItem -LiteralPath $root)) {
        Say ("  - {0}" -f $item.Name)
    }
    Say ''
    if (-not (AskYN "Delete EVERYTHING in: $root  (y/n)")) {
        Say 'Aborted. Nothing changed.'
        return
    }
    Remove-Item -LiteralPath $root -Recurse -Force
    if (-not (Test-Path -LiteralPath $root)) {
        Good "Folder deleted: $root"
    } else {
        Bad "Could not delete completely: $root"
        $ErrorCount++
    }
    Say ''
    Say 'Checking for leftovers OUTSIDE the folder (normally there are none)...'
    $leftovers = @()
    foreach ($p in @(
        "$env:USERPROFILE\.pi",
        "$env:USERPROFILE\.npm",
        "$env:USERPROFILE\.gitconfig",
        "$env:LOCALAPPDATA\Programs\pi"
    )) {
        if (Test-Path -LiteralPath $p) { $leftovers += $p }
    }
    if ($leftovers.Count -eq 0) {
        Good 'No leftovers found. This machine is clean.'
    } else {
        Say 'Found these. NOTE: this installer never creates them (they come from a SYSTEM pi/npm install):'
        foreach ($p in $leftovers) { Say "  - $p" }
        if (AskYN 'Delete these too? (y/n)') {
            foreach ($p in $leftovers) {
                Remove-Item -LiteralPath $p -Recurse -Force
                Good "Removed: $p"
            }
        } else {
            Say 'Kept as they are.'
        }
    }
    Say ''
    Good 'Uninstall complete.'
    return
}

# ==================================================================== MODE 2: UPDATE
if ($choice -match '^2') {
    $root = Read-Host 'Pi folder (Enter = default)'
    if (-not $root) { $root = "$env:USERPROFILE\PiPortable" }
    $paths = GetPiPaths($root)
    if (-not (Test-Path -LiteralPath $paths.node) -or -not (Test-Path -LiteralPath $paths.cli)) {
        Bad 'Pi not found there. Run install first (choice 1).'
        return
    }
    SetPiEnv $root
    Step 'UPDATE pi core (via the portable npm)' 1
    & $paths.node $paths.nodeCli install -g --prefix $paths.npmDir --ignore-scripts "$PKG_PI@latest"
    Step 'UPDATE installed packages' 2
    & $paths.node $paths.cli update --extensions
    Say ''
    Good 'Update done.'
    return
}

# ==================================================================== MODE 1: INSTALL / REPAIR
$root = Read-Host 'Install pi in this folder (Enter = default)'
if (-not $root) { $root = "$env:USERPROFILE\PiPortable" }
Say "Pi folder: $root"

# --- step 1: preflight
Step 'PREFLIGHT CHECKS' 1
if ($env:OS -notmatch 'Windows') { Bad 'This installer is for Windows only.'; return }
if (-not [Environment]::Is64BitOperatingSystem) {
    Bad '64-bit Windows required (official Node.js / Git for Windows builds used here are 64-bit).'
    return
}
Good 'Windows 64-bit detected.'
Say 'Disk needed: about 500 MB (Node ~120, Git ~300, pi ~80).'
EnsureDir $root
EnsureDir (Join-Path $root 'node')
EnsureDir (Join-Path $root 'git')
EnsureDir (Join-Path $root 'npm-global')
EnsureDir (Join-Path $root 'pi-home')
EnsureDir (Join-Path $root 'cache\npm')
SetPiEnv $root

# --- step 2: Node.js
Step 'STEP 2: Node.js (portable, inside the folder)' 2
$paths = GetPiPaths($root)
$nodeOk = $false
if (Test-Path -LiteralPath $paths.node) {
    $v = ''
    try { $v = & $paths.node --version } catch { }
    if ($v -match '^v(\d+)\.(\d+)\.') {
        $maj = [int]$Matches[1]; $min = [int]$Matches[2]
        if (($maj -eq 22 -and $min -ge 19) -or ($maj -gt 22)) {
            Good "Node already installed and new enough: $v"
            $nodeOk = $true
        } else {
            Say "Node found but too old ($v). pi requires >= v22.19. Replacing it..."
            Remove-Item -LiteralPath $paths.node -Recurse -Force
        }
    }
}
if (-not $nodeOk) {
    Say 'Looking up the latest LTS Node.js (>= 22.19) on nodejs.org...'
    $nv = ''
    try {
        $idx = (Invoke-WebRequest -UseBasicParsing 'https://nodejs.org/dist/index.json').Content | ConvertFrom-Json
        foreach ($x in $idx) {
            $maj = [int]($x.version -replace '^v(\d+)\..*$', '$1')
            if ($x.lts -and $maj -ge 22) { $nv = $x.version; break }
        }
        if (-not $nv) {
            foreach ($x in $idx) {
                $maj = [int]($x.version -replace '^v(\d+)\..*$', '$1')
                if ($maj -ge 22) { $nv = $x.version; break }
            }
        }
    } catch {
        Bad "Could not read nodejs.org index: $($_.Exception.Message)"
        Say 'Cannot continue without Node.js.'
        return
    }
    if (-not $nv) { Bad 'No Node.js >= 22.19 found on nodejs.org.'; return }
    Say "Selected: Node.js $nv (LTS)"
    $zip = Join-Path $root "cache\node-$nv-win-x64.zip"
    $url = "https://nodejs.org/dist/$nv/node-$nv-win-x64.zip"
    if (-not (Download $url $zip)) { Say 'Cannot continue without Node.js.'; return }
    Say 'Extracting (this takes a moment)...'
    Add-Type -AssemblyName 'System.IO.Compression'
    $tmp = Join-Path $root 'cache\node-extract'
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    EnsureDir $tmp
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
    } catch {
        Bad "Extraction failed: $($_.Exception.Message)"
        return
    }
    $inner = Get-ChildItem -LiteralPath $tmp | Select-Object -First 1
    Move-Item -LiteralPath $inner.FullName -Destination (Join-Path $root 'node') -Force
    Remove-Item -LiteralPath $tmp -Recurse -Force
    Remove-Item -LiteralPath $zip -Force
    $v = ''
    try { $v = & $paths.node --version } catch { }
    if (-not $v) { Bad 'Node.js extraction failed (node.exe not runnable).' }
    Good "Node installed: $v"
}

# --- step 3: Git for Windows (Portable)
Step 'STEP 3: Git (portable: also gives Git Bash for the bash tool + code history)' 3
$paths = GetPiPaths($root)
if ((Test-Path -LiteralPath $paths.gitExe) -and (Test-Path -LiteralPath $paths.bashExe)) {
    Good 'Git already installed in the folder. Skipping download.'
} else {
    Say 'Looking up the latest Git for Windows PORTABLE release on GitHub...'
    $assetUrl = ''
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -Headers @{ 'User-Agent' = 'pi-portable-installer' } 'https://api.github.com/repos/git-for-windows/git/releases/latest'
        $rel = $resp.Content | ConvertFrom-Json
        foreach ($a in $rel.assets) {
            if ($a.name -like 'PortableGit-*64-bit.7z.exe') { $assetUrl = $a.browser_download_url; break }
        }
    } catch {
        Bad "Could not read GitHub releases: $($_.Exception.Message)"
    }
    if (-not $assetUrl) {
        Say 'Git could not be downloaded. pi still WORKS: the powershell tool does not need Git.'
        Say 'But you lose: the bash tool, git: package sources, and code history (git commits).'
    } else {
        $gname = $assetUrl.Split('/')[-1]
        $gexe = Join-Path $root "cache\$gname"
        if (-not (Download $assetUrl $gexe)) { Say 'Continuing WITHOUT Git (powershell tool only).' }
        else {
            Say 'Extracting the self-extracting 7z archive (this takes a moment)...'
            try {
                & $gexe '-y' "-o$($root)\git" | Out-Null
            } catch {
                Bad "Extraction failed: $($_.Exception.Message)"
            }
            Remove-Item -LiteralPath $gexe -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $paths.gitExe) {
                Good 'Portable git installed: <root>\git\cmd\git.exe'
                if (Test-Path -LiteralPath $paths.bashExe) {
                    Good 'Git Bash found: <root>\git\bin\bash.exe (pi bash tool will use it)'
                } else {
                    Say 'NOTE: bash.exe not found in this build; the bash tool may not work. The powershell tool works anyway.'
                }
            } else {
                Bad 'Git extraction failed. Continuing without Git.'
            }
        }
    }
}

# --- step 4: pi itself
Step 'STEP 4: install pi via the portable npm (prefix INSIDE the folder)' 4
$paths = GetPiPaths($root)
if (-not (Test-Path -LiteralPath $paths.nodeCli)) { Bad 'npm not found in the portable Node. Aborting.'; return }
Say "npm install -g --prefix $($paths.npmDir) $PKG_PI"
& $paths.node $paths.nodeCli install -g --prefix $paths.npmDir --ignore-scripts "$PKG_PI"
if (-not (Test-Path -LiteralPath $paths.cli)) {
    Bad 'pi install failed: cli.js not found.'
    return
}
Good 'pi installed.'

# --- step 5: launchers + settings (idempotent: safe on re-run)
Step 'STEP 5: launchers + pi-home settings.json' 5
$piCmdContent = @'
@echo off
set "PIROOT=%~dp0"
set "PATH=%PIROOT%node;%PIROOT%npm-global;%PIROOT%git\cmd;%PIROOT%git\bin;%PATH%"
set "PI_CODING_AGENT_DIR=%PIROOT%pi-home"
set "PI_CODING_AGENT_SESSION_DIR=%PIROOT%pi-home\sessions"
set "NPM_CONFIG_CACHE=%PIROOT%cache\npm"
set "GIT_CONFIG_GLOBAL=%PIROOT%pi-home\gitconfig"
"%PIROOT%node\node.exe" "%PIROOT%npm-global\node_modules\@earendil-works\pi-coding-agent\dist\bundle\cli.js" %*
'@
Set-Content -LiteralPath (Join-Path $root 'pi.cmd') -Value $piCmdContent -Encoding Default

$launchContent = @'
@echo off
cd /d "%~dp0"
call "%~dp0pi.cmd"
'@
Set-Content -LiteralPath (Join-Path $root 'Launch Pi.cmd') -Value $launchContent -Encoding Default
Good 'Launchers written: pi.cmd and "Launch Pi.cmd"'

# portable gitconfig (keeps git identity/config inside the folder, never %USERPROFILE%)
if (-not (Test-Path -LiteralPath $paths.gitconfig)) {
    New-Item -ItemType File -Force -Path $paths.gitconfig | Out-Null
    Good 'gitconfig placeholder created inside pi-home'
}

# settings.json (only created when missing; user edits are preserved on re-run)
if (-not (Test-Path -LiteralPath $paths.settings)) {
    $st = [ordered]@{
        defaultTools = @('read', 'powershell', 'edit', 'write')
        shellPath    = $paths.bashExe
    }
    ($st | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $paths.settings -Encoding UTF8
    Good 'settings.json created: model uses the powershell tool INSTEAD OF bash; portable Git Bash still serves ! commands, git and packages'
} else {
    $healed = $false
    try {
        $cfg = Get-Content -LiteralPath $paths.settings -Raw | ConvertFrom-Json
        $dirty = $false
        # heal shellPath when missing or pointing at a moved/deleted folder
        if (Test-Path -LiteralPath $paths.bashExe) {
            $sp = $null
            if ($cfg.PSObject.Properties['shellPath']) { $sp = $cfg.shellPath }
            if (-not $sp -or -not (Test-Path -LiteralPath $sp)) {
                $cfg | Add-Member -Name 'shellPath' -Value $paths.bashExe -Force
                $dirty = $true
                $healed = $true
            }
        }
        # defaultTools: replace bash with powershell (or add the set when unset)
        if (-not $cfg.PSObject.Properties['defaultTools']) {
            $cfg | Add-Member -Name 'defaultTools' -Value @('read', 'powershell', 'edit', 'write') -Force
            $dirty = $true
            $healed = $true
        } else {
            $dt = @($cfg.defaultTools)
            if ($dt -contains 'bash' -and -not ($dt -contains 'powershell')) {
                $dt2 = @()
                foreach ($t in $dt) {
                    if ($t -eq 'bash') { $dt2 += 'powershell' } else { $dt2 += $t }
                }
                $cfg | Add-Member -Name 'defaultTools' -Value $dt2 -Force
                $dirty = $true
                $healed = $true
            }
        }
        if ($dirty) {
            ($cfg | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $paths.settings -Encoding UTF8
            Good 'settings.json healed: powershell tool replaces bash; shellPath refreshed if stale.'
        }
    } catch { }
    if (-not $healed) { Say 'settings.json already exists and is consistent: user configuration left untouched.' }
}

# --- step 6: extensions
Step 'STEP 6: extensions (web search always installed, others on request)' 6
$settingsObj = $null
if (Test-Path -LiteralPath $paths.settings) {
    try { $settingsObj = Get-Content -LiteralPath $paths.settings -Raw | ConvertFrom-Json } catch { }
}
$installed = @()
if ($settingsObj -and $settingsObj.packages) {
    foreach ($p in $settingsObj.packages) {
        if ($p -is [string]) { $installed += $p } else { $installed += $p.source }
    }
}
function HasPackage([string]$src) {
    foreach ($i in $installed) { if ($i -eq $src) { return $true } }
    return $false
}

if (HasPackage $PKG_SEARCH) {
    Good 'Web search (pi-web-access) already installed.'
} else {
    Say 'Installing web search (npm:pi-web-access)...'
    & $paths.node $paths.cli install $PKG_SEARCH
    if ($LASTEXITCODE -eq 0) { Good 'Web search installed (web_search + fetch_content tools).' } else { Bad 'Web search install FAILED.'; $ErrorCount++ }
}
Say ''
Say 'Other extensions? Answer y or n to each:'
foreach ($pkg in $MENU_PACKAGES) {
    if (HasPackage $pkg.id) {
        Good ("Already installed: " + $pkg.id)
        Say ''
        continue
    }
    Write-Host ("  {0} = {1}" -f $pkg.id, $pkg.desc) -ForegroundColor Cyan
    if (AskYN ("Install {0}? (y/n)" -f $pkg.id)) {
        & $paths.node $paths.cli install $pkg.id
        if ($LASTEXITCODE -eq 0) { Good ("Installed: " + $pkg.id) } else { Bad ("Install failed: " + $pkg.id); $ErrorCount++ }
    } else {
        Say ("Skipped: " + $pkg.id)
    }
    Say ''
}
while ($true) {
    $extra = Read-Host 'Other sources? Type npm:name, git:owner/repo or https://... or N to stop'
    if ($extra -match '^(n|)$') { break }
    & $paths.node $paths.cli install $extra
    if ($LASTEXITCODE -eq 0) { Good "Installed: $extra" } else { Bad "Install failed: $extra"; $ErrorCount++ }
}

# --- step 7: summary
Step 'DONE: HOW TO USE PI' 7
Say ''
Say "Pi folder: $root"
Say 'Double-click "Launch Pi.cmd"  =  starts pi in that folder (terminal window opens)'
Say 'For another project: copy "Launch Pi.cmd" into the project folder, OR run pi.cmd from a terminal.'
Say ''
Say 'FIRST STEPS INSIDE PI:'
Say '  /login      choose a provider and connect it (API key or subscription). WITHOUT this pi cannot answer.'
Say '  /model      pick a model'
Say '  then just describe your task in plain language.'
Say ''
Say 'ALL INSIDE THE FOLDER (safe to delete):'
Say '  node\node.exe        git\cmd\git.exe        npm-global\ (pi)        pi-home\ (settings, sessions, packages)        cache\npm'
Say ''
Say 'UNINSTALL: run this installer again and choose 3, or simply delete the folder.'
Say ''
if ($ErrorCount -gt 0) {
    Bad ("Finished with {0} error(s). Check the messages above." -f $ErrorCount)
} else {
    Good 'Installation finished cleanly.'
}
