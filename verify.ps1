# ArcIcons verify.ps1
# Read-only check: state.json + manifests vs the live SystemResources files.
# Manifest completeness is enforced first: an empty or missing manifest is
# always FAIL, never PASS; exactly three UNIQUE allowlisted basenames are
# required. The state.json mode must be one of
# installed|original|partial|drifted; anything else is FAIL.
# Per file: live sha256 == recorded hash for the current mode; baseline owner
# + complete DACL semantics (protection flag + ACE set, via full SDDL compare
# with a semantic breakdown on mismatch) on BOTH the live path AND every
# surviving hardlink sibling; the file loads via
# LoadLibraryEx(LOAD_LIBRARY_AS_DATAFILE).
# Theme invariants (bin\Test-ResourceInvariants.ps1) run ONLY in
# mode=installed, where a missing checker is FAIL. The theme input for those
# checks is the BUILT variant's source, read from the installed manifest's
# per-file themeFile (falling back to the baseline themeFile), never from
# originals\manifest.json alone — that file always describes the ARC variant,
# so a non-ARC build would false-FAIL. In mode=original the live
# files are the pristine originals, so theme invariants are not-applicable
# (comparing stock-vs-stock would false-FAIL). mode=partial/drifted always
# FAIL with an explanatory reason (re-run / re-merge).
# Prints ARC-ICONS-VERIFY: PASS (exit 0) or FAIL (exit 1) with per-check detail.
[CmdletBinding()]
param(
  [string]$Root = (Join-Path $env:ProgramData 'ArcIcons'),
  [string]$SystemResourceDir = (Join-Path $env:SystemRoot 'SystemResources')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bin\Set-BaselineSecurity.ps1')
$DefaultRoot = Join-Path $env:ProgramData 'ArcIcons'

$RootC = Resolve-ArcIconsCanonicalPath $Root
$DefaultRootC = Resolve-ArcIconsCanonicalPath $DefaultRoot
if (($RootC -ine $DefaultRootC) -and (-not $PSBoundParameters.ContainsKey('SystemResourceDir'))) {
  Write-Output 'ARC-ICONS-VERIFY: FAIL sandbox run requires an explicit -SystemResourceDir.'
  exit 1
}
$SysC = Resolve-ArcIconsCanonicalPath $SystemResourceDir
if (-not (Test-Path -LiteralPath $SysC -PathType Container)) {
  Write-Output ("ARC-ICONS-VERIFY: FAIL SystemResourceDir not found: {0}." -f $SysC)
  exit 1
}
try {
  if (-not ([System.Management.Automation.PSTypeName]'ArcIcons.Native').Type) {
    Add-Type -Namespace ArcIcons -Name Native -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
public static extern IntPtr LoadLibraryEx(string lpFileName, IntPtr hFile, uint dwFlags);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool FreeLibrary(IntPtr hModule);
'@
  }
} catch {
  Write-Output ("ARC-ICONS-VERIFY: FAIL C# compiler unavailable (Add-Type failed: {0})." -f $_)
  exit 1
}

$failures = @()
$notes = @()

# ---- F6: manifest completeness first; empty/missing is FAIL, never PASS ----
$origManPath = Join-Path $RootC 'originals\manifest.json'
if (-not (Test-Path -LiteralPath $origManPath -PathType Leaf)) { Write-Output 'ARC-ICONS-VERIFY: FAIL originals\manifest.json not found.'; exit 1 }
try { $origMan = Read-ArcIconsJsonFile $origManPath }
catch { Write-Output ("ARC-ICONS-VERIFY: FAIL originals\manifest.json unreadable: {0}." -f $_); exit 1 }
try { Assert-ArcIconsOriginalsManifest $origMan }
catch { Write-Output ("ARC-ICONS-VERIFY: FAIL manifest completeness: {0}" -f $_); exit 1 }
$baseline = @{}
foreach ($b in $origMan.files) { $baseline[[string]$b.name] = $b }

# ---- F6: mode enum ----
$mode = 'original'
$statePath = Join-Path $RootC 'state.json'
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
  try {
    $state = Read-ArcIconsJsonFile $statePath
    if ([string]$state.mode) { $mode = [string]$state.mode }
  } catch { $failures += ("state.json unreadable: {0}." -f $_) }
} else {
  $notes += 'state.json absent; assuming mode=original.'
}
$validModes = @('installed', 'original', 'partial', 'drifted')
if ($validModes -notcontains $mode) {
  $failures += ("unknown mode '{0}' (want one of: {1})." -f $mode, ($validModes -join ', '))
}
Write-Output ("ARC-ICONS-VERIFY: mode={0} root={1} sysdir={2}" -f $mode, $RootC, $SysC)
if ($mode -eq 'partial') { $failures += 'mode=partial: the last apply/restore run did not complete; re-run it, then re-verify.' }
if ($mode -eq 'drifted') { $failures += 'mode=drifted: a live payload is unknown (e.g. Windows Update); auto-repair will not touch it — re-merge, then apply.' }

$merged = @{}
$instMan = $null
if ($mode -eq 'installed') {
  $instManPath = Join-Path $RootC 'installed-manifest.json'
  if (-not (Test-Path -LiteralPath $instManPath -PathType Leaf)) {
    $failures += 'mode=installed but installed-manifest.json not found.'
  } else {
    try {
      $instMan = Read-ArcIconsJsonFile $instManPath
      try { Assert-ArcIconsInstalledManifest $instMan }
      catch { $failures += ("installed-manifest completeness: {0}" -f $_) }
      foreach ($f in @($instMan.files)) { if ($f) { $merged[[string]$f.name] = $f } }
      $builtTheme = ''
      $builtSrc = ''
      if ($instMan.PSObject.Properties['theme']) { $builtTheme = [string]$instMan.theme }
      if ($instMan.PSObject.Properties['variantSource']) { $builtSrc = [string]$instMan.variantSource }
      Write-Output ("ARC-ICONS-VERIFY: built={0} source={1}" -f $(if ($builtTheme) { $builtTheme } else { '<unset>' }), $(if ($builtSrc) { $builtSrc } else { '<unset>' }))
    } catch { $failures += ("installed-manifest.json unreadable: {0}." -f $_) }
  }
}

$checker = Join-Path $RootC 'bin\Test-ResourceInvariants.ps1'
$checkerPresent = Test-Path -LiteralPath $checker -PathType Leaf
if (($mode -eq 'installed') -and (-not $checkerPresent)) {
  $failures += 'mode=installed but bin\Test-ResourceInvariants.ps1 is missing.'
}

foreach ($b in $origMan.files) {
  $name = [string]$b.name
  $live = Resolve-ArcIconsCanonicalPath (Join-Path $SysC $name)
  Write-Output "--- $name"
  if (-not (Test-ArcIconsPathInside $live $SysC)) { $failures += "${name}: destination escapes -SystemResourceDir."; continue }
  if (-not (Test-Path -LiteralPath $live -PathType Leaf)) { $failures += "${name}: live file missing ($live)."; Write-Output '  [hash] MISSING'; continue }

  $want = $null
  $wantKind = $null
  if ($mode -eq 'installed') {
    if ($merged[$name]) { $want = ([string]$merged[$name].mergedSha256).ToUpperInvariant(); $wantKind = 'merged' }
  } elseif ($mode -eq 'original') {
    $want = ([string]$b.originalSha256).ToUpperInvariant(); $wantKind = 'original'
  }
  try { $liveHash = Get-ArcIconsSha256 $live }
  catch { $failures += "${name}: live hash unreadable."; Write-Output '  [hash] UNREADABLE'; continue }
  if ($want) {
    if ($liveHash -eq $want) { Write-Output ("  [hash] OK {0} == {1} ({2})" -f $liveHash, $want, $wantKind) }
    else { $failures += ("{0}: live hash {1} != recorded {2} ({3}, mode={4})." -f $name, $liveHash, $want, $wantKind, $mode); Write-Output ("  [hash] MISMATCH live={0} want={1}" -f $liveHash, $want) }
  } else {
    $cls = 'unknown'
    if ($liveHash -eq ([string]$b.originalSha256).ToUpperInvariant()) { $cls = 'original' }
    elseif ($merged[$name] -and ($liveHash -eq ([string]$merged[$name].mergedSha256).ToUpperInvariant())) { $cls = 'merged' }
    Write-Output ("  [hash] INFO live={0} class={1} (mode={2}; no single expected hash)." -f $liveHash, $cls, $mode)
  }

  try {
    $baseSddl = [string]$b.sddl
    $baseOwner = [string]$b.owner
    $baseRs = New-Object System.Security.AccessControl.RawSecurityDescriptor($baseSddl)
    $baseProtected = $baseRs.AreAccessRulesProtected
    $baseSet = Get-ArcIconsAceSet $baseSddl.Substring($baseSddl.IndexOf('D:'))
  } catch { $failures += "${name}: baseline sddl does not parse."; Write-Output '  [sd] BASELINE-SDDL-UNPARSEABLE'; continue }

  $paths = @($live)
  try {
    foreach ($s in @(Get-ArcIconsHardlinkTargets $live)) {
      if (($s -ine $live) -and ($paths -notcontains $s)) { $paths += $s }
    }
  } catch { $notes += ("fsutil hardlink list failed for {0}; checking live path only." -f $name) }
  foreach ($pp in $paths) {
    $tag = 'live'
    if ($pp -ine $live) { $tag = 'sibling' }
    if (-not (Test-Path -LiteralPath $pp -PathType Leaf)) { $failures += ("{0}: [{1}] path missing ({2})." -f $name, $tag, $pp); Write-Output ("  [sd:{0}] MISSING" -f $tag); continue }
    $okSD = $false
    try { $okSD = Test-ArcIconsBaselineSecurity $pp $baseSddl }
    catch { $failures += ("{0}: [{1}] SD read failed ({2})." -f $name, $tag, $pp); Write-Output ("  [sd:{0}] UNREADABLE" -f $tag); continue }
    if ($okSD) { Write-Output ("  [sd:{0}] OK owner+group+DACL+protection == baseline" -f $tag) }
    else {
      $detail = 'diagnostic read failed.'
      try {
        $la = Get-Acl -LiteralPath $pp
        $liveFull = $la.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::Owner -bor [System.Security.AccessControl.AccessControlSections]::Group -bor [System.Security.AccessControl.AccessControlSections]::Access)
        $lr = New-Object System.Security.AccessControl.RawSecurityDescriptor($liveFull)
        $liveSet = Get-ArcIconsAceSet $liveFull.Substring($liveFull.IndexOf('D:'))
        $aceDiff = Compare-Object $liveSet $baseSet
        $diffText = '(ACE set identical)'
        if ($aceDiff) { $diffText = (($aceDiff | ForEach-Object { "$_" }) -join '; ') }
        $detail = ("owner={0} wantOwner={1}; protected={2} wantProtected={3}; aceDiff={4}" -f $la.Owner, $baseOwner, $lr.AreAccessRulesProtected, $baseProtected, $diffText)
      } catch { }
      $failures += ("{0}: [{1}] SD != baseline ({2}): {3}" -f $name, $tag, $pp, $detail)
      Write-Output ("  [sd:{0}] MISMATCH {1}" -f $tag, $detail)
    }
  }

  $h = [ArcIcons.Native]::LoadLibraryEx($live, [IntPtr]::Zero, 0x2)
  if ($h -ne [IntPtr]::Zero) { [void][ArcIcons.Native]::FreeLibrary($h); Write-Output '  [load] OK LoadLibraryEx AS_DATAFILE' }
  else { $failures += "${name}: LoadLibraryEx(LOAD_LIBRARY_AS_DATAFILE) failed."; Write-Output '  [load] FAIL' }

  if ($mode -eq 'original') {
    Write-Output '  [invariants] not-applicable in original mode (live files are the pristine originals)'
  } elseif ($mode -eq 'installed') {
    if (-not $checkerPresent) { Write-Output '  [invariants] SKIPPED (checker missing; counted as FAIL above)' }
    else {
      $origP = $null
      $themeP = $null
      # the built variant's theme source, not originals\manifest.json's ARC path
      $themeRel = [string]$b.themeFile
      if ($merged[$name] -and $merged[$name].PSObject.Properties['themeFile'] -and [string]$merged[$name].themeFile) {
        $themeRel = [string]$merged[$name].themeFile
      }
      try {
        if (-not [string]$b.originalPath) { throw 'baseline originalPath missing.' }
        if (-not $themeRel) { throw 'themeFile missing (neither installed-manifest.json nor the baseline carries one).' }
        $origP = Resolve-ArcIconsCanonicalPath (Join-Path $RootC ([string]$b.originalPath))
        $themeP = Resolve-ArcIconsCanonicalPath (Join-Path $RootC $themeRel)
        if (-not (Test-ArcIconsPathInside $origP $RootC)) { throw 'originalPath escapes -Root.' }
        if (-not (Test-ArcIconsPathInside $themeP $RootC)) { throw 'themeFile escapes -Root.' }
        if (-not (Test-Path -LiteralPath $origP -PathType Leaf)) { throw ("pristine input missing ({0})." -f $b.originalPath) }
        if (-not (Test-Path -LiteralPath $themeP -PathType Leaf)) { throw ("theme input missing ({0})." -f $themeRel) }
      } catch { $failures += ("{0}: invariant inputs: {1}" -f $name, $_); Write-Output ("  [invariants] INPUT-FAIL {0}" -f $_); continue }
      Write-Output ("  [invariants] theme={0}" -f $themeRel)
      $out = $null
      $code = -1
      try {
        $out = & $checker -Original $origP -Merged $live -Theme $themeP 2>&1
        $code = $LASTEXITCODE
      } catch { $out = "$_"; $code = -1 }
      $lines = @((($out | Out-String) -split "`n") | Where-Object { $_ -match '\S' })
      $failLines = @($lines | Where-Object { $_ -match 'FAIL' })
      if ($failLines.Count -gt 0) { $tail = (($failLines | Select-Object -First 2) -join ' | ') }
      else { $tail = (($lines | Select-Object -Last 3) -join ' | ') }
      if ($tail.Length -gt 400) { $tail = $tail.Substring(0, 400) + '...[truncated]' }
      if ($code -eq 0) { Write-Output ("  [invariants] OK {0}" -f $tail) }
      else { $failures += ("{0}: Test-ResourceInvariants exit={1} :: {2}" -f $name, $code, $tail); Write-Output ("  [invariants] FAIL exit={0} :: {1}" -f $code, $tail) }
    }
  } else {
    Write-Output ("  [invariants] not-applicable in mode={0}" -f $mode)
  }
}
foreach ($n in $notes) { Write-Output ("note: {0}" -f $n) }
if ($failures.Count -gt 0) {
  Write-Output 'ARC-ICONS-VERIFY: FAIL'
  foreach ($f in $failures) { Write-Output ("  FAIL: {0}" -f $f) }
  exit 1
}
Write-Output 'ARC-ICONS-VERIFY: PASS'
exit 0
