# Code tests for the setup runner. Missing installed software is not a failure.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$env:SETUP_NO_PAUSE = '1'
$env:SETUP_LOG_DIR = Join-Path $env:TEMP 'tqt-setup-test-logs'
New-Item -ItemType Directory -Force -Path $env:SETUP_LOG_DIR | Out-Null

$script:Failures = New-Object System.Collections.Generic.List[string]

function Add-Pass {
    param([string]$Name)
    Write-Host "[PASS] $Name"
}

function Add-Fail {
    param([string]$Name, [string]$Detail)
    $script:Failures.Add("${Name}: $Detail")
    Write-Host "[FAIL] ${Name}: $Detail"
}

function Assert-True {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    if ($Condition) { Add-Pass $Name } else { Add-Fail $Name $Detail }
}

function Invoke-Runner {
    param([string[]]$Arguments)
    $out = Join-Path $env:TEMP ("tqt-test-{0}.out" -f [guid]::NewGuid().ToString('N'))
    $err = Join-Path $env:TEMP ("tqt-test-{0}.err" -f [guid]::NewGuid().ToString('N'))
    $argLine = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $Root 'runner\Setup-Machine.ps1')
    ) + $Arguments
    $quoted = $argLine | ForEach-Object {
        $text = [string]$_
        if ($text -match '[\s"]') { '"' + ($text -replace '"', '\"') + '"' } else { $text }
    }
    $proc = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList ($quoted -join ' ') `
        -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $out `
        -RedirectStandardError $err
    $text = ''
    if (Test-Path -LiteralPath $out) { $text += (Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue) }
    if (Test-Path -LiteralPath $err) { $text += (Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue) }
    Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
    return @{ ExitCode = $proc.ExitCode; Text = [string]$text }
}

Write-Host 'Parsing scripts...'
Get-ChildItem -Path (Join-Path $Root 'runner') -Recurse -Filter *.ps1 | ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
    $messages = @($parseErrors | ForEach-Object { $_.Message })
    Assert-True "parse $($_.Name)" ($messages.Count -eq 0) ($messages -join '; ')
}
$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$tokens, [ref]$parseErrors)
$selfParseMessages = @()
if ($parseErrors) { $selfParseMessages = @($parseErrors | ForEach-Object { $_.Message }) }
Assert-True 'parse Invoke-RunnerTests.ps1' ($selfParseMessages.Count -eq 0) ($selfParseMessages -join '; ')

. (Join-Path $Root 'runner\Lib.ps1')
$catalog = Get-SetupCatalog
Assert-True 'catalog loads' ($catalog.ById.Count -gt 0) 'no components'

$catalogIds = @($catalog.ById.Keys | Sort-Object)
$fullIds = @($catalog.Profiles['full'].components | Sort-Object)
Assert-True 'full profile lists every component' (($catalogIds -join ',') -eq ($fullIds -join ',')) (($fullIds -join ','))

$ide = @(Get-InstallOrder -ById $catalog.ById -Ids @($catalog.Profiles['ide'].components))
function Get-IdIndex {
    param([string[]]$List, [string]$Id)
    for ($i = 0; $i -lt $List.Count; $i++) {
        if ($List[$i] -eq $Id) { return $i }
    }
    return -1
}
Assert-True 'ide install order' (($ide -join ',') -eq 'choco,git,python,uv,vscode,vscode-python') ($ide -join ',')
Assert-True 'choco before git' ((Get-IdIndex $ide 'choco') -lt (Get-IdIndex $ide 'git')) ($ide -join ',')
Assert-True 'python before uv' ((Get-IdIndex $ide 'python') -lt (Get-IdIndex $ide 'uv')) ($ide -join ',')

$cycle = @{
    a = [pscustomobject]@{ dependsOn = @('b') }
    b = [pscustomobject]@{ dependsOn = @('a') }
}
$cycleThrown = $false
try { Get-InstallOrder -ById $cycle -Ids @('a') } catch { if ($_.Exception.Message -match 'Vong phu thuoc') { $cycleThrown = $true } }
Assert-True 'dependency cycle is rejected' $cycleThrown 'expected a cycle error'

$unknownThrown = $false
try { Get-InstallOrder -ById $catalog.ById -Ids @('missing-tool') } catch { if ($_.Exception.Message -match 'missing-tool') { $unknownThrown = $true } }
Assert-True 'unknown component is rejected' $unknownThrown 'expected an unknown-id error'

$savedExtra = $env:CHOCO_EXTRA_ARGS
$env:CHOCO_EXTRA_ARGS = '--no-progress --force'
$chocoArgs = @(Get-ChocoArgumentList 'git')
Assert-True 'choco extra args are appended' (($chocoArgs -contains 'git') -and ($chocoArgs -contains '--force')) ($chocoArgs -join ' ')
if ($null -eq $savedExtra) { Remove-Item Env:CHOCO_EXTRA_ARGS -ErrorAction SilentlyContinue } else { $env:CHOCO_EXTRA_ARGS = $savedExtra }

Write-Host 'Running runner commands...'
$list = Invoke-Runner @('-List')
Assert-True 'list exits 0' ($list.ExitCode -eq 0) "exit $($list.ExitCode)"
foreach ($id in $catalogIds) {
    Assert-True "list shows $id" ($list.Text -match ("(?m)^\s+" + [regex]::Escape($id) + "\s+")) "missing from list output"
}
foreach ($profileId in @($catalog.ProfileOrder)) {
    Assert-True "list shows profile $profileId" ($list.Text -match ("(?m)^\s+" + [regex]::Escape($profileId) + "\s+")) 'missing from list output'
}

$help = Invoke-Runner @('-Help')
Assert-True 'help exits 0' ($help.ExitCode -eq 0) "exit $($help.ExitCode)"
Assert-True 'help mentions catalog' ($help.Text -match 'catalog') 'help text incomplete'
Assert-True 'help mentions Windows Terminal' ($help.Text -match 'Windows Terminal') 'help text incomplete'
Assert-True 'help mentions cleanup' ($help.Text -match 'cleanup') 'help text incomplete'

Assert-True 'profile root is not removable' (-not (Test-RemovableUserPath $env:USERPROFILE)) $env:USERPROFILE
Assert-True 'Windows directory is not removable' (-not (Test-RemovableUserPath 'C:\Windows')) 'C:\Windows'
Assert-True 'grok home is removable' (Test-RemovableUserPath '%USERPROFILE%\.grok') '%USERPROFILE%\.grok'
Assert-True 'leave-session is cleanup' ((Get-ProfileAction $catalog.Profiles['leave-session']) -eq 'cleanup') 'action'
Assert-True 'base stays an install profile' ((Get-ProfileAction $catalog.Profiles['base']) -eq 'install') 'action'

$leaveSession = @(Get-CleanupSteps -Catalog $catalog -ProfileId 'leave-session')
$leaveSessionText = ($leaveSession | ForEach-Object { $_.Target }) -join "`n"
Assert-True 'leave-session lists .dsh' ($leaveSessionText -match '\.dsh') $leaveSessionText
Assert-True 'leave-session does not uninstall node' ($leaveSessionText -notmatch 'nodejs-lts') $leaveSessionText

$leaveAll = @(Get-CleanupSteps -Catalog $catalog -ProfileId 'leave-all')
$leaveAllText = ($leaveAll | ForEach-Object { $_.Target }) -join "`n"
Assert-True 'leave-all lists nodejs-lts' ($leaveAllText -match 'nodejs-lts') $leaveAllText

$dry = Invoke-Runner @('-Cleanup', 'leave-session')
Assert-True 'cleanup dry-run exits 0' ($dry.ExitCode -eq 0) "exit $($dry.ExitCode)`n$($dry.Text)"
Assert-True 'cleanup dry-run lists .dsh' ($dry.Text -match '\.dsh') $dry.Text
Assert-True 'cleanup dry-run does not delete' ($dry.Text -notmatch 'Da xoa') $dry.Text
Assert-True '.dsh still exists after dry-run' (Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.dsh')) '.dsh missing'

$dryAll = Invoke-Runner @('-Cleanup', 'leave-all')
Assert-True 'leave-all dry-run exits 0' ($dryAll.ExitCode -eq 0) "exit $($dryAll.ExitCode)"
Assert-True 'leave-all dry-run mentions nodejs-lts' ($dryAll.Text -match 'nodejs-lts') $dryAll.Text
Assert-True 'leave-all dry-run does not delete' ($dryAll.Text -notmatch 'Da xoa') $dryAll.Text
Update-SessionPath
Assert-True 'node still exists after leave-all dry-run' (Test-CommandInstalled 'node') 'node missing'

$asInstall = Invoke-Runner @('-Profile', 'leave-session')
Assert-True 'install of cleanup profile exits 1' ($asInstall.ExitCode -eq 1) "exit $($asInstall.ExitCode)"
Assert-True 'install of cleanup profile points at cleanup' ($asInstall.Text -match 'cleanup') $asInstall.Text

$bad = Invoke-Runner @('-Profile', 'missing-profile')
Assert-True 'unknown profile exits 1' ($bad.ExitCode -eq 1) "exit $($bad.ExitCode)"
Assert-True 'unknown profile prints ERROR' ($bad.Text -match '\[ERROR\]') 'no ERROR line'

$check = Invoke-Runner @('-Check')
$errorLines = @($check.Text -split "`r?`n" | Where-Object { $_ -match '\[ERROR\]' })
Assert-True 'check does not crash' ($errorLines.Count -eq 0) ($errorLines -join ' | ')
$missing = @()
foreach ($id in $catalogIds) {
    $ok = $check.Text -match ("(?m)^\[OK\]\s+" + [regex]::Escape($id) + "\s*$")
    $miss = $check.Text -match ("(?m)^\[MISS\]\s+" + [regex]::Escape($id) + "\s*$")
    Assert-True "check classifies $id" ($ok -xor $miss) 'expected exactly one of OK or MISS'
    if ($miss) { $missing += $id }
}
if ($missing.Count -eq 0) {
    Assert-True 'check exits 0 when nothing is missing' ($check.ExitCode -eq 0) "exit $($check.ExitCode)"
} else {
    Assert-True 'check exits 1 when a tool is missing' ($check.ExitCode -eq 1) "exit $($check.ExitCode)"
}

Write-Host ''
if ($script:Failures.Count -gt 0) {
    Write-Host ("{0} test(s) failed" -f $script:Failures.Count)
    exit 1
}
Write-Host 'All tests passed.'
exit 0
