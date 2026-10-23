# Installed means the current user can launch wt. A provisioned package with a
# missing license still shows up in Get-AppxPackage and must count as missing.
$ErrorActionPreference = 'Stop'

function Test-WtReady {
    $wt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
    if (-not (Test-Path -LiteralPath $wt)) { return $false }
    $pkg = Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue
    if (-not $pkg) { return $false }
    $regPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages\$($pkg.PackageFullName)"
    $root = $null
    if (Test-Path -LiteralPath $regPath) {
        $root = (Get-ItemProperty -LiteralPath $regPath -Name PackageRootFolder -ErrorAction SilentlyContinue).PackageRootFolder
    }
    if (-not $root) { return $false }
    $out = Join-Path $env:TEMP 'tqt-wt-detect-out.txt'
    $err = Join-Path $env:TEMP 'tqt-wt-detect-err.txt'
    try {
        $proc = Start-Process -FilePath $wt -ArgumentList '--version' -Wait -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $out -RedirectStandardError $err
    } catch {
        return $false
    }
    $blob = ''
    if (Test-Path -LiteralPath $out) { $blob += [string](Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue) }
    if (Test-Path -LiteralPath $err) { $blob += [string](Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue) }
    Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
    if ($proc.ExitCode -ne 0) { return $false }
    if ($blob -match 'license') { return $false }
    return $true
}

if (Test-WtReady) { exit 0 }
exit 1
