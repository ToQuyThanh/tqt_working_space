# Install Chocolatey when `choco` is not already on PATH.
$ErrorActionPreference = 'Stop'
$choco = Get-Command choco -ErrorAction SilentlyContinue
if ($choco -and $choco.Source -notlike '*\WindowsApps\*') {
    exit 0
}
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
$env:Path = "$env:Path;$env:ProgramData\chocolatey\bin"
$choco = Get-Command choco -ErrorAction SilentlyContinue
if (-not $choco) {
    throw 'Cai Chocolatey xong nhung khong thay lenh choco'
}
exit 0
