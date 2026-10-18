$cmd = Get-Command psql -ErrorAction SilentlyContinue
if ($cmd -and $cmd.Source -notlike '*\WindowsApps\*') { exit 0 }
$service = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue
if ($service) { exit 0 }
exit 1
