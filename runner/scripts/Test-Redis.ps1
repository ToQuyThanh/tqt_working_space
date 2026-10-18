$cmd = Get-Command redis-server -ErrorAction SilentlyContinue
if ($cmd -and $cmd.Source -notlike '*\WindowsApps\*') { exit 0 }
$service = Get-Service -Name 'Redis' -ErrorAction SilentlyContinue
if ($service) { exit 0 }
exit 1
