# A healthy Windows Terminal package registers "Open in Terminal" itself.
# Windows 10 only does that after the license and Xaml dependency are in place.
# If that verb is missing, add a classic shell command. If it is present, drop
# the classic key so Explorer does not show two entries.
$ErrorActionPreference = 'Stop'

function Test-NativeTerminalVerb {
    # The user-profile folder does not expose Directory shell verbs. Probe a normal directory.
    $probe = $env:SystemRoot
    if (-not $probe) { $probe = 'C:\Windows' }
    $shell = New-Object -ComObject Shell.Application
    $parent = $shell.NameSpace((Split-Path -Parent $probe))
    if (-not $parent) { return $false }
    $item = $parent.ParseName((Split-Path -Leaf $probe))
    if (-not $item) { return $false }
    foreach ($verb in @($item.Verbs())) {
        $name = ([string]$verb.Name) -replace '&', ''
        if ($name -match 'Open in Terminal') { return $true }
    }
    return $false
}

function Remove-ClassicTerminalMenu {
    $keys = @(
        'HKCU:\Software\Classes\Directory\shell\OpenWithTerminal',
        'HKCU:\Software\Classes\Directory\Background\shell\OpenWithTerminal',
        'HKCU:\Software\Classes\Drive\shell\OpenWithTerminal',
        'HKLM:\SOFTWARE\Classes\Directory\shell\OpenWithTerminal',
        'HKLM:\SOFTWARE\Classes\Directory\Background\shell\OpenWithTerminal',
        'HKLM:\SOFTWARE\Classes\Drive\shell\OpenWithTerminal'
    )
    foreach ($key in $keys) {
        if (Test-Path -LiteralPath $key) {
            Remove-Item -LiteralPath $key -Recurse -Force
        }
    }
}

if (Test-NativeTerminalVerb) {
    Remove-ClassicTerminalMenu
    exit 0
}

$wt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
if (-not (Test-Path -LiteralPath $wt)) {
    throw 'Khong co wt.exe trong WindowsApps, khong gan duoc menu Explorer'
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$roots = @(
    'HKCU:\Software\Classes\Directory\shell',
    'HKCU:\Software\Classes\Directory\Background\shell',
    'HKCU:\Software\Classes\Drive\shell'
)
if ($isAdmin) {
    $roots += @(
        'HKLM:\SOFTWARE\Classes\Directory\shell',
        'HKLM:\SOFTWARE\Classes\Directory\Background\shell',
        'HKLM:\SOFTWARE\Classes\Drive\shell'
    )
}

$icon = '%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe'
$command = '"%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" -d "%V."'
foreach ($root in $roots) {
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -Path $root -Force | Out-Null
    }
    $key = Join-Path $root 'OpenWithTerminal'
    New-Item -Path $key -Force | Out-Null
    Set-Item -LiteralPath $key -Value 'Open in Terminal'
    New-ItemProperty -LiteralPath $key -Name 'Icon' -Value $icon -PropertyType String -Force | Out-Null
    $cmdKey = Join-Path $key 'command'
    New-Item -Path $cmdKey -Force | Out-Null
    Set-Item -LiteralPath $cmdKey -Value $command
}

exit 0
