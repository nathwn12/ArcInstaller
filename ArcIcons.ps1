# ArcIcons.ps1 - launcher for the ARC icon theme controller (lives in your PS1-SCRIPTS folder)
#
# Finds the real controller and runs it with the arguments you pass.
#
#   .\ArcIcons.ps1                  -> interactive menu (apply / revert / status / ...)
#   .\ArcIcons.ps1 status           -> show state + verify
#   .\ArcIcons.ps1 apply            -> apply / re-apply the ARC icons
#   .\ArcIcons.ps1 revert           -> put Windows' own icons back
#   .\ArcIcons.ps1 merge            -> re-merge after a Windows Update
#   .\ArcIcons.ps1 task-on          -> enable auto-repair at startup
#   .\ArcIcons.ps1 -Action apply -Yes -DryRun
#
# Copies are looked up in this order (first one that exists wins):
#   1. %ProgramData%\ArcIcons            <- the live copy (also used by the startup repair task)
# Override with -Controller <path to ARC-Icons.ps1>.
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]$Rest,
    [string]$Controller
)

$candidates = @(
    (Join-Path $env:ProgramData 'ArcIcons\ARC-Icons.ps1')
)
if ($Controller) { $candidates = @($Controller) }

$target = $null
foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { $target = $c; break } }
if (-not $target) {
    Write-Host 'ArcIcons: controller not found in any known location.' -ForegroundColor Red
    Write-Host ("  looked in: " + ($candidates -join ' | '))
    exit 1
}

# allow a bare action word:  .\ArcIcons.ps1 apply  ->  -Action apply
$words = 'menu', 'apply', 'revert', 'status', 'refresh', 'merge', 'task-on', 'task-off'
$args2 = @($Rest)
if ($args2.Count -gt 0 -and $words -contains [string]$args2[0]) {
    $args2 = @('-Action', [string]$args2[0]) + @($args2 | Select-Object -Skip 1)
}

Write-Host "ArcIcons -> $target" -ForegroundColor Cyan
$psExe = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if (-not $psExe) { $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' }
& $psExe -NoProfile -ExecutionPolicy Bypass -File $target @args2
