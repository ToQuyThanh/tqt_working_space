. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Lib.ps1')
if (Find-DBeaverExe) { exit 0 }
exit 1
