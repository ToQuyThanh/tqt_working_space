$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Lib.ps1')
$exe = Find-DBeaverExe
if (-not $exe) {
    throw 'Khong tim thay dbeaver.exe de tao shortcut'
}
$desktop = [Environment]::GetFolderPath('Desktop')
$linkPath = Join-Path $desktop 'DBeaver.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($linkPath)
$shortcut.TargetPath = $exe
$shortcut.WorkingDirectory = Split-Path -Parent $exe
$shortcut.Description = 'DBeaver Database Tool'
$shortcut.Save()
exit 0
