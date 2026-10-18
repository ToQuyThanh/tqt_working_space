. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Lib.ps1')
if (Find-CodeCmd) { exit 0 }
exit 1
