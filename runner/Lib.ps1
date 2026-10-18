# Shared helpers for the machine setup runner. PowerShell 5.1.
# Dot-source only. This file does not install anything.

$Script:RunnerDir = $PSScriptRoot
$Script:SetupRoot = Split-Path -Parent $PSScriptRoot
$Script:ScriptsDir = Join-Path $PSScriptRoot 'scripts'
$Script:CatalogDir = Join-Path $Script:SetupRoot 'catalog'

function Import-SetupEnv {
    $path = Join-Path $Script:SetupRoot '.env'
    if (-not (Test-Path -LiteralPath $path)) {
        return
    }
    Get-Content -LiteralPath $path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) {
            return
        }
        $idx = $line.IndexOf('=')
        if ($idx -lt 1) {
            return
        }
        $name = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        # A variable already set on the process wins over .env.
        if ($null -ne [Environment]::GetEnvironmentVariable($name, 'Process') -and [Environment]::GetEnvironmentVariable($name, 'Process') -ne '') {
            return
        }
        Set-Item -Path "Env:$name" -Value $value
    }
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-SessionPath {
    param([string]$Path)
    if (-not $Path) {
        return
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $trimmed = $Path.TrimEnd('\')
    foreach ($part in ($env:Path -split ';')) {
        if ($part.TrimEnd('\') -ieq $trimmed) {
            return
        }
    }
    $env:Path = "$env:Path;$Path"
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $combined = @($machine, $user) | Where-Object { $_ }
    $env:Path = $combined -join ';'

    Add-SessionPath "$env:ProgramData\chocolatey\bin"
    Add-SessionPath "$env:ProgramFiles\Git\cmd"
    Add-SessionPath "$env:ProgramFiles\Git\bin"
    Add-SessionPath "$env:USERPROFILE\.cargo\bin"
    Add-SessionPath "$env:ProgramFiles\nodejs"
    Add-SessionPath "$env:APPDATA\npm"
    Add-SessionPath "$env:USERPROFILE\.grok\bin"
    Add-SessionPath "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
    Add-SessionPath "$env:ProgramFiles\Microsoft VS Code\bin"
    Add-SessionPath "$env:LOCALAPPDATA\DBeaver"
    Add-SessionPath "$env:ProgramFiles\DBeaver"
    Add-SessionPath "$env:ProgramFiles\Redis"

    $pythonRoot = Join-Path $env:LOCALAPPDATA 'Programs\Python'
    if (Test-Path -LiteralPath $pythonRoot) {
        Get-ChildItem -LiteralPath $pythonRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Add-SessionPath $_.FullName
            Add-SessionPath (Join-Path $_.FullName 'Scripts')
        }
    }
    $userPython = Join-Path $env:APPDATA 'Python'
    if (Test-Path -LiteralPath $userPython) {
        Get-ChildItem -LiteralPath $userPython -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Add-SessionPath (Join-Path $_.FullName 'Scripts')
        }
    }
    $pgRoot = Join-Path $env:ProgramFiles 'PostgreSQL'
    if (Test-Path -LiteralPath $pgRoot) {
        Get-ChildItem -LiteralPath $pgRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Add-SessionPath (Join-Path $_.FullName 'bin')
        }
    }
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Khong tim thay $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
}

function Assert-InstallSpec {
    param($Spec, [string]$Label, [bool]$AllowFallback)
    if (-not $Spec -or -not $Spec.type) {
        throw "$Label thieu install.type"
    }
    switch ($Spec.type) {
        'choco' {
            if (-not $Spec.package) { throw "$Label thieu install.package" }
        }
        'winget' {
            if (-not $Spec.id) { throw "$Label thieu install.id" }
        }
        'command' {
            if (-not $Spec.run) { throw "$Label thieu install.run" }
        }
        'script' {
            if (-not $Spec.script) { throw "$Label thieu install.script" }
            $full = Join-Path $Script:ScriptsDir $Spec.script
            if (-not (Test-Path -LiteralPath $full)) {
                throw "$Label tro toi script khong ton tai: $($Spec.script)"
            }
        }
        'fallback' {
            if (-not $AllowFallback) { throw "$Label khong duoc long fallback" }
            $steps = @()
            if ($Spec.steps) { $steps = @($Spec.steps) }
            if ($steps.Count -eq 0) { throw "$Label thieu install.steps" }
            $i = 0
            foreach ($step in $steps) {
                Assert-InstallSpec -Spec $step -Label "$Label.steps[$i]" -AllowFallback $false
                $i++
            }
        }
        default { throw "$Label co install.type khong ho tro: $($Spec.type)" }
    }
}

function Assert-DetectSpec {
    param($Detect, [string]$Label)
    if (-not $Detect -or -not $Detect.type) {
        throw "$Label thieu detect.type"
    }
    switch ($Detect.type) {
        'command' {
            if (-not $Detect.command) { throw "$Label thieu detect.command" }
            if ($Detect.command -match '\s') {
                throw "$Label detect.command chi la ten lenh, khong phai cau lenh day du"
            }
        }
        'path' {
            $paths = @()
            if ($Detect.paths) { $paths = @($Detect.paths) }
            if ($paths.Count -eq 0) { throw "$Label thieu detect.paths" }
        }
        'script' {
            if (-not $Detect.script) { throw "$Label thieu detect.script" }
            $full = Join-Path $Script:ScriptsDir $Detect.script
            if (-not (Test-Path -LiteralPath $full)) {
                throw "$Label tro toi script khong ton tai: $($Detect.script)"
            }
        }
        default { throw "$Label co detect.type khong ho tro: $($Detect.type)" }
    }
}

function Get-SetupCatalog {
    $componentsDoc = Read-JsonFile (Join-Path $Script:CatalogDir 'components.json')
    $profilesDoc = Read-JsonFile (Join-Path $Script:CatalogDir 'profiles.json')
    if ($componentsDoc.version -ne 1) { throw 'components.json version phai la 1' }
    if ($profilesDoc.version -ne 1) { throw 'profiles.json version phai la 1' }

    $byId = @{}
    foreach ($component in @($componentsDoc.components)) {
        if (-not $component.id) { throw 'Mot component thieu id' }
        if ($component.id -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
            throw "Id khong hop le: $($component.id). Dung chu thuong, so, va dau gach."
        }
        if ($byId.ContainsKey($component.id)) {
            throw "Id bi trung: $($component.id)"
        }
        if (-not $component.name) { throw "$($component.id) thieu name" }
        if ($null -eq $component.admin) { throw "$($component.id) thieu admin" }
        Assert-DetectSpec -Detect $component.detect -Label $component.id
        Assert-InstallSpec -Spec $component.install -Label $component.id -AllowFallback $true
        if ($component.PSObject.Properties.Name -contains 'afterInstall' -and $component.afterInstall) {
            Assert-InstallSpec -Spec $component.afterInstall -Label "$($component.id).afterInstall" -AllowFallback $false
        }
        if ($component.PSObject.Properties.Name -contains 'remove' -and $component.remove) {
            Assert-RemoveSpec -Spec $component.remove -Label $component.id
        }
        $deps = @()
        if ($component.dependsOn) { $deps = @($component.dependsOn) }
        foreach ($dep in $deps) {
            if (-not $dep) { throw "$($component.id) co dependsOn rong" }
        }
        $byId[$component.id] = $component
    }
    if ($byId.Count -eq 0) { throw 'Catalog khong co component' }

    foreach ($component in $byId.Values) {
        $deps = @()
        if ($component.dependsOn) { $deps = @($component.dependsOn) }
        foreach ($dep in $deps) {
            if (-not $byId.ContainsKey($dep)) {
                throw "$($component.id) phu thuoc $dep nhung id nay khong co trong catalog"
            }
        }
    }

    $profiles = @{}
    $profileOrder = New-Object System.Collections.Generic.List[string]
    foreach ($profile in @($profilesDoc.profiles)) {
        if (-not $profile.id) { throw 'Mot profile thieu id' }
        if ($profiles.ContainsKey($profile.id)) { throw "Profile bi trung: $($profile.id)" }
        $ids = @()
        if ($profile.components) { $ids = @($profile.components) }
        if ($ids.Count -eq 0) { throw "Profile $($profile.id) khong co component" }
        foreach ($id in $ids) {
            if (-not $byId.ContainsKey($id)) {
                throw "Profile $($profile.id) tro toi component khong ton tai: $id"
            }
        }
        $action = Get-ProfileAction $profile
        if ($action -eq 'cleanup') {
            $level = [string]$profile.cleanupLevel
            if ($level -ne 'session' -and $level -ne 'all') {
                throw "Profile $($profile.id) can cleanupLevel session hoac all"
            }
            foreach ($id in $ids) {
                $remove = $null
                if ($byId[$id].PSObject.Properties.Name -contains 'remove') { $remove = $byId[$id].remove }
                if (-not $remove) {
                    throw "Profile $($profile.id) tro toi $id nhung component nay khong co remove"
                }
            }
        }
        $profiles[$profile.id] = $profile
        $profileOrder.Add($profile.id)
    }

    return @{
        ById         = $byId
        Profiles     = $profiles
        ProfileOrder = $profileOrder
    }
}

function Get-InstallOrder {
    param($ById, [string[]]$Ids)
    $order = New-Object System.Collections.Generic.List[string]
    $visiting = @{}

    function Visit-Component {
        param([string]$Id)
        if ($order.Contains($Id)) { return }
        if ($visiting.ContainsKey($Id)) { throw "Vong phu thuoc tai $Id" }
        if (-not $ById.ContainsKey($Id)) { throw "Khong co component $Id" }
        $visiting[$Id] = $true
        $deps = @()
        if ($ById[$Id].dependsOn) { $deps = @($ById[$Id].dependsOn) }
        foreach ($dep in $deps) {
            Visit-Component -Id $dep
        }
        $visiting.Remove($Id)
        $order.Add($Id)
    }

    foreach ($id in $Ids) {
        Visit-Component -Id $id
    }
    return @($order)
}

function Test-CommandInstalled {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    # The Microsoft Store stub answers `python` even when Python is not installed.
    # Other WindowsApps commands, notably winget, are real programs.
    if ($Name -match '^(python|python3)(\.exe)?$' -and $cmd.Source -like '*\WindowsApps\*') {
        return $false
    }
    return $true
}

function Test-ComponentDetected {
    param($Component)
    Update-SessionPath
    $detect = $Component.detect
    switch ($detect.type) {
        'command' { return (Test-CommandInstalled $detect.command) }
        'path' {
            foreach ($path in @($detect.paths)) {
                $expanded = [Environment]::ExpandEnvironmentVariables($path)
                if (Test-Path -LiteralPath $expanded) { return $true }
            }
            return $false
        }
        'script' {
            $full = Join-Path $Script:ScriptsDir $detect.script
            # Child process: `exit` inside a nested script would close this runner.
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $full
            return ($LASTEXITCODE -eq 0)
        }
        default { throw "detect.type khong ho tro: $($detect.type)" }
    }
}

function Invoke-SetupCommand {
    param([string]$Run)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $Run
    if ($LASTEXITCODE -ne 0) {
        throw "Lenh that bai (exit $LASTEXITCODE)"
    }
}

function Invoke-SetupScript {
    param([string]$ScriptName)
    $full = Join-Path $Script:ScriptsDir $ScriptName
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $full
    if ($LASTEXITCODE -ne 0) {
        throw "Script $ScriptName that bai (exit $LASTEXITCODE)"
    }
}

function Get-ChocoArgumentList {
    param([string]$Package)
    $extra = '--no-progress'
    if ($env:CHOCO_EXTRA_ARGS) { $extra = $env:CHOCO_EXTRA_ARGS }
    $args = @('install', $Package, '-y')
    if ($extra) {
        $args += $extra.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
    }
    return $args
}

function Invoke-InstallSpec {
    param($Spec)
    switch ($Spec.type) {
        'choco' {
            $chocoArgs = Get-ChocoArgumentList $Spec.package
            & choco @chocoArgs
            # 3010 means success and a reboot is requested.
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
                throw "choco install $($Spec.package) that bai (exit $LASTEXITCODE)"
            }
        }
        'winget' {
            if (-not (Test-CommandInstalled 'winget')) {
                throw 'winget khong co san'
            }
            & winget install --id $Spec.id -e --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
                throw "winget install $($Spec.id) that bai (exit $LASTEXITCODE)"
            }
        }
        'command' { Invoke-SetupCommand $Spec.run }
        'script' { Invoke-SetupScript $Spec.script }
        default { throw "install.type khong ho tro o buoc nay: $($Spec.type)" }
    }
}

function Find-CodeCmd {
    $cmd = Get-Command code -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and $cmd.Source -notlike '*\WindowsApps\*') {
        return $cmd.Source
    }
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Test-DshInNormalPowerShell {
    # The runner is started with -ExecutionPolicy Bypass, which exports
    # PSExecutionPolicyPreference. A terminal the user opens does not have that variable.
    Remove-Item Env:PSExecutionPolicyPreference -ErrorAction SilentlyContinue
    $command = @'
$ErrorActionPreference = 'Stop'
try {
    dsh --version | Out-Null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} catch {
    exit 1
}
'@
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
    $stdout = Join-Path $env:TEMP ("dsh-probe-{0}.out" -f [guid]::NewGuid().ToString('N'))
    $stderr = Join-Path $env:TEMP ("dsh-probe-{0}.err" -f [guid]::NewGuid().ToString('N'))
    $probe = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList "-NoProfile -EncodedCommand $encoded" `
        -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
    return ($probe.ExitCode -eq 0)
}

function Get-ProfileAction {
    param($Profile)
    if ($Profile -and $Profile.PSObject.Properties.Name -contains 'action' -and $Profile.action) {
        $action = [string]$Profile.action
        if ($action -ne 'install' -and $action -ne 'cleanup') {
            throw "Profile $($Profile.id) co action khong ho tro: $action"
        }
        return $action
    }
    return 'install'
}

function Assert-RemoveSpec {
    param($Spec, [string]$Label)
    $session = @()
    if ($Spec.session) { $session = @($Spec.session) }
    foreach ($path in $session) {
        if (-not $path) { throw "$Label co remove.session rong" }
    }
    $packages = @()
    if ($Spec.package) { $packages = @($Spec.package) }
    if ($session.Count -eq 0 -and $packages.Count -eq 0) {
        throw "$Label remove khong co session hoac package"
    }
    foreach ($package in $packages) {
        if ($package.type -eq 'choco' -and $package.package) { continue }
        if ($package.type -eq 'npm' -and $package.package) { continue }
        if ($package.type -eq 'path' -and $package.path) { continue }
        throw "$Label co remove.package khong ho tro"
    }
}

function Test-RemovableUserPath {
    param([string]$Path)
    if (-not $Path -or $Path -match '[\*\?]') { return $false }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if (-not $expanded) { return $false }
    $full = [System.IO.Path]::GetFullPath($expanded)
    $roots = New-Object System.Collections.Generic.List[string]
    foreach ($root in @($env:USERPROFILE, $env:APPDATA, $env:LOCALAPPDATA)) {
        if (-not $root) { continue }
        $roots.Add([System.IO.Path]::GetFullPath($root).TrimEnd('\'))
    }
    foreach ($root in $roots) {
        if ($full.TrimEnd('\') -eq $root) { return $false }
        if ($full.StartsWith($root + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Resolve-RemovablePath {
    param([string]$Path)
    if (-not (Test-RemovableUserPath $Path)) {
        throw "Duong dan khong duoc phep xoa: $Path"
    }
    return [System.IO.Path]::GetFullPath(([Environment]::ExpandEnvironmentVariables($Path)))
}

function Get-CleanupSteps {
    param($Catalog, [string]$ProfileId)
    if (-not $Catalog.Profiles.ContainsKey($ProfileId)) {
        throw "Khong co profile '$ProfileId'"
    }
    $profile = $Catalog.Profiles[$ProfileId]
    if ((Get-ProfileAction $profile) -ne 'cleanup') {
        throw "Profile $ProfileId khong phai lenh xoa"
    }
    $level = [string]$profile.cleanupLevel
    $listed = @($profile.components)
    $installOrder = @(Get-InstallOrder -ById $Catalog.ById -Ids $listed)
    $steps = New-Object System.Collections.Generic.List[object]
    for ($i = $installOrder.Count - 1; $i -ge 0; $i--) {
        $id = $installOrder[$i]
        if ($listed -notcontains $id) { continue }
        $remove = $Catalog.ById[$id].remove
        if ($level -eq 'session' -or $level -eq 'all') {
            $session = @()
            if ($remove.session) { $session = @($remove.session) }
            foreach ($path in $session) {
                $full = Resolve-RemovablePath $path
                $steps.Add([pscustomobject]@{ Id = $id; Kind = 'path'; Target = $full })
            }
        }
        if ($level -eq 'all') {
            $packages = @()
            if ($remove.package) { $packages = @($remove.package) }
            foreach ($package in $packages) {
                if ($package.type -eq 'path') {
                    $full = Resolve-RemovablePath $package.path
                    $steps.Add([pscustomobject]@{ Id = $id; Kind = 'path'; Target = $full })
                } else {
                    $steps.Add([pscustomobject]@{ Id = $id; Kind = $package.type; Target = [string]$package.package })
                }
            }
        }
    }
    return @($steps)
}

function Invoke-CleanupStep {
    param($Step)
    if ($Step.Kind -eq 'path') {
        $full = Resolve-RemovablePath $Step.Target
        if (-not (Test-Path -LiteralPath $full)) {
            return "Khong co $full"
        }
        Remove-Item -LiteralPath $full -Recurse -Force
        return "Da xoa $full"
    }
    if ($Step.Kind -eq 'choco') {
        & choco uninstall $Step.Target -y --no-progress
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 404) {
            throw "choco uninstall $($Step.Target) that bai (exit $LASTEXITCODE)"
        }
        return "Da go choco $($Step.Target)"
    }
    if ($Step.Kind -eq 'npm') {
        & npm uninstall -g $Step.Target
        if ($LASTEXITCODE -ne 0) {
            throw "npm uninstall $($Step.Target) that bai (exit $LASTEXITCODE)"
        }
        return "Da go npm $($Step.Target)"
    }
    throw "Buoc xoa khong ho tro: $($Step.Kind)"
}

function Find-DBeaverExe {
    $candidates = @(
        "$env:LOCALAPPDATA\DBeaver\dbeaver.exe",
        "$env:ProgramFiles\DBeaver\dbeaver.exe",
        "${env:ProgramFiles(x86)}\DBeaver\dbeaver.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    $roots = @(
        "$env:LOCALAPPDATA\Programs",
        "$env:LOCALAPPDATA",
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}"
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $hit = Get-ChildItem -Path $root -Filter dbeaver.exe -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}
