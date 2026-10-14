# Capture-IconProof.ps1
# Independent proof harness: extracts icons BY INDEX from a live PE resource file and from
# shell-visible files, writes PNGs + per-index SHA256 + a labelled contact sheet.
# Read-only: never writes outside -Out.
param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$Out,
    [string[]]$Source = @('C:\Windows\System32\imageres.dll'),
    [int[]]$Index = (0..59),
    [string[]]$ShellItem = @(),
    [int]$Size = 256
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not ('IconProof' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class IconProof {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int PrivateExtractIconsW(string file, int index, int cx, int cy, IntPtr[] phicon, int[] piconid, int nIcons, int flags);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool DestroyIcon(IntPtr h);
}
'@
}

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$records = New-Object System.Collections.ArrayList

function Save-Icon([IntPtr]$hIcon, [string]$path) {
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)
    $bmp = $icon.ToBitmap()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# --- 1. direct resource extraction by index ---
foreach ($src in $Source) {
    $tag = [IO.Path]::GetFileName($src)
    foreach ($i in $Index) {
        $h = New-Object IntPtr[] 1
        $id = New-Object int[] 1
        $n = [IconProof]::PrivateExtractIconsW($src, $i, $Size, $Size, $h, $id, 1, 0)
        if ($n -gt 0 -and $h[0] -ne [IntPtr]::Zero) {
            $png = Join-Path $Out ("{0}_{1}_idx{2:D4}.png" -f $Label, ($tag -replace '[^A-Za-z0-9]', ''), $i)
            Save-Icon $h[0] $png
            [void][IconProof]::DestroyIcon($h[0])
            $sha = (Get-FileHash -LiteralPath $png -Algorithm SHA256).Hash
            [void]$records.Add([pscustomobject]@{ kind = 'resource'; source = $src; index = $i; resid = $id[0]; sha256 = $sha; png = $png })
        } else {
            [void]$records.Add([pscustomobject]@{ kind = 'resource'; source = $src; index = $i; resid = $null; sha256 = 'ABSENT'; png = $null })
        }
    }
}

# --- 2. shell-visible items (what Explorer actually paints) ---
if ($ShellItem.Count -gt 0) {
    if (-not ('ShellIcon' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ShellIcon {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct SHFILEINFOW { public IntPtr hIcon; public int iIcon; public uint dwAttributes; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string szDisplayName; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)] public string szTypeName; }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SHGetFileInfoW(string path, uint attrs, ref SHFILEINFOW info, uint cb, uint flags);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool DestroyIcon(IntPtr h);
}
'@
    }
    $SHGFI_ICON = 0x100; $SHGFI_LARGEICON = 0x0; $SHGFI_SMALLICON = 0x1; $SHGFI_USEFILEATTRIBUTES = 0x10; $SHGFI_SYSICONINDEX = 0x4000
    foreach ($item in $ShellItem) {
        $fi = New-Object ShellIcon+SHFILEINFOW
        $attrs = if (Test-Path -LiteralPath $item -PathType Container) { 0x10 } elseif (Test-Path -LiteralPath $item) { 0x80 } else { 0x80 }
        $useAttrs = if (Test-Path -LiteralPath $item) { 0 } else { $SHGFI_USEFILEATTRIBUTES }
        [void][ShellIcon]::SHGetFileInfoW($item, [uint32]$attrs, [ref]$fi, [uint32][Runtime.InteropServices.Marshal]::SizeOf($fi), [uint32]($SHGFI_ICON -bor $SHGFI_LARGEICON -bor $SHGFI_SYSICONINDEX -bor $useAttrs))
        if ($fi.hIcon -ne [IntPtr]::Zero) {
            $safe = ($item -replace '[^A-Za-z0-9]', '_')
            $png = Join-Path $Out ("{0}_shell_{1}.png" -f $Label, $safe)
            Save-Icon $fi.hIcon $png
            [void][ShellIcon]::DestroyIcon($fi.hIcon)
            $sha = (Get-FileHash -LiteralPath $png -Algorithm SHA256).Hash
            [void]$records.Add([pscustomobject]@{ kind = 'shell'; source = $item; index = $fi.iIcon; resid = $null; sha256 = $sha; png = $png })
        } else {
            [void]$records.Add([pscustomobject]@{ kind = 'shell'; source = $item; index = $null; resid = $null; sha256 = 'ABSENT'; png = $null })
        }
    }
}

# --- 3. labelled contact sheet (for visual review) ---
$cell = 96; $pad = 6; $cols = 10
$files = @($records | Where-Object { $_.png } | Select-Object -ExpandProperty png)
$rows = [math]::Ceiling($files.Count / $cols)
if ($files.Count -gt 0) {
    $w = $cols * ($cell + $pad) + $pad
    $hh = $rows * ($cell + $pad + 14) + $pad
    $sheet = New-Object System.Drawing.Bitmap($w, $hh)
    $g = [System.Drawing.Graphics]::FromImage($sheet)
    $g.Clear([System.Drawing.Color]::FromArgb(240, 240, 240))
    $font = New-Object System.Drawing.Font('Consolas', 8)
    $brush = [System.Drawing.Brushes]::Black
    $i = 0
    foreach ($f in $files) {
        $col = $i % $cols; $row = [math]::Floor($i / $cols)
        $x = $pad + $col * ($cell + $pad); $y = $pad + $row * ($cell + $pad + 14)
        try { $img = [System.Drawing.Image]::FromFile($f); $g.DrawImage($img, $x, $y, $cell, $cell); $img.Dispose() } catch { }
        $g.DrawString(([IO.Path]::GetFileNameWithoutExtension($f) -replace "^${Label}_", ''), $font, $brush, $x, ($y + $cell + 1))
        $i++
    }
    $g.Dispose()
    $sheetPath = Join-Path $Out "$Label-contact-sheet.png"
    $sheet.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $sheet.Dispose()
    "CONTACT SHEET: $sheetPath"
}

$json = Join-Path $Out "$Label-icons.json"
$records | ConvertTo-Json -Depth 4 | Set-Content $json -Encoding UTF8
"RECORDS: $($records.Count)  -> $json"
$records | Group-Object kind | ForEach-Object { "{0}: {1} ({2} absent)" -f $_.Name, $_.Count, @($_.Group | Where-Object { $_.sha256 -eq 'ABSENT' }).Count }
