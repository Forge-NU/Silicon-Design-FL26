# Forge Silicon — COE VLAB setup

Use the Rocky Linux 8 VLAB desktop and a Bash terminal. Put this repository at
`~/Silicon-Design-FL26`. Everything installs in your account; no administrator access
or shared-file changes are needed.

## 1. First-time setup

```bash
bash
cd ~/Silicon-Design-FL26

# Private graphics library for Virtuoso, Innovus and Tempus; run once.
bash scripts/bootstrap-motif.sh

# Private Xvfb; ADE Explorer will not simulate without it; run once.
bash scripts/bootstrap-xvfb.sh

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

The launcher enlarges Virtuoso's GUI (`FORGE_VIRTUOSO_SCALE`, default 1.5)
and, before starting, removes edit locks your earlier sessions left behind when
you logged off, so cellviews do not open read-only. Run
`bash scripts/clear-stale-locks.sh` in a project to clear them by hand; see
`config/site.example.sh` for both settings.

## 3. Check the tools

```bash
cd ~/Silicon-Design-FL26
bash scripts/smoke.sh
bash scripts/run-counter.sh
```

Read the reported logs. If xmsim crashes at time zero with `*F,INTERR`, run
`getsebool selinuxuser_execheap` and ask IT to enable it on that host (it fixed
Xcelium 22.03 on rocky8-04, October 2026). Startup checks do not prove that a
complete design flow works.

The most recent checkout-level verification of this repository on VLAB, with
the exact commands and results, is recorded in [docs/validation.md](docs/validation.md).

## Selected versions

The launchers select these existing COE installations under
`/ECEnet/Apps1/linux/Cadence`; they do not install EDA software.

| Component | Selected version |
|---|---|
| Virtuoso | IC25.1 (`IC251`) |
| Spectre | 25.1 (`SPECTRE251`) |
| Genus | 26.1 (`DDI261`) |
| Innovus | 26.1 (`DDI261`) |
| Tempus | 25.1 (`SSV251`, still in `cad2024/tools`) |
| Xcelium | 26.03 (`XCELIUM2603`) |
| Pegasus | 25.1 (`PEGASUS251`) |
| Quantus | 26.1 (`QUANTUS261`) |
| Conformal | 26.1 (`CONFRML261`) |
| SKY130 PDK / standard cells | 0.1.0 / base 9T 0.1.2 |

IC26.1 is installed too, but the campus license server only serves Virtuoso
features up to 25.1, so it fails license checkout. Set
`FORGE_VIRTUOSO_RELEASE=IC261` in `config/local.sh` once the server offers 26.x
features. Pegasus, Quantus and Conformal use the site's executables when on `PATH`, and
otherwise the versions above. The generated digital manifest supplies library
paths and the clock-tree and filler cells; the counter example takes it through
Genus, Innovus, Tempus and Conformal (see
[design validation](docs/design-validation.md)). That run used the earlier
Genus 21.10 / Innovus 21.1 / Xcelium 22.03 tree; rerun it on the versions above.

## Next steps

- [Run counter synthesis and configure DRC/LVS/extraction](docs/sky130-package.md).
- [Validate the inverter and digital counter](docs/design-validation.md).
- [Learn mixed-signal (AMS) co-simulation](docs/ams-cosim.md): command-line
  labs (`scripts/run-ams.sh lab1|lab2`) and a Virtuoso/ADE walkthrough.
- [Set up Git and share changes](docs/git-setup.md).

Keep the supplied PDK archives and license notices together in Git. Extracted
PDKs and design runs stay in your home outside the repository. MPW collateral is
optional and unnecessary for these exercises; omit `--with-mpw` for now.
