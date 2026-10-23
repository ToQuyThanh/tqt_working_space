# Chocolatey provisions Windows Terminal with -SkipLicense and does not install
# Microsoft.UI.Xaml.2.8. The package then looks installed, wt.exe is missing or
# dies with "No applicable app licenses found". The Windows 10 preinstall kit
# has the license and the Xaml framework.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-WtReady {
    $wt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
    if (-not (Test-Path -LiteralPath $wt)) { return $false }
    $pkg = Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue
    if (-not $pkg) { return $false }
    $out = Join-Path $env:TEMP 'tqt-wt-install-out.txt'
    $err = Join-Path $env:TEMP 'tqt-wt-install-err.txt'
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

function Get-WtArchToken {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { return 'arm64' }
    if ($env:PROCESSOR_ARCHITECTURE -eq 'X86') { return 'x86' }
    return 'x64'
}

function Install-WtFromPreinstallKit {
    $headers = @{ 'User-Agent' = 'tqt-setup' }
    $release = Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/microsoft/terminal/releases/latest'
    $asset = $release.assets | Where-Object { $_.name -like '*Windows10_PreinstallKit.zip' } | Select-Object -First 1
    if (-not $asset) {
        throw 'Khong tim thay Windows10_PreinstallKit trong release Windows Terminal'
    }
    $tempZip = Join-Path $env:TEMP $asset.name
    $stage = Join-Path $env:TEMP 'tqt-wt-preinstall'
    Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $tempZip
    try {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
        Expand-Archive -LiteralPath $tempZip -DestinationPath $stage
        $bundle = Get-ChildItem -LiteralPath $stage -Filter '*.msixbundle' | Select-Object -First 1
        $license = Get-ChildItem -LiteralPath $stage -Filter '*_License1.xml' | Select-Object -First 1
        $arch = Get-WtArchToken
        $xaml = Get-ChildItem -LiteralPath $stage -Filter ("Microsoft.UI.Xaml.2.8_*_{0}__*.appx" -f $arch) | Select-Object -First 1
        if (-not $bundle -or -not $license -or -not $xaml) {
            throw 'Preinstall kit thieu msixbundle, license, hoac Microsoft.UI.Xaml.2.8'
        }

        $userPkg = Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue
        if ($userPkg) {
            Remove-AppxPackage -Package $userPkg.PackageFullName
        }
        $provs = @(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'Microsoft.WindowsTerminal' })
        foreach ($prov in $provs) {
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName | Out-Null
        }

        Add-AppxProvisionedPackage -Online -PackagePath $bundle.FullName -LicensePath $license.FullName -DependencyPackagePath $xaml.FullName | Out-Null

        $installed = Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue
        if (-not $installed) {
            throw 'Khong dang ky duoc Windows Terminal cho user hien tai'
        }
        $wt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
        if (-not (Test-Path -LiteralPath $wt)) {
            $manifest = Join-Path $installed.InstallLocation 'AppxManifest.xml'
            Add-AppxPackage -DisableDevelopmentMode -Register -Path $manifest -ForceApplicationShutdown
        }
    } finally {
        Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    }
}

if (Test-WtReady) { exit 0 }
Install-WtFromPreinstallKit
if (-not (Test-WtReady)) {
    throw 'Windows Terminal van khong mo duoc. wt.exe thieu hoac loi license'
}
exit 0
