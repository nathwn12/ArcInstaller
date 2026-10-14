<p align="center">
  <img src="assets/icon.svg" width="120" height="120" alt="ArcInstaller icon" />
</p>
<h1 align="center">ArcInstaller</h1>
<p align="center"><strong>Install, repair and revert the ARC icon theme for Windows themers — C#.</strong></p>
<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/nathwn12/ArcInstaller" alt="License" /></a>
  <img src="https://img.shields.io/github/languages/top/nathwn12/ArcInstaller" alt="Language" />
  <img src="https://img.shields.io/badge/platform-windows--64bit-2b3137?logo=windows&logoColor=white" alt="Platform" />
</p>

## What it is

A self-contained Windows installer for the ARC icon theme. It replaces three
Windows resource payloads — `imageres.dll.mun`, `imagesp1.dll.mun` and
`zipfldr.dll.mun` — with merged copies that keep every stock resource and swap in
the theme's icon images, and it can put the originals back. Four variants ship in
one `.exe`: ARC, Arc Neutral Brown, Arc Neutral Grey, and Arc Dark Grey, which is
derived locally. One window: pick a variant, then apply, repair or revert.

## Why

Most Windows icon themes are applied by replacing a resource file whole. That
drops resource IDs the stock file carried and nothing else provides, which breaks
the shell surfaces that still ask for them. ArcInstaller merges instead: the stock
resources stay and only the icon images change. It also does the ownership and ACL
work `SystemResources` requires — `TrustedInstaller` owns those files and
Administrators hold read-only — so the change is genuinely reversible rather than
something to repair by hand.

## Features

- **Self-contained.** One `.exe` with the toolchain and all four variants embedded; nothing to install first.
- **Merge, not swap.** Every stock resource is preserved; only icon images are replaced.
- **Reversible.** The pristine payloads and their baseline security descriptors are captured before the first write.
- **Repair and refresh.** Re-apply when a payload drifts, or refresh the icon cache after a Windows update.
- **Variant-aware window.** The dropdown preselects what is installed and the preview shows the themed folder glyph.
- **No hardcoded paths.** The install root resolves from the environment, not from a fixed drive letter.

## Install

ArcInstaller is not distributed as a prebuilt binary: the payload embeds the ARC
icon packs, which are niivu's work and are not redistributed here, so the build
fetches them from upstream. It is one command once the prerequisites are in place
— see [Build from source](#build-from-source).

1. `git clone https://github.com/nathwn12/ArcInstaller.git`
2. `cd ArcInstaller`
3. `pwsh -File .\fetch-theme.ps1`
4. `powershell -File .\build.ps1`
5. Run `dist\ArcInstaller.exe` and pick a variant.

## Usage

Run `dist\ArcInstaller.exe`, choose a variant in the dropdown and press **Apply**.
Applying takes ownership of the three payloads, writes the merged copies, restores
the baseline security descriptors and restarts Explorer so the new icons paint.
**Revert** puts the pristine originals back, **Repair** re-applies when a payload
has drifted, and **Refresh** clears the icon cache alone.

The same actions are available from a command line. Everything after `--cli` is
passed straight through to the toolchain, so `-Action` and `-Variant` work as
documented there:

```powershell
.\ArcInstaller.exe --cli -Action status
.\ArcInstaller.exe --cli -Action apply -Variant dark-grey -Yes
.\ArcInstaller.exe --cli -Action repair -Yes
.\ArcInstaller.exe --cli -Action revert -Yes
.\ArcInstaller.exe --selftest
```

`--selftest` checks the embedded payload and exits without touching the system.

## Build from source

Prerequisites: Windows 10/11 x64 and .NET Framework 4.x, whose C# compiler ships
at `%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`. No SDK, no MSBuild,
no package restore.

```powershell
git clone https://github.com/nathwn12/ArcInstaller.git
cd ArcInstaller
pwsh -File .\fetch-theme.ps1     # download the icon packs, verify, derive Arc Dark Grey
powershell -File .\build.ps1     # -> dist\ArcInstaller.exe
```

`build.ps1` stages the tooling and `theme\` into `staging\files`, zips them to
`staging\payload.zip`, and compiles the single-file winexe with `payload.zip`
embedded as a resource. It accepts `-Root <dir>` to stage from another tree with
the same layout. Run it from Windows PowerShell 5.1: `csc` argument quoting on
PowerShell 7 mangles the `/resource:` path.

## Docs

- [docs/REPAIR-MANUAL.md](docs/REPAIR-MANUAL.md) — the measured mechanism, and why each step exists.
- [docs/WHERE-IT-LIVES.md](docs/WHERE-IT-LIVES.md) — where the tooling, state and backups live after a run.
- [docs/arc-dark-grey-variant.md](docs/arc-dark-grey-variant.md) — how the dark grey variant is derived.

## Status

**Unverified** — as-is, use at your own risk.

Apply, verify and revert are exercised on Windows 11 x64; the four-variant matrix
and a clean-machine run are not yet proven end to end.

## Credits

- [niivu](https://github.com/niivu) — the ARC, Arc Neutral Brown and Arc Neutral Grey icon packs, from [resource-redirect-icon-themes](https://github.com/niivu/resource-redirect-icon-themes).
- [Ramen Software](https://ramensoftware.com/) — [Windhawk](https://windhawk.net/) and its [Resource Redirect](https://windhawk.net/mods/icon-resource-redirect) mod, which these theme packs are authored for.

This project is not affiliated with either. The icon artwork is not redistributed
here: `fetch-theme.ps1` downloads it from niivu's repository at build time and
verifies every archive against a pinned SHA-256. Arc Dark Grey is a local
derivative of Arc Neutral Grey, generated by `bin\Recolor-IconTheme.ps1`.

## License

MIT — see [LICENSE](LICENSE).

The icon packs fetched by `fetch-theme.ps1` are third-party work and carry their
own terms; they are not covered by this licence.

<!-- nathwn12 house footer: identical in every repo. Do not edit. -->
<p align="center">
  <a href="https://github.com/nathwn12"><img src="assets/signature.svg" width="96" alt="nathwn12" /></a>
</p>
<p align="center">
  <sub>Built by <a href="https://github.com/nathwn12">nathwn12</a> · <a href="https://github.com/nathwn12?tab=repositories">All projects</a></sub>
</p>
