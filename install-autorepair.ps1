# ArcIcons install-autorepair.ps1
# Idempotently registers Scheduled Task `ArcIcons-Repair` (SYSTEM, startup +
# 2-minute delay) that runs repair.ps1. The task action carries the VALIDATED
# ABSOLUTE -Root (canonicalized with [IO.Path]::GetFullPath, refused when the
# directory or repair.ps1 is absent) plus the absolute live
# -SystemResourceDir, and points at the absolute repair.ps1 path — no relative
# or fallback resolution at repair time. No network requirement; hidden.
# Prints the resulting task definition.
[CmdletBinding()]
param(
  [string]$Root = (Join-Path $env:ProgramData 'ArcIcons'),
  [string]$SystemResourceDir = (Join-Path $env:SystemRoot 'SystemResources'),
  [string]$TaskName = 'ArcIcons-Repair'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bin\Set-BaselineSecurity.ps1')

$RootC = Resolve-ArcIconsCanonicalPath $Root
if (-not (Test-Path -LiteralPath $RootC -PathType Container)) {
  [Console]::Error.WriteLine(("ARC-ICONS-AUTOREPAIR: FAIL -Root not found: {0}." -f $RootC)); exit 1
}
$repair = Resolve-ArcIconsCanonicalPath (Join-Path $RootC 'repair.ps1')
if (-not (Test-ArcIconsPathInside $repair $RootC)) {
  [Console]::Error.WriteLine(("ARC-ICONS-AUTOREPAIR: FAIL repair.ps1 escapes -Root: {0}." -f $repair)); exit 1
}
if (-not (Test-Path -LiteralPath $repair -PathType Leaf)) {
  [Console]::Error.WriteLine(("ARC-ICONS-AUTOREPAIR: FAIL {0} not found." -f $repair)); exit 1
}
$sysdir = Resolve-ArcIconsCanonicalPath $SystemResourceDir

$pwsh = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" }

$action = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$repair`" -Root `"$RootC`" -SystemResourceDir `"$sysdir`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = 'PT2M'
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) { Write-Output "ARC-ICONS-AUTOREPAIR: task exists; re-registering (idempotent)." }
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'ArcIcons: re-apply merged icon theme only when the live payload is the pristine original it was built from (unknown post-update payloads are left alone).' -Force | Out-Null

$task = Get-ScheduledTask -TaskName $TaskName
$info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
Write-Output 'ARC-ICONS-AUTOREPAIR: registered.'
Write-Output ("  TaskName : {0}`n  Path     : {1}`n  State    : {2}" -f $task.TaskName, $task.TaskPath, $task.State)
foreach ($a in $task.Actions) { Write-Output ("  Action   : {0} {1}" -f $a.Execute, $a.Arguments) }
foreach ($t in $task.Triggers) { Write-Output ("  Trigger  : AtStartup Delay={0} Enabled={1}" -f $t.Delay, $t.Enabled) }
Write-Output ("  Principal: {0} LogonType={1} RunLevel={2}" -f $task.Principal.UserId, $task.Principal.LogonType, $task.Principal.RunLevel)
Write-Output ("  Settings : Hidden={0} DisallowStartIfOnBatteries={1} StopIfGoingOnBatteries={2} StartWhenAvailable={3} RunOnlyIfNetworkAvailable={4}" -f $task.Settings.Hidden, $task.Settings.DisallowStartIfOnBatteries, $task.Settings.StopIfGoingOnBatteries, $task.Settings.StartWhenAvailable, $task.Settings.RunOnlyIfNetworkAvailable)
if ($info) { Write-Output ("  LastRun  : {0} LastResult={1} NextRun={2}" -f $info.LastRunTime, $info.LastTaskResult, $info.NextRunTime) }
