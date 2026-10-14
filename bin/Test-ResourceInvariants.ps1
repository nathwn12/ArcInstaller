# Test-ResourceInvariants.ps1 — read-only resource-byte comparison.
# CLI: -Original <pe> -Merged <pe> -Theme <pe>
# Prints one line per check + final ARC-ICONS-INVARIANT: PASS|FAIL, exit 0|1.
# Safe to point at live files (e.g. C:\Windows\SystemResources\<name>): opens
# read-only via LoadLibraryEx and always frees the module. Writes nothing.
param(
    [Parameter(Mandatory = $true)][string]$Original,
    [Parameter(Mandatory = $true)][string]$Merged,
    [Parameter(Mandatory = $true)][string]$Theme
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not ([System.Management.Automation.PSTypeName]'ArcResTest').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class ArcTestEntry {
    public bool TypeIsInt; public int TypeInt; public string TypeForm;
    public bool NameIsInt; public int NameInt; public string NameForm;
    public ushort Lang; public byte[] Data;
}

public static class ArcResTest {
    const uint AS_DATAFILE = 2u;
    const uint AS_IMAGE_RESOURCE = 0x20u;
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint fl);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool FreeLibrary(IntPtr h);
    delegate bool TProc(IntPtr h, IntPtr t, IntPtr p);
    delegate bool NProc(IntPtr h, IntPtr t, IntPtr n, IntPtr p);
    delegate bool LProc(IntPtr h, IntPtr t, IntPtr n, ushort l, IntPtr p);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool EnumResourceTypes(IntPtr h, TProc c, IntPtr p);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool EnumResourceNames(IntPtr h, IntPtr t, NProc c, IntPtr p);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool EnumResourceLanguages(IntPtr h, IntPtr t, IntPtr n, LProc c, IntPtr p);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr FindResourceEx(IntPtr h, IntPtr t, IntPtr n, ushort l);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr LoadResource(IntPtr h, IntPtr i);
    [DllImport("kernel32.dll")]
    static extern IntPtr LockResource(IntPtr d);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint SizeofResource(IntPtr h, IntPtr i);

    static bool IsInt(IntPtr p) { return (((long)p) >> 16) == 0; }
    // Resource-directory strings are COUNTED (WORD length prefix), not
    // null-terminated: PtrToStringUni over-reads into adjacent data.
    static string ExactStr(IntPtr p) {
        try {
            short len = Marshal.ReadInt16(new IntPtr(p.ToInt64() - 2));
            if (len > 0 && len <= 512) {
                char[] c = new char[len];
                for (int i = 0; i < len; i++)
                    c[i] = (char)Marshal.ReadInt16(new IntPtr(p.ToInt64() + i * 2));
                return new string(c);
            }
        } catch { }
        return Marshal.PtrToStringUni(p);
    }
    static string FormOf(IntPtr p) {
        if (IsInt(p)) return "#" + ((int)p.ToInt64()).ToString();
        return ExactStr(p);
    }

    static List<ArcTestEntry> ReadWithFlags(string path, uint flags) {
        IntPtr h = LoadLibraryEx(path, IntPtr.Zero, flags);
        if (h == IntPtr.Zero)
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "LoadLibraryEx failed: " + path);
        List<ArcTestEntry> all = new List<ArcTestEntry>();
        try {
            TProc tc = (hm, tp, lp) => {
                NProc nc = (hm2, tp2, np, lp2) => {
                    string tf = FormOf(tp2);
                    string nf = FormOf(np);
                    bool ti = IsInt(tp2);
                    bool ni = IsInt(np);
                            int tii = ti ? (int)tp2.ToInt64() : -1;
                            int nii = ni ? (int)np.ToInt64() : -1;
                            LProc lc = (hm3, tp3, np3, lang, lp3) => {
                                IntPtr hi = FindResourceEx(hm3, tp3, np3, lang);
                                if (hi != IntPtr.Zero) {
                                    IntPtr hd = LoadResource(hm3, hi);
                                    if (hd != IntPtr.Zero) {
                                        IntPtr ptr = LockResource(hd);
                                        uint sz = SizeofResource(hm3, hi);
                                        byte[] buf = new byte[sz];
                                        if (sz > 0) Marshal.Copy(ptr, buf, 0, (int)sz);
                                        ArcTestEntry e = new ArcTestEntry();
                                        e.TypeIsInt = ti; e.TypeInt = tii; e.TypeForm = tf;
                                        e.NameIsInt = ni; e.NameInt = nii; e.NameForm = nf;
                                        e.Lang = lang; e.Data = buf;
                                        all.Add(e);
                                    }
                                }
                                return true;
                            };
                            EnumResourceLanguages(hm2, tp2, np, lc, IntPtr.Zero);
                            GC.KeepAlive(lc);
                        return true;
                    };
                    EnumResourceNames(hm, tp, nc, IntPtr.Zero);
                    GC.KeepAlive(nc);
                return true;
            };
            EnumResourceTypes(h, tc, IntPtr.Zero);
            GC.KeepAlive(tc);
        }
        finally { FreeLibrary(h); }
        return all;
    }

    public static List<ArcTestEntry> ReadDataFile(string path) { return ReadWithFlags(path, AS_DATAFILE); }
    public static List<ArcTestEntry> ReadImageResource(string path) { return ReadWithFlags(path, AS_IMAGE_RESOURCE); }

    public static bool BytesEqual(byte[] a, byte[] b) {
        if (Object.ReferenceEquals(a, b)) return true;
        if (a == null || b == null) return false;
        if (a.Length != b.Length) return false;
        for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false;
        return true;
    }
}
'@
}

function Get-Groups($Entries) {
    $g = @{}
    foreach ($e in $Entries) {
        if ($e.TypeForm -ne '#14') { continue }
        if (-not $g.ContainsKey($e.NameForm)) { $g[$e.NameForm] = $e.Data }
    }
    return $g
}

$fail = $false

try { $oE = [ArcResTest]::ReadDataFile($Original) } catch { Write-Output "CHECK load-original: FAIL ($_)"; Write-Output 'ARC-ICONS-INVARIANT: FAIL'; exit 1 }
try { $mE = [ArcResTest]::ReadDataFile($Merged) } catch { Write-Output "CHECK load-merged: FAIL ($_)"; Write-Output 'ARC-ICONS-INVARIANT: FAIL'; exit 1 }
try { $tE = [ArcResTest]::ReadDataFile($Theme) } catch { Write-Output "CHECK load-theme: FAIL ($_)"; Write-Output 'ARC-ICONS-INVARIANT: FAIL'; exit 1 }

$oG = Get-Groups $oE
$mG = Get-Groups $mE
$tG = Get-Groups $tE

# (a) merged group-name set is a superset of the original group-name set
$missing = @($oG.Keys | Where-Object { -not $mG.ContainsKey($_) })
if ($missing.Count -eq 0) { Write-Output "CHECK group-names-superset: PASS (original $($oG.Count), merged $($mG.Count))" }
else { Write-Output "CHECK group-names-superset: FAIL (missing $($missing.Count): $($missing -join ','))"; $fail = $true }

# (b) every theme-provided group is byte-identical in merged
$badT = @()
foreach ($n in $tG.Keys) {
    if (-not $mG.ContainsKey($n)) { $badT += "$n(absent)"; continue }
    if (-not [ArcResTest]::BytesEqual($mG[$n], $tG[$n])) { $badT += $n }
}
if ($badT.Count -eq 0) { Write-Output "CHECK theme-groups-identical: PASS ($($tG.Count)/$($tG.Count))" }
else { Write-Output "CHECK theme-groups-identical: FAIL ($($tG.Count - $badT.Count)/$($tG.Count) match; differ: $($badT -join ','))"; $fail = $true }

# (c) every group the theme does NOT provide is byte-identical to the original
$badO = @()
foreach ($n in $oG.Keys) {
    if ($tG.ContainsKey($n)) { continue }
    if (-not [ArcResTest]::BytesEqual($mG[$n], $oG[$n])) { $badO += $n }
}
$untouched = $oG.Count - @($oG.Keys | Where-Object { $tG.ContainsKey($_) }).Count
if ($badO.Count -eq 0) { Write-Output "CHECK original-groups-preserved: PASS ($untouched untouched)" }
else { Write-Output "CHECK original-groups-preserved: FAIL (differ: $($badO -join ','))"; $fail = $true }

# (c2) all-resources-preserved: every original (type,name,lang) entry survives
# byte-identical, except type 3/14 entries whose name the theme provides, which
# must equal the theme's bytes for that (type,name).
function Get-ResKey($e) { return "$($e.TypeForm)`0$($e.NameForm)`0$($e.Lang)" }
$dictCmp = [System.StringComparer]::Ordinal
$oMap = New-Object 'System.Collections.Generic.Dictionary[string,object]' ($dictCmp)
foreach ($e in $oE) { $oMap[(Get-ResKey $e)] = $e }
$mMap = New-Object 'System.Collections.Generic.Dictionary[string,object]' ($dictCmp)
foreach ($e in $mE) { $mMap[(Get-ResKey $e)] = $e }
$themeByTN = New-Object 'System.Collections.Generic.Dictionary[string,object]' ($dictCmp)
foreach ($e in $tE) {
    if ($e.TypeForm -ne '#3' -and $e.TypeForm -ne '#14') { continue }
    $k = "$($e.TypeForm)`0$($e.NameForm)"
    if (-not $themeByTN.ContainsKey($k)) { $themeByTN[$k] = $e }
}
$missingR = @()
$diffR = @()
$themeOverR = 0
foreach ($k in $oMap.Keys) {
    $oe = $oMap[$k]
    if (($oe.TypeForm -eq '#3' -or $oe.TypeForm -eq '#14') -and $themeByTN.ContainsKey("$($oe.TypeForm)`0$($oe.NameForm)")) {
        $te = $themeByTN["$($oe.TypeForm)`0$($oe.NameForm)"]
        if (-not $mMap.ContainsKey($k)) { $missingR += "$k(absent)"; continue }
        if (-not [ArcResTest]::BytesEqual($mMap[$k].Data, $te.Data)) { $diffR += "$($oe.TypeForm):$($oe.NameForm):$($oe.Lang)" }
        else { $themeOverR++ }
        continue
    }
    if (-not $mMap.ContainsKey($k)) { $missingR += "$k(absent)"; continue }
    if (-not [ArcResTest]::BytesEqual($mMap[$k].Data, $oe.Data)) { $diffR += "$($oe.TypeForm):$($oe.NameForm):$($oe.Lang)" }
}
$badAll = @($missingR) + @($diffR)
if ($badAll.Count -eq 0) { Write-Output "CHECK all-resources-preserved: PASS (original $($oMap.Count), merged $($mMap.Count), theme-overlaid $themeOverR)" }
else {
    $show = ($badAll | Select-Object -First 20) -join ','
    $more = if ($badAll.Count -gt 20) { " (+$($badAll.Count - 20) more)" } else { '' }
    Write-Output "CHECK all-resources-preserved: FAIL (original $($oMap.Count), merged $($mMap.Count); diff $($badAll.Count): $show$more)"
    $fail = $true
}

# (d) merged loads both ways and enumerates its types
try {
    $d = [ArcResTest]::ReadDataFile($Merged)
    $types = @($d | ForEach-Object { $_.TypeForm } | Sort-Object -Unique)
    Write-Output "CHECK merged-loads-datafile: PASS (entries $($d.Count), types $($types -join ','))"
}
catch { Write-Output "CHECK merged-loads-datafile: FAIL ($_)"; $fail = $true }

try {
    $im = [ArcResTest]::ReadImageResource($Merged)
    $typesIm = @($im | ForEach-Object { $_.TypeForm } | Sort-Object -Unique)
    Write-Output "CHECK merged-loads-image-resource: PASS (entries $($im.Count), types $($typesIm -join ','))"
}
catch { Write-Output "CHECK merged-loads-image-resource: FAIL ($_)"; $fail = $true }

try {
    $all = [ArcResTest]::ReadDataFile($Merged)
    $typesAll = @($all | ForEach-Object { $_.TypeForm } | Sort-Object -Unique)
    if ($typesAll.Count -gt 0) { Write-Output "CHECK merged-enumerates-types: PASS ($($typesAll -join ','))" }
    else { Write-Output 'CHECK merged-enumerates-types: FAIL (no types)'; $fail = $true }
}
catch { Write-Output "CHECK merged-enumerates-types: FAIL ($_)"; $fail = $true }

if ($fail) { Write-Output 'ARC-ICONS-INVARIANT: FAIL'; exit 1 }
Write-Output 'ARC-ICONS-INVARIANT: PASS'
exit 0
