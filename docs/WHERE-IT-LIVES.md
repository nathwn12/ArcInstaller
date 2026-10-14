# Where the tooling lives

`ArcInstaller.exe` is self-contained. On first run it extracts its payload to
`%ProgramData%\ArcIcons` and drives everything from there. Nothing else is
installed and no registry key is written.

| Path | Role |
|---|---|
| `%ProgramData%\ArcIcons` | The install root: the tooling, `theme\`, `originals\`, `state.json`, `installed-manifest.json` and `logs\`. |
| `%ProgramData%\ArcIcons\originals` | The pristine payloads captured before the first write, plus their baseline security descriptors. **This is what revert restores - never edit or delete it.** |
| `%ProgramData%\ArcIcons\theme` | The icon-theme variants, one directory per variant. |
| `%ProgramData%\ArcIcons\state.json` | Live install state: `installed`, `original`, `partial` or `drifted`. |
| `%ProgramData%\ArcIcons\installed-manifest.json` | Per-file record of what was merged, plus the variant's provenance. |
| `%ProgramData%\ArcIcons\logs` | The apply and restore journals. |

## The files it changes

`%SystemRoot%\SystemResources\imageres.dll.mun`, `imagesp1.dll.mun` and
`zipfldr.dll.mun`. Ownership stays `NT SERVICE\TrustedInstaller`, and the WinSxS
component-store copies are never modified. The mechanism is documented in
[REPAIR-MANUAL.md](REPAIR-MANUAL.md).

## Running the tooling directly

The extracted tooling is a normal PowerShell command line, if you would rather
not use the window:

```powershell
pwsh -File "$env:ProgramData\ArcIcons\ARC-Icons.ps1" -Action status
pwsh -File "$env:ProgramData\ArcIcons\apply.ps1" -Variant dark-grey -Yes
pwsh -File "$env:ProgramData\ArcIcons\verify.ps1"
pwsh -File "$env:ProgramData\ArcIcons\restore.ps1"
```

`apply.ps1` is THE one install command. `bin\Live-Install.ps1` and
`bin\Finalize-Security.ps1` are superseded, kept as the measured reference only -
do not run them alongside `apply.ps1`.
