<p align="center">
  <img src="icon/ArcInstaller.ico" width="120" height="120" alt="ArcInstaller icon" />
</p>
<h1 align="center">ArcInstaller</h1>
<p align="center"><strong>Get the ARC icon theme on your Windows desktop, and put the stock icons back whenever you want.</strong></p>

## Install

There is no released installer yet, so you build the app from source. You need Windows 10 or 11 (x64) with admin rights:

```powershell
git clone https://github.com/nathwn12/ArcInstaller.git
cd ArcInstaller
pwsh -File .\fetch-theme.ps1
powershell -File .\build.ps1
```

The fetch step downloads the icon packs from upstream and checks every archive against a pinned SHA-256. The build step compiles `dist\ArcInstaller.exe`. The app replaces three icon payloads in the Windows SystemResources folder with merged copies that keep every stock resource, and it backs up your originals before the first write so revert works.

## Use it

Run `dist\ArcInstaller.exe`, pick a variant in the dropdown, and press Apply. Repair re-applies the theme when a payload drifts, Revert puts your originals back, and Refresh clears the icon cache. The same actions work from a command line:

```powershell
.\dist\ArcInstaller.exe --cli -Action status
.\dist\ArcInstaller.exe --cli -Action apply -Variant dark-grey -Yes
.\dist\ArcInstaller.exe --cli -Action revert -Yes
```

Four variants ship in the one exe: ARC, Arc Neutral Brown, Arc Neutral Grey, and Arc Dark Grey. Switching variants re-merges, restores the originals, and applies in one step.

## What you get

- One window that applies, repairs, reverts, and refreshes the ARC icon theme.
- Four ARC variants in a single self-contained exe with nothing to install first.
- Merge, not swap: stock resources stay, only icon images change.
- Genuine revert: pristine originals are captured before the first write.
- Read-only checks: `--selftest` verifies the embedded payload, `verify.ps1` compares live files against recorded hashes.
- Optional auto-repair task that re-applies the theme when Windows replaces a payload.

## Requirements

- Windows 10 or 11, 64-bit, with administrator rights.
- .NET Framework 4.x (its C# compiler ships with Windows and builds the exe directly).
- PowerShell 7 for the fetch step; the build step runs under Windows PowerShell 5.1.
- Network access at build time: the icon packs download from upstream, SHA-256 verified, and are never redistributed here.

## Links

- [Source and issue tracker](https://github.com/nathwn12/ArcInstaller)
- [Repair manual](docs/REPAIR-MANUAL.md)
- [Where it lives](docs/WHERE-IT-LIVES.md)
- [Upstream icon packs](https://github.com/niivu/resource-redirect-icon-themes)
- [License (MIT)](LICENSE)

<!-- nathwn12 house footer: identical in every repo. Do not edit. -->
<p align="center">
  <a href="https://github.com/nathwn12"><img src="assets/signature.svg" width="96" alt="nathwn12" /></a>
</p>
<p align="center">
  <sub>Built by <a href="https://github.com/nathwn12">nathwn12</a> · <a href="https://github.com/nathwn12?tab=repositories">All projects</a></sub>
</p>
