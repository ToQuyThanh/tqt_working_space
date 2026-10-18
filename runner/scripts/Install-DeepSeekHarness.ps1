# npm publishes a dsh.ps1 shim. A normal PowerShell window refuses it when the
# execution policy is Restricted. This setup process itself runs with Bypass,
# so the policy has to be fixed for the user, not for this process.
$ErrorActionPreference = 'Stop'

npm install -g @deepseek-ai/dsh
if ($LASTEXITCODE -ne 0) {
    throw "npm install @deepseek-ai/dsh failed: $LASTEXITCODE"
}

function Test-PolicyAllowsLocalScripts {
    param([string]$Policy)
    return $Policy -in @('RemoteSigned', 'Unrestricted', 'Bypass')
}

$machinePolicy = [string](Get-ExecutionPolicy -Scope MachinePolicy -ErrorAction SilentlyContinue)
$userPolicy = [string](Get-ExecutionPolicy -Scope UserPolicy -ErrorAction SilentlyContinue)
$currentUser = [string](Get-ExecutionPolicy -Scope CurrentUser)
$localMachine = [string](Get-ExecutionPolicy -Scope LocalMachine)
$groupLocked = @('Restricted', 'AllSigned') -contains $machinePolicy -or @('Restricted', 'AllSigned') -contains $userPolicy

if (-not (Test-PolicyAllowsLocalScripts $currentUser) -and -not (Test-PolicyAllowsLocalScripts $localMachine) -and -not $groupLocked) {
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    } catch {
        # The setup process is Bypass, which is a more specific scope. PowerShell
        # still saves CurrentUser and then throws because this process stays on Bypass.
        $currentUser = [string](Get-ExecutionPolicy -Scope CurrentUser)
        if (-not (Test-PolicyAllowsLocalScripts $currentUser)) { throw }
    }
}

. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Lib.ps1')
if (Test-DshInNormalPowerShell) {
    exit 0
}

# Group policy can keep scripts disabled. The cmd shim still runs.
$ps1 = Join-Path $env:APPDATA 'npm\dsh.ps1'
if (Test-Path -LiteralPath $ps1) {
    Remove-Item -LiteralPath $ps1 -Force
}
if (-not (Test-DshInNormalPowerShell)) {
    throw 'dsh van khong chay duoc trong PowerShell thuong'
}
exit 0
