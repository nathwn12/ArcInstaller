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

## Project name and description

ArcInstaller is a self-contained Windows installer for the ARC icon theme. It replaces three Windows resource payloads — `imageres.dll.mun`, `imagesp1.dll.mun` and `zipfldr.dll.mun` — with merged copies that keep every stock resource and swap in the theme's icon images, and it can put the originals back. Four variants ship in one `.exe`: ARC, Arc Neutral Brown, Arc Neutral Grey, and a locally derived Arc Dark Grey. One window: pick a variant, then apply, repair or revert. Windows-only (Windows 10/11 x64); it touches `SystemResources` and has no cross-platform path.

## Technology stack

- C# WinForms desktop app (`src/ArcInstaller.cs`, single file plus `src/app.manifest`), compiled with the .NET Framework 4.x `csc.exe` that ships with Windows — no SDK, no MSBuild, no package restore.
- PowerShell tooling: `bin/` scripts stage, merge, recolor, install and verify the theme; root entry points (`apply.ps1`, `repair.ps1`, `restore.ps1`, `verify.ps1`, `fetch-theme.ps1`, `build.ps1`) orchestrate the flow.
- No project file: there is no `.sln`, `.csproj` or `editorconfig`; the build is `build.ps1` invoking `csc` directly.

## Architecture

`build.ps1` stages the tooling and `theme/` into `staging/files`, zips them to `staging/payload.zip`, and compiles a single-file winexe with `payload.zip` embedded as a resource. At runtime the `.exe` extracts its tool tree and shells out to the PowerShell toolchain. Apply merges instead of swapping: stock resources stay and only icon images change, then the baseline security descriptors (`TrustedInstaller` ownership, Administrators read-only) are restored and Explorer is restarted so the new icons paint. Pristine payloads and their baseline descriptors are captured before the first write, which is what makes revert genuine. See [docs/REPAIR-MANUAL.md](docs/REPAIR-MANUAL.md) for the measured mechanism and [docs/WHERE-IT-LIVES.md](docs/WHERE-IT-LIVES.md) for where tooling, state and backups live after a run.

## Getting started

Prerequisites: Windows 10/11 x64 and .NET Framework 4.x (its C# compiler ships at `%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`). ArcInstaller is not distributed as a prebuilt binary — the payload embeds niivu's ARC icon packs, which are not redistributed here, so the build fetches them from upstream (SHA-256 verified) and derives Arc Dark Grey locally.

```powershell
git clone https://github.com/nathwn12/ArcInstaller.git
cd ArcInstaller
pwsh -File .\fetch-theme.ps1     # download the icon packs, verify, derive Arc Dark Grey
powershell -File .\build.ps1     # -> dist\ArcInstaller.exe (run from Windows PowerShell 5.1)
```

Run `dist\ArcInstaller.exe`, choose a variant in the dropdown and press **Apply**. **Revert** puts the pristine originals back, **Repair** re-applies when a payload has drifted, and **Refresh** clears the icon cache alone. The same actions work from a command line:

```powershell
.\ArcInstaller.exe --cli -Action status
.\ArcInstaller.exe --cli -Action apply -Variant dark-grey -Yes
.\ArcInstaller.exe --cli -Action revert -Yes
.\ArcInstaller.exe --selftest     # checks the embedded payload, touches nothing
```

## Project structure

- `src/` — the C# application (`ArcInstaller.cs`) and `app.manifest`.
- `bin/` — the PowerShell toolchain: merge, recolor, live-install, security baseline/finalize, invariants, proof capture.
- `theme/` — the fetched and derived icon packs plus `theme.ini` (populated by `fetch-theme.ps1`, not redistributed).
- `docs/` — `REPAIR-MANUAL.md`, `WHERE-IT-LIVES.md`, `arc-dark-grey-variant.md`.
- `icon/` — the app icon sources and `ArcInstaller.ico` (see `icon/NOTES.md`).
- `assets/` — the house `icon.svg` and `signature.svg`.
- `staging/` — build working tree (`staging/files`, `staging/payload.zip`).
- `dist/` — the built `ArcInstaller.exe`.
- Root `*.ps1` / `*.cmd` — user-facing entry points: `fetch-theme`, `build`, `apply`, `repair`, `restore`, `verify`, `install-autorepair`, `remove-autorepair`, `ARC-Icons`, `ArcIcons`.
- `CHANGELOG.md` — release notes (Keep a Changelog).

## Key features

- Self-contained: one `.exe` with the toolchain and all four variants embedded; nothing to install first.
- Merge, not swap: every stock resource is preserved; only icon images are replaced.
- Reversible: pristine payloads and baseline security descriptors are captured before the first write.
- Repair and refresh: re-apply when a payload drifts, or clear the icon cache after a Windows update.
- Variant-aware window: the dropdown preselects what is installed and the preview shows the themed folder glyph.
- No hardcoded paths: the install root resolves from the environment, not from a fixed drive letter.
- CLI parity: everything after `--cli` passes through to the toolchain; `--selftest` verifies without touching the system.

## Development workflow

No `AGENTS.md`, no CI workflow and no branch strategy are documented in the repo; the working branch is `main`. Changes are built and checked locally on Windows: fetch, build, self-test, verify. Keep [CHANGELOG.md](CHANGELOG.md) current in Keep a Changelog format — the `[Unreleased]` section is the scratchpad. Cut releases by adding a versioned section; there are no tags in the repo yet.

## Coding standards

There is no repo lint config (no `editorconfig`, no analyzers, no `.sln`/`.csproj` properties), so the scripts and the single C# file are the convention source: `[CmdletBinding()]` with comment-based help and `$ErrorActionPreference = 'Stop'` in PowerShell; WinForms-idiomatic C# in one file. Match the surrounding style, keep entry-point help accurate, and never invent a command, path or version — verify each against the repo before writing it.

## Testing

There is no automated test suite. The repo's checks, in order:

```powershell
.\ArcInstaller.exe --selftest        # embedded-payload check, touches nothing
powershell -File .\verify.ps1        # read-only: state.json + manifests vs live SystemResources files
```

`verify.ps1` fails on empty or missing manifests and on any `state.json` mode outside `installed|original|partial|drifted`; per-file it compares live SHA-256 against the recorded hash and the full SDDL on the live path and every surviving hardlink sibling. Apply, verify and revert are exercised on Windows 11 x64; the four-variant matrix and a clean-machine run are not yet proven end to end.

## Contributing

Small, Windows-verified pull requests against `main`: one concern per PR, CHANGELOG entry included, every command and path checked against the tree. There is no contributor contract file in the repo, so open an issue first for anything structural. Status is **Unverified** — as-is, use at your own risk.

## License

MIT — see [LICENSE](LICENSE).

The icon packs fetched by `fetch-theme.ps1` are third-party work and carry their own terms; they are not covered by this licence.

## Credits

- [niivu](https://github.com/niivu) — the ARC, Arc Neutral Brown and Arc Neutral Grey icon packs, from [resource-redirect-icon-themes](https://github.com/niivu/resource-redirect-icon-themes).
- [Ramen Software](https://ramensoftware.com/) — [Windhawk](https://windhawk.net/) and its [Resource Redirect](https://windhawk.net/mods/icon-resource-redirect) mod, which these theme packs are authored for.

This project is not affiliated with either. The icon artwork is not redistributed here: `fetch-theme.ps1` downloads it from niivu's repository at build time and verifies every archive against a pinned SHA-256. Arc Dark Grey is a local derivative of Arc Neutral Grey, generated by `bin\Recolor-IconTheme.ps1`.

<!-- nathwn12 house footer: identical in every repo. Do not edit. -->
<p align="center">
  <a href="https://github.com/nathwn12"><img src="assets/signature.svg" width="96" alt="nathwn12" /></a>
</p>
<p align="center">
  <sub>Built by <a href="https://github.com/nathwn12">nathwn12</a> · <a href="https://github.com/nathwn12?tab=repositories">All projects</a></sub>
</p>
