# Last resort when winget and Chocolatey did not install Windows Terminal.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{ 'User-Agent' = 'tqt-setup' }
$release = Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/microsoft/terminal/releases/latest'
$asset = $release.assets | Where-Object { $_.name -like '*.msixbundle' } | Select-Object -First 1
if (-not $asset) {
    throw 'Khong tim thay file .msixbundle trong release Windows Terminal'
}
$tempFile = Join-Path $env:TEMP $asset.name
Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $tempFile
try {
    Add-AppxPackage -Path $tempFile
} finally {
    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
}
exit 0
