# Entry point for setup.bat. PowerShell 5.1.
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Profile,

    # Typed as [string]. The script body must not assign a catalog object to
    # $component: PowerShell is case-insensitive, so that assignment casts the object away.
    [string]$Component,

    [switch]$Check,

    [switch]$List,

    [switch]$Help,

    [string]$ElevatedResult
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib.ps1')

try {
    cmd /c 'chcp 65001 > nul'
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [Console]::OutputEncoding = $utf8
    $OutputEncoding = $utf8
} catch {
}

function Write-Setup {
    param([string]$Level, [string]$Message)
    $color = 'Gray'
    switch ($Level) {
        'OK' { $color = 'Green' }
        'MISS' { $color = 'Yellow' }
        'ERROR' { $color = 'Red' }
        'WARN' { $color = 'Yellow' }
        'INFO' { $color = 'Cyan' }
    }
    Write-Host ("[{0}] {1}" -f $Level, $Message) -ForegroundColor $color
}

function Show-SetupHelp {
    @"
Cai moi truong may dev.

  setup.bat                  Mo menu. Chon bo cai, hoac chon mot ung dung
                             (co Windows Terminal).
  setup.bat ide              Cai mot profile
  setup.bat --profile ide
  setup.bat --component rust
  setup.bat --component rust,dbeaver
  setup.bat --check          Kiem tra toan bo catalog
  setup.bat --check ide      Kiem tra mot profile
  setup.bat --list
  setup.bat --help

Profile va component nam trong catalog/. Them phan mem moi bang cach sua JSON,
khong tao file .bat moi. Xem AGENTS.md va docs/them-thanh-phan.md.

Bien tuy chon: .env.example
"@ | Write-Host
}

function Get-RequestedIds {
    param($Catalog)
    $ids = New-Object System.Collections.Generic.List[string]
    if ($Profile) {
        if (-not $Catalog.Profiles.ContainsKey($Profile)) {
            $known = ($Catalog.ProfileOrder -join ', ')
            throw "Khong co profile '$Profile'. Profile hien co: $known"
        }
        foreach ($id in @($Catalog.Profiles[$Profile].components)) {
            if (-not $ids.Contains($id)) { $ids.Add($id) }
        }
    }
    if ($Component) {
        foreach ($raw in ($Component -split ',')) {
            $id = $raw.Trim()
            if (-not $id) { continue }
            if (-not $Catalog.ById.ContainsKey($id)) {
                throw "Khong co component '$id'"
            }
            if (-not $ids.Contains($id)) { $ids.Add($id) }
        }
    }
    return @($ids)
}

function Invoke-Elevated {
    param([string[]]$ForwardArgs)
    $resultFile = Join-Path $env:TEMP ("tqt-setup-{0}.txt" -f [guid]::NewGuid().ToString('N'))
    $argItems = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $Script:RunnerDir 'Setup-Machine.ps1'),
        '-ElevatedResult', $resultFile
    ) + $ForwardArgs
    $quoted = $argItems | ForEach-Object {
        $text = [string]$_
        if ($text -match '[\s"]') { '"' + ($text -replace '"', '\"') + '"' } else { $text }
    }
    $argLine = $quoted -join ' '
    Write-Setup INFO 'Can quyen Administrator. Dang mo cua so UAC...'
    try {
        $proc = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -Verb RunAs -ArgumentList $argLine -Wait -PassThru
    } catch {
        throw 'Khong nang duoc quyen Administrator (UAC bi tu choi hoac khong mo duoc).'
    }
    if (Test-Path -LiteralPath $resultFile) {
        $codeText = (Get-Content -LiteralPath $resultFile -Raw).Trim()
        Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
        return [int]$codeText
    }
    if ($proc -and $proc.ExitCode) { return [int]$proc.ExitCode }
    return 1
}

function Install-OneComponent {
    param($Component)
    $id = $Component.id
    Write-Host ""
    Write-Setup INFO "Dang xu ly $id ($($Component.name))"
    if (Test-ComponentDetected $Component) {
        Write-Setup OK "$id da co san"
    } else {
        Write-Setup INFO "Dang cai $id"
        if ($Component.install.type -eq 'fallback') {
            $installed = $false
            $errors = @()
            foreach ($step in @($Component.install.steps)) {
                try {
                    Invoke-InstallSpec $step
                } catch {
                    $errors += $_.Exception.Message
                    Write-Setup WARN $_.Exception.Message
                }
                if (Test-ComponentDetected $Component) {
                    $installed = $true
                    break
                }
            }
            if (-not $installed) {
                throw ("Khong cai duoc {0}. {1}" -f $id, ($errors -join ' | '))
            }
        } else {
            Invoke-InstallSpec $Component.install
            if (-not (Test-ComponentDetected $Component)) {
                throw "Da chay cai $id nhung khong phat hien duoc tool"
            }
        }
        Write-Setup OK "Da cai $id"
    }

    $hasAfter = $Component.PSObject.Properties.Name -contains 'afterInstall' -and $Component.afterInstall
    if ($hasAfter) {
        try {
            Invoke-InstallSpec $Component.afterInstall
            Write-Setup OK "Da chay buoc sau cai dat cho $id"
        } catch {
            Write-Setup WARN "$id da co, nhung buoc sau cai dat loi: $($_.Exception.Message)"
        }
    }
}

function Show-AppMenu {
    param($Catalog)
    Write-Host ''
    Write-Host 'Chon mot ung dung de cai:'
    $ids = @($Catalog.ById.Keys | Sort-Object { $Catalog.ById[$_].name })
    $map = @{}
    $index = 1
    foreach ($id in $ids) {
        $entry = $Catalog.ById[$id]
        Write-Host ("  {0,2}. {1,-18} {2}" -f $index, $id, $entry.name)
        $map[[string]$index] = $id
        $index++
    }
    Write-Host '   b. Quay lai'
    Write-Host '   q. Thoat'
    $answer = Read-Host 'Chon'
    $answer = if ($answer) { $answer.Trim() } else { '' }
    if ($answer -eq '' -or $answer -eq 'b') { return 'back' }
    if ($answer -eq 'q') { return $null }
    if ($map.ContainsKey($answer)) {
        return @{ Profile = ''; Component = $map[$answer]; Check = $false }
    }
    if ($Catalog.ById.ContainsKey($answer)) {
        return @{ Profile = ''; Component = $answer; Check = $false }
    }
    Write-Setup WARN 'Lua chon khong hop le'
    return (Show-AppMenu $Catalog)
}

function Show-SetupMenu {
    param($Catalog)
    Write-Host ''
    Write-Host '========================================'
    Write-Host '  CAI MOI TRUONG MAY DEV'
    Write-Host '========================================'
    $index = 1
    $map = @{}
    foreach ($profileId in $Catalog.ProfileOrder) {
        $profile = $Catalog.Profiles[$profileId]
        Write-Host ("  {0}. {1,-16} {2}" -f $index, $profile.id, $profile.description)
        $map[[string]$index] = $profile.id
        $index++
    }
    Write-Host '  i. Cai mot ung dung (Windows Terminal, Bitwarden, ...)'
    Write-Host '  c. Kiem tra may (toan bo catalog)'
    Write-Host '  p. Kiem tra mot profile'
    Write-Host '  l. Liet ke catalog'
    Write-Host '  q. Thoat'
    $answer = Read-Host 'Chon'
    $answer = if ($answer) { $answer.Trim() } else { '' }
    if ($answer -eq '' -or $answer -eq 'q') { return $null }
    if ($map.ContainsKey($answer)) {
        return @{ Profile = $map[$answer]; Component = ''; Check = $false }
    }
    if ($Catalog.Profiles.ContainsKey($answer)) {
        return @{ Profile = $answer; Component = ''; Check = $false }
    }
    switch ($answer) {
        'c' { return @{ Profile = ''; Component = ''; Check = $true } }
        'l' {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Script:RunnerDir 'Setup-Machine.ps1') -List
            return (Show-SetupMenu $Catalog)
        }
        'p' {
            $name = Read-Host 'Id profile'
            if (-not $name) { return $null }
            return @{ Profile = $name.Trim(); Component = ''; Check = $true }
        }
        'i' {
            $picked = Show-AppMenu $Catalog
            if ($picked -eq 'back') { return (Show-SetupMenu $Catalog) }
            return $picked
        }
        default {
            Write-Setup WARN 'Lua chon khong hop le'
            return (Show-SetupMenu $Catalog)
        }
    }
}

$exitCode = 0
$pauseOnExit = $false
$transcriptStarted = $false

try {
    Import-SetupEnv
    $catalog = Get-SetupCatalog

    if ($Help) {
        Show-SetupHelp
        exit 0
    }

    if ($List) {
        Write-Host 'Profiles:'
        foreach ($profileId in $catalog.ProfileOrder) {
            $profile = $catalog.Profiles[$profileId]
            Write-Host ("  {0,-18} {1}" -f $profile.id, $profile.name)
            $memberList = @($profile.components) -join ', '
            Write-Host ("  {0,-18} {1}" -f '', $memberList)
        }
        Write-Host ''
        Write-Host 'Components:'
        foreach ($componentId in @($catalog.ById.Keys | Sort-Object)) {
            $entry = $catalog.ById[$componentId]
            $deps = @()
            if ($entry.dependsOn) { $deps = @($entry.dependsOn) }
            $depText = '(khong)'
            if ($deps.Count -gt 0) { $depText = ($deps -join ', ') }
            Write-Host ("  {0,-18} {1}  [{2}]  can: {3}" -f $entry.id, $entry.name, $entry.install.type, $depText)
        }
        exit 0
    }

    $logDir = Join-Path $Script:SetupRoot 'logs'
    if ($env:SETUP_LOG_DIR) {
        if ([System.IO.Path]::IsPathRooted($env:SETUP_LOG_DIR)) {
            $logDir = $env:SETUP_LOG_DIR
        } else {
            $logDir = Join-Path $Script:SetupRoot $env:SETUP_LOG_DIR
        }
    }
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("setup-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Start-Transcript -Path $logPath -Force | Out-Null
    $transcriptStarted = $true
    Write-Setup INFO "Log: $logPath"

    if (-not $Profile -and -not $Component -and -not $Check) {
        $choice = Show-SetupMenu $catalog
        if (-not $choice) { exit 0 }
        $Profile = $choice.Profile
        $Component = $choice.Component
        $Check = [bool]$choice.Check
    }

    $requested = @(Get-RequestedIds $catalog)
    if ($requested.Count -eq 0 -and $Check -and -not $Profile -and -not $Component) {
        $requested = @($catalog.ById.Keys | Sort-Object)
    }
    if ($requested.Count -eq 0) {
        throw 'Chua chon profile hoac component. Chay setup.bat --help'
    }

    $order = @(Get-InstallOrder -ById $catalog.ById -Ids $requested)
    $needsAdmin = $false
    foreach ($id in $order) {
        if ($catalog.ById[$id].admin) { $needsAdmin = $true }
    }

    if ($Check) {
        $missing = @()
        foreach ($id in $order) {
            if (Test-ComponentDetected $catalog.ById[$id]) {
                Write-Setup OK $id
            } else {
                Write-Setup MISS $id
                $missing += $id
            }
        }
        if ($missing.Count -gt 0) {
            Write-Setup WARN ("Chua co: {0}" -f ($missing -join ', '))
            $exitCode = 1
        } else {
            Write-Setup OK 'Tat ca muc da chon deu co san'
        }
    } else {
        if ($needsAdmin -and -not (Test-IsAdmin)) {
            if ($transcriptStarted) {
                Stop-Transcript | Out-Null
                $transcriptStarted = $false
            }
            $forward = @()
            if ($Profile) { $forward += @('-Profile', $Profile) }
            if ($Component) { $forward += @('-Component', $Component) }
            $exitCode = Invoke-Elevated $forward
            exit $exitCode
        }
        $pauseOnExit = $true
        $failed = New-Object System.Collections.Generic.List[string]
        $blocked = @{}
        foreach ($id in $order) {
            $deps = @()
            if ($catalog.ById[$id].dependsOn) { $deps = @($catalog.ById[$id].dependsOn) }
            $depFailed = $false
            foreach ($dep in $deps) {
                if ($blocked.ContainsKey($dep)) { $depFailed = $true }
            }
            if ($depFailed) {
                Write-Setup ERROR "$id bi bo qua vi phu thuoc chua cai duoc"
                $failed.Add($id)
                $blocked[$id] = $true
                continue
            }
            try {
                Install-OneComponent $catalog.ById[$id]
            } catch {
                Write-Setup ERROR $_.Exception.Message
                $failed.Add($id)
                $blocked[$id] = $true
            }
        }
        Write-Host ''
        if ($failed.Count -gt 0) {
            Write-Setup ERROR ("Loi: {0}" -f ($failed -join ', '))
            $exitCode = 1
        } else {
            Write-Setup OK 'Xong. Mo terminal moi de dung PATH vua cai.'
        }
    }
} catch {
    Write-Setup ERROR $_.Exception.Message
    $exitCode = 1
} finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
    if ($ElevatedResult) {
        Set-Content -LiteralPath $ElevatedResult -Value $exitCode -Encoding ASCII
    }
}

if ($pauseOnExit -and $env:SETUP_NO_PAUSE -ne '1') {
    cmd /c pause
}
exit $exitCode
