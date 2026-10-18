. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Lib.ps1')
$cmd = Get-Command dsh -ErrorAction SilentlyContinue
if (-not $cmd -or $cmd.Source -like '*\WindowsApps\*') { exit 1 }
if (Test-DshInNormalPowerShell) { exit 0 }
exit 1
