# Forge Silicon — COE VLAB setup

Use the Rocky Linux 8 VLAB desktop and a Bash terminal. Put this repository at
`~/forge-silicon-eda`. Everything installs in your account; no administrator access
or shared-file changes are needed.

## 1. First-time setup

```bash
bash
cd ~/forge-silicon-eda

# Private graphics library for Innovus and Tempus; run once.
bash scripts/bootstrap-motif.sh

# Extract the bundled PDK and base 9T cells; create a project.
python3 scripts/setup-sky130.py --project ~/forge-projects/sky130-9t
```

Skip the Motif step if already installed. If using the earlier audit repair,
set `FORGE_MOTIF_ROOT="$HOME/forge_repair_20260918/motif"` in `config/local.sh`
instead. If the project already contains different configuration, choose a new
project name; the setup script preserves existing files.

## 2. Open Virtuoso

```bash
bash ~/forge-projects/sky130-9t/launch.sh virtuoso
```

Create your design library attached to the SKY130 technology. In ADE, verify
`models/sky130.lib.spice` from the installed PDK, section `tt`. Use the normal
VLAB graphical session. Detailed model and verification paths are in the
project's `.forge-sky130/paths.json`.

The launcher enlarges Virtuoso's text (`FORGE_VIRTUOSO_FONT_DPI`, default 144)
and, before starting, removes edit locks your earlier sessions left behind when
you logged off, so cellviews do not open read-only. Run
`bash scripts/clear-stale-locks.sh` in a project to clear them by hand; see
`config/site.example.sh` for both settings.

## 3. Check the tools

```bash
cd ~/forge-silicon-eda
bash scripts/smoke.sh
bash scripts/run-counter.sh
```

Read the reported logs. **Xcelium 22.03 currently crashes on the audited COE
image**, so its checks may fail until IT repairs it. Startup checks do not prove
that a complete design flow works.

## Selected versions

The launchers select these existing COE installations; they do not install EDA software.

| Component | Selected version |
|---|---|
| Virtuoso | IC6.1.8 |
| Spectre | 23.1 |
| Genus | 21.10 |
| Innovus | 21.1 |
| Tempus | 25.1 |
| Xcelium | 22.03 — awaiting runtime repair |
| SKY130 PDK / standard cells | 0.1.0 / base 9T 0.1.2 |

Pegasus and Quantus use the site's configured executables. Their exact versions
and the complete SKY130 flow still need validation. The generated digital
manifest supplies library paths; it does not run place-and-route or timing automatically.

## Next steps

- [Run counter synthesis and configure DRC/LVS/extraction](docs/sky130-package.md).
- [Validate the inverter and digital counter](docs/design-validation.md).
- [Set up Git and share changes](docs/git-setup.md).

Keep the supplied PDK archives and license notices together in Git. Extracted
PDKs and design runs stay in your home outside the repository. MPW collateral is
optional and unnecessary for these exercises; omit `--with-mpw` for now.
