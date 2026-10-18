$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Lib.ps1')
$code = Find-CodeCmd
if (-not $code) {
    Start-Sleep -Seconds 5
    Update-SessionPath
    $code = Find-CodeCmd
}
if (-not $code) {
    throw 'Khong tim thay code.cmd. Mo terminal moi roi cai lai vscode-python.'
}
& $code --install-extension ms-python.python
if ($LASTEXITCODE -ne 0) {
    throw "code --install-extension that bai (exit $LASTEXITCODE)"
}
exit 0
