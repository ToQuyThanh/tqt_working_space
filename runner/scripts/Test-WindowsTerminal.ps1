$package = Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue
if ($package) { exit 0 }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $package = Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -AllUsers -ErrorAction SilentlyContinue
    if ($package) { exit 0 }
}
exit 1
