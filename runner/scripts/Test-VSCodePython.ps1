. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Lib.ps1')
$code = Find-CodeCmd
if (-not $code) { exit 1 }
$listed = @(& $code --list-extensions 2>$null)
if ($listed -contains 'ms-python.python') { exit 0 }
exit 1
