# Faculty-guided reference designs

These are staged exercises, not a tapeout qualification. New examples were
prepared locally; they have not been executed in Cadence on COE. The PDK-specific
steps require approved libraries and reference runsets. Do not substitute random
internet decks. Agree on the process, operating conditions and pass thresholds
with your sponsor before starting. Use docs/next-steps.md as the acceptance gate.

## A. First run the portable examples

In a Bash terminal on COE, after the Git setup guide:

```bash
export FORGE_REPO="$HOME/forge-silicon-eda"
cd "$FORGE_REPO"
bash scripts/smoke.sh
bash scripts/run-counter.sh
mkdir -p "$HOME/forge-projects/toy-inverter"
cd "$HOME/forge-projects/toy-inverter"
bash "$FORGE_REPO/bin/forge-eda" spectre \
  "$FORGE_REPO/examples/inverter/toy-inverter.scs" +log toy.log
```

The inverter uses generic level-1 models: it tests simulator operation only,
not a PDK, layout or realistic device performance. Inspect toy.log for completed
transient analysis and zero errors. Plot input and output in the available
waveform viewer: settled output should invert input, approximately spanning
0–1.8 V. Do not use these voltage or geometry values for an actual kit without
checking its specifications. The RTL counter needs a host with SELinux
`selinuxuser_execheap` on; if xmsim crashes before time advances, retain its log
and check that boolean before continuing.

## B. Analog inverter using the actual PDK

1. **Create the project.** Follow pdk-selection.md. Record technology library,
   model file/section, PDK revision, tool versions, nominal supply, temperature,
   supported MOS type and legal W/L. Launch Virtuoso from this project directory
   with `bash "$FORGE_REPO/bin/forge-eda" virtuoso`. Use the kit's startup hooks.
2. **Draw inverter schematic.** Create cell `inv` in your new design library,
   view schematic. Instantiate the kit's NMOS and PMOS. Connect gates to `A`,
   drains to `Y`, PMOS source/body to `VDD`, NMOS source/body to `VSS`, subject
   to the kit's well/body rules. Add four pins and check/save. Create its symbol.
   Use kit devices, not generic transistor symbols with guessed model names.
3. **Create testbench.** New cell `inv_tb`: instantiate the symbol, attach DC
   supply, input source and a known capacitive load. Use analogLib sources as
   appropriate. Set the supply to the kit's supported nominal value. Ensure VSS
   references simulator ground. Select the documented Spectre models in ADE.
4. **Schematic simulation.** First DC-sweep A from 0 to VDD; save transfer curve
   Y versus A and supply current. Then drive a pulse with finite edges, high/low
   levels 0/VDD and a period long enough to settle. Simulate several cycles.
   Save input/output, propagation delays measured at 50% VDD, rise/fall time
   using an agreed 10–90% definition and average supply current. Check for
   floating nodes, missing models and convergence warnings. Save ADE state.
5. **Choose pass limits.** Suggested initial logic check: after settling, Y
   below 0.1 VDD when A is high and above 0.9 VDD when A is low. Have your sponsor
   approve these limits, stimulus, load and required delay before using them.
   Repeat approved PVT corners; compare schematics at the same conditions.
6. **Layout.** Create layout from source using Layout XL if available, or the
   kit's supported manual flow. Place the correct PCells, wells, substrate/well
   taps and required contacts; route gates, drains, supply and ground. Create
   labeled pins on approved layers. Follow grid, spacing and enclosure rules.
   Save into your design library, never into the shared PDK library.
7. **DRC.** Choose the kit-supported checker (PVS, Pegasus or Calibre), not just
   whichever starts. Copy its reference runset into your project and set input
   library/cell/view or streamed layout, top cell and rule options. Run the full
   recommended deck, fix every violation and rerun. Record deck revision and
   final count. A preview/check-and-save is not foundry DRC.
8. **LVS.** Run against the schematic source with the kit's device recognition,
   mapping and power/ground settings. Require matched devices, connectivity,
   pins and relevant parameters, with no unintended black boxes. Resolve errors
   in the design or correct run configuration; do not edit shared decks to hide them.
9. **Extraction.** Use the kit-qualified Quantus/Calibre extraction setup. Select
   the required RC corner and coupling treatment; extract an OA view or DSPF as
   supported. Require sensible nonzero parasitics and correct pins. Save the
   extraction summary. LVS success alone does not establish RC extraction.
10. **Extracted simulation.** Duplicate the saved ADE test. Bind the inverter
    to its extracted view through a config view, or use the documented DSPF
    inclusion flow. Confirm the generated netlist actually contains/uses
    parasitics and has not silently selected schematic. Repeat the identical
    load, stimulus and PVT, tabulating schematic vs extracted delay, edge times,
    logic levels and current. Explain differences; identical traces can indicate
    an incorrect view binding. Sponsor reviews reports and waveforms.

Do not delete stale Virtuoso lock files until the owning session is confirmed
inactive. Normal GUI startup has been verified; headless startup remains limited.

## C. Digital counter through the physical flow

The provided counter has a synchronous active-low reset and enable, with a
4-bit output. It wraps modulo 16. Its self-checking testbench has 26 checks.

1. **RTL simulation:** run `scripts/run-counter.sh`; require successful exit,
   the PASS marker and inspection of the log. Review simulation coverage of
   reset, enable hold and wraparound. No PDK needed yet.
2. **Select libraries:** obtain one matched digital platform. Populate the
   ignored local manifest and verify Liberty time/capacitance units. The example
   SDC assumes ns, a 10 ns clock and illustrative I/O delays; add realistic input
   slew and output load before accepting timing. Reset is synchronous, so do
   not false-path it. Clock and reset constraints must match the intended board
   or enclosing block behavior.
3. **Synthesis:** run the template below in Genus Common UI. If the installed
   release opens legacy UI, use its documented Common UI mode or adapt the script
   with the sponsor; do not silently mix command dialects.

```bash
cd "$FORGE_REPO"
test -f config/pdk.local.tcl || cp config/pdk.example.tcl config/pdk.local.tcl
# Edit config/pdk.local.tcl before continuing.
export FORGE_PDK_CONFIG="$FORGE_REPO/config/pdk.local.tcl"
mkdir -p "$HOME/forge-projects/counter"
run=$(mktemp -d "$HOME/forge-projects/counter/synth-XXXXXXXX")
cd "$run"
bash "$FORGE_REPO/bin/forge-eda" genus -batch \
  -files "$FORGE_REPO/examples/counter/synthesize.tcl" >genus.log 2>&1
echo "Genus exit: $?"
```

Review elaboration and mapping warnings; require no unresolved modules,
unintended latches or unmapped logic. Inspect area.rpt, timing.rpt,
counter4_mapped.v and counter4_mapped.sdc. Record cell counts and verify the
constraints actually reached the design. Successful script exit alone is insufficient.

4. **Equivalence:** use the supported Conformal launcher and a kit reference
   dofile. Load functional standard-cell Verilog for both sides; read counter4.v
   as golden and counter4_mapped.v as revised; select counter4 as top, enter LEC
   mode, add compared points and compare. Cadence's minimal flow uses `read
   library`, `read design`, `set system mode lec`, `add compared point -all` and
   `compare`. Inspect design data, black boxes, unmapped points and comparison
   summary. Require all intended state/output points equivalent with no unexplained
   exclusions. Do not treat a zero shell exit status as an equivalence result.
5. **Initialize Innovus:** start in a fresh implementation directory with the
   mapped netlist/SDC, technology and cell LEFs, and the kit's MMMC view file.
   Configure its power/ground net names. Import and resolve every logical cell
   to both physical and timing views. A reference legacy import uses
   `init_lef_file`, `init_verilog`, `init_top_cell`, `init_mmmc_file`, then
   `init_design`. Populate values from your kit, not another process tutorial.
6. **Floorplan and power:** follow the kit's reference flow for site, rows, core
   margins, metal stack, legal minimum core size and pin placement. Tiny designs
   can still need a minimum core to fit power structures. Add the prescribed tap,
   endcap and power connections/rings/stripes. Verify power connectivity. Do not
   invent tap spacing or route layers from generic examples.
7. **Place, clock and route:** place/optimize, inspect congestion and setup;
   build the clock tree using allowed clock cells; inspect skew and hold; route
   and optimize. Use the kit's supported flow for fillers, antenna fixes and
   physical-only cells. Save a database after each stage. Resolve route/connectivity
   errors and review postroute setup and hold. Add approved metal fill before
   final extraction if the reference flow requires it.
8. **Physical verification:** run the kit's full DRC and LVS flow on the final
   layout and appropriate physical netlist. In-tool routing checks do not replace
   these. Require zero unwaived violations, complete connectivity and correct
   treatment of physical-only cells. Keep any faculty-approved teaching waivers
   explicit; waivers do not establish manufacturability.
9. **Extract:** produce SPEF using the supported RC extraction setup and final
   routed layout. Export the matching final netlist, constraints and, when useful,
   SDF. Check extraction coverage, units, corner and hierarchical net naming.
10. **Timing in Tempus:** load matching Liberty views, final netlist and SDC;
    read the corresponding SPEF for each analysis corner; use propagated clocks
    after CTS as prescribed by the flow. Check design linkage, clock definitions,
    timing coverage and parasitic annotation before reading slack. Require no
    unintended unconstrained endpoints, missing libraries or unexplained unannotated
    signal nets. Review setup AND hold, transition/capacitance limits, WNS/TNS and
    violating endpoints at all approved views. Ideal or special nets can have
    intentional exceptions, which must be documented. Close violations and rerun
    extraction/timing whenever the routed design changes.
11. **Final functional check:** rerun equivalence against the final logical
    netlist with approved physical-cell handling. Optionally simulate that netlist
    with functional cell models, then SDF using an appropriate sampling/testbench
    timing scheme. The RTL testbench's fixed #1 sample is not a general signoff
    gate-level timing test. Review SDF annotation and timing-check violations.

For the SKY130 base 9T project, `examples/counter/place_route.tcl` and
`timing.tcl` run steps 5–7, 9 and 10 in the synthesis build directory. They take
the clock-tree and filler cells from the project's `pdk.tcl`; Innovus CCOpt
does not infer them and stops with `IMPCCOPT-1135`. Projects generated before
these cells were added need a new project or the three `set` lines copied in.
Post-route timing also requires on-chip-variation analysis, which the script sets.

```bash
source ~/forge-projects/sky130-9t/.forge-sky130/env.sh
export FORGE_PDK_ENV=~/forge-projects/sky130-9t/.forge-sky130/env.sh
cd "$run"   # the Genus build directory from step 3
bash "$FORGE_REPO/bin/forge-eda" innovus -nowin \
  -files "$FORGE_REPO/examples/counter/place_route.tcl" -log innovus
bash "$FORGE_REPO/bin/forge-eda" tempus -no_gui \
  -files "$FORGE_REPO/examples/counter/timing.tcl" -log tempus
# Step 11: compare counter4.v with counter4_routed.v using your dofile.
bash "$FORGE_REPO/bin/forge-eda" lec -XL -nogui -dofile lec.do
```

Review connectivity.rpt, geometry.rpt, timing_postroute and the tempus_*.rpt
files. This is a teaching flow: the kit has no tap or endcap cells, and its
qualified power, routing and extraction flow, plus full Pegasus DRC/LVS (step 8),
still come from your sponsor.

## D. AMS only after both branches pass

Start with one digital stimulus signal driving the verified analog inverter and
one analog output observed by a digital checker. Use the PDK-supported simulator
config, bind analog cells to Spectre and digital cells to HDL, and select the
approved connect modules/rules for logic-to-electrical and electrical-to-logic
conversion. Set domain supply levels, thresholds, rise/fall behavior and time
resolution explicitly. Confirm both engines advance time, the intended views
are used and AMS licenses check out. Compare the analog waveform to the standalone
case and require the digital checker to recognize both logic states. If domains
have different supplies, model the required interface; do not assume compatible
voltage levels. Repeat required corners before expanding to a larger design.

## Evidence to keep

For every stage record: date, tool version, PDK/library/deck revision, PVT/RC
corner, input commit, command/runset, completed analysis, key metrics, warnings
and sponsor review. Keep raw licensed data and logs in the approved private
location. In Git, commit a redacted status table with stage, PASS/FAIL/BLOCKED,
metric, evidence location and reviewer. A blocked step is not a pass.

Reference: [Cadence Conformal example](https://community.cadence.com/cadence_technology_forums/f/logic-design/22250/checking-equivalence-of-buffer-trees/1310299).
