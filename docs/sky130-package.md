# Cadence SKY130: bundled package and user-local setup

PDK 0.1.0, standard cells 0.1.2, die collateral 1.1 and the applicable Cadence Public License 1.0 were supplied by the
user. The unchanged archive is included under `vendor/sky130/`, alongside the
original license PDF, attribution record and Apache-2.0 license for upstream
models. Preserve these together when redistributing. The Cadence license permits
redistribution with copyright and license notices preserved. Modified vendor
files require prominent modification notices. Forge configuration is generated
separately. The extracted RCXdspfINIT symlink is materialized as a byte-identical
copy of RCXspiceINIT; the original archive remains unchanged.

Archive: `sky130_release_0.1.0.tgz`; 33,438,776 bytes.
SHA-256: `1a3846edc3552d99c289061515512116ca97f8db8fba7d365904082a54cb5bfb`

Source: user-supplied Cadence download:
https://support.cadence.com/apex/ArticleAttachmentPortal?id=a1Od000000051TqEAI&pageName=GPDKs

## Install in your COE account

Clone/update this repository in your home, then run in Bash:

```bash
cd "$HOME/Silicon-Design-FL26"
python3 scripts/setup-sky130.py
bash "$HOME/forge-projects/sky130/launch.sh" virtuoso
```

Python 3 standard library only. The script checks the archive hash, installs to
`~/.local/share/forge-silicon/pdks/sky130_release_0.1.0`, and generates the project
`~/forge-projects/sky130`. It does not edit shared files or shell startup files.
Repeat runs preserve managed installations and identical generated files; edited
project configuration is never overwritten. For another project:

```bash
python3 scripts/setup-sky130.py --project "$HOME/forge-projects/sky130-inverter"
```

Set the existing private repair paths in repo `config/local.sh` as documented in
README. Generated launchers refer to this checkout's absolute path: keep it in
place. The PDK profile is applied after COE's course setup, retaining tool-specific
Motif/OpenAccess handling. Use separate project launchers to switch processes;
existing designs are not automatically retargeted.

## Tool coverage

| Tool | Generated configuration | Remaining work |
|---|---|---|
| Virtuoso | cds.lib registers sky130_fd_pr_main and base libraries; vendor libInit loads kit settings | Attach a new design library to kit technology; validate PCells on IC6.1.8 |
| Spectre / ADE | Model path, tt corner and models.scs include | Explicitly verify ADE model selection and generated netlist; no duplicate model includes |
| Pegasus | Exact DRC/LVS paths, PDK_HOME/PDKDIR/PEGASUS_DRC, corrected techRuleSets overlay | Select decks and design inputs in supported GUI/runset workflow |
| Quantus | Typical qrcTechFile and extraction setup directory in overlay | Select technology, LVS database, top cell and output format |
| Xcelium | Project launcher for RTL, which needs no PDK | Existing runtime crash still needs repair; AMS setup is separate |
| Genus / Innovus / Tempus / Conformal | Base 9T pdk.tcl manifest contains supplied Liberty, technology/cell LEF and Verilog paths | Each flow must source the manifest; synthesis example does so. P&R, equivalence and timing need their reference flow/runsets |
| PVS / Calibre | No automatic setup | Pegasus decks are not assumed validated interchangeable decks |

For command-line tools:

```bash
bash "$HOME/forge-projects/sky130/launch.sh" spectre /absolute/path/to/test.scs
bash "$HOME/forge-projects/sky130/launch.sh" pegasus -help
bash "$HOME/forge-projects/sky130/launch.sh" qrc -help
```

Spectre does not read model environment variables automatically. Include the
generated `.forge-sky130/models.scs` once in your netlist, or select the package's
`models/sky130.lib.spice`, section `tt`, in ADE. Inspect the resulting netlist.
Pegasus/qrc executables must be exposed by the site's setup; missing launchers
produce an error. Tool help only checks startup.

All resolved paths are in `.forge-sky130/paths.json`. In Pegasus Rules/Tech&Rules,
select the recorded DRC/LVS deck and the kit configurator as needed. The generated
`.forge-sky130/techRuleSets` can be selected through the technology ruleset workflow
supported by your installed release; it is not globally auto-registered. Original
`pv/techRuleSets` references obsolete names; the overlay points to supplied DRC
`sky130_rev_0.0_2.12.drc.pvl` and LVS `sky130.lvs.v0.0_1.1.pvl`.
Configure top cell/layout/source inputs before running; do not execute example
TOPCELL controls blindly. Review the included LVS README's device/CDF caveats.

## Validation

Local tests cover package extraction and setup plumbing, not remote Cadence
execution. Bundled logs show IC23.1 use; compatibility with COE IC6.1.8 remains
unverified. Complete the inverter validation in `docs/design-validation.md`.
Digital implementation runsets, AMS view/connect-rule setup and the Xcelium repair remain
separate requirements. The script cannot supply missing process data.

The archive remains in Git history if removed later. Extracted PDKs and projects
stay outside the repository; preserve their supplied notices when sharing copies.

## Digital companion and optional MPW package

The installer now adds `sky130_scl_9T_0.1.2` beside the analog PDK and registers
base 9T and 9T technology OA libraries. LP and HS variants are archived but not
selected. Use a new project when upgrading from the earlier analog-only setup:

```bash
cd "$HOME/Silicon-Design-FL26"
python3 scripts/setup-sky130.py --project "$HOME/forge-projects/sky130-digital"
```

`sky130_scl_9T_0.1.2.tgz` SHA-256:
`c28363b936f3845fb02df8ea03b7106b17ffcf28ed6accfa3e1ea9fefd3f4c71`

`sky130_die_collateral_1.1.tgz` SHA-256:
`8464226fe231c6dfdad2a6da875cfa88451bf8e7baef4609c1eea5d03c6c21b4`

The manifest uses normal NLDM files, not backup or `dontFalse` variants:
- TT: 1.8 V, 25 C.
- SS: 1.62 V, 125 C.
- FF: 1.98 V, 0 C.
- Time unit ns; capacitance pF; placement site CoreSite; supply pins VDD/VSS.

Preserve vendor dont_use restrictions. Typical Quantus RC is supplied; the
manifest does not falsely label it RC worst/best. Required corner combinations
and timing coverage must be reviewed with the sponsor.

To run the existing counter synthesis template with the selected library:

```bash
export FORGE_PDK_ENV="$HOME/forge-projects/sky130-digital/.forge-sky130/env.sh"
mkdir -p "$HOME/forge-projects/counter-runs"
run=$(mktemp -d "$HOME/forge-projects/counter-runs/synth-XXXXXXXX")
cd "$run"
bash "$HOME/Silicon-Design-FL26/bin/forge-eda" genus -batch \
  -files "$HOME/Silicon-Design-FL26/examples/counter/synthesize.tcl" >genus.log 2>&1
```

Genus receives FORGE_PDK_CONFIG from the generated profile and the synthesis
script reads that manifest. Innovus/Tempus/Conformal do not automatically consume
it just because a variable exists: explicitly source it in their tool Tcl setup
and use the relevant paths as described in design-validation.md. No automatic
place-and-route or signoff claim is made.

For MPW collateral, create a separate project with `--with-mpw`. This adds the
supplied OA library to cds.lib. It does not place a seal ring or assign a die ID.
The package's example die ID is not yours; get submission-specific instructions
and an assigned ID from the fabrication program. It is unnecessary for block tests.

All original internal notices, including generated PGV database notices, remain
unchanged in the archives. Redistribution includes the supplied Cadence license;
no contents have been relicensed as Apache solely because some models use it.
