# Selecting and switching a PDK

There is no universal Cadence PDK switch. `PDKS` in the launcher identifies a
directory; it does not select device models, technology attachment or digital
libraries. `OA_HOME` selects an OpenAccess software installation, not a process.
Keep the launcher's tool-specific OpenAccess handling intact.

Ask your sponsor to identify a supported process and revision, its installation
root, allowed uses, and a working reference project. A transistor PDK alone is
not a digital platform. Obtain matching standard-cell Liberty, LEF, functional
Verilog, layout views, extraction technology and verification decks. A gpdk180
analog project and an unrelated 180 nm cell library are not automatically compatible.
Separate analog and digital teaching processes are fine for separate exercises;
they do not establish an integrated mixed-signal chip flow.

| Tool or stage | What selects the process | What to check |
|---|---|---|
| Virtuoso | Project `cds.lib`, PDK startup setup, design library technology attachment, PDK device/PCell libraries | Correct tech library, layers, grid, device terminals and units |
| ADE / Spectre | Model files and sections in ADE model setup; device CDF netlisting; corner, supply, temperature | Exact device/subcircuit models, legal geometry, intended PVT |
| Genus | Liberty libraries and synthesis constraints | Matching cell family, operating voltage, units and available sequential cells |
| Conformal | Golden RTL, mapped netlist and functional cell models/setup | All cells resolved; no accidental black boxes; intended compared points |
| Innovus | Technology LEF, cell LEFs, netlist, MMMC Liberty/SDC/RC setup, site, metal stack | Consistent cell names, pins, dimensions, power nets and layer definitions |
| Tempus | Netlist, Liberty corners, SDC and corresponding SPEF/RC views | Corner coverage, hierarchy and parasitic annotation |
| PVS / Pegasus / Calibre | Process-specific DRC/LVS decks, layer maps and source netlisting setup | Exact process revision/options, top cell and power naming |
| Quantus / other extraction | Qualified extraction technology, stack/corner, layer mapping and runset | Extracted R/C, pin mapping and supported output format |
| Xcelium | RTL needs no PDK; gate simulation uses matching cell Verilog and optionally SDF | Model revision, timescale, supplies and timing annotation |
| AMS | Digital hierarchy plus analog model setup, view/config bindings and connect rules | Correct analog/digital boundaries and voltage thresholds |

## Safe switch procedure

1. Finish/save your session and close its tools. Create a fresh project directory
   in your home, e.g. `~/forge-projects/PROCESS_REV/inverter`. Use a separate
   terminal/session per process; do not source multiple PDK startup scripts together.
2. Follow the selected PDK's documented startup instructions. In the new project,
   create `cds.lib` entries pointing to that kit's libraries using its supplied
   reference project. Preserve required base libraries. Do not edit shared cds.lib
   or shared technology libraries. Some kits require a local `.cdsinit` or SKILL
   setup before their PCells work; use the kit's instructions rather than guessing.
3. In Virtuoso Library Manager, create a **new design library** and choose
   **Attach to an existing technology library**, selecting the kit's tech library.
   Menu wording varies by release. Instantiate that kit's MOS PCells. An existing
   library's technology attachment is separate from its cds.lib search entry.
4. In ADE, select Spectre and use Model Libraries / Corners (name varies with
   ADE edition) to select the kit's documented model files and sections. Set VDD,
   temperature and dimensions from the kit. Inspect the generated netlist's
   model includes and device names, then run one transistor or inverter test.
5. For digital work, copy `config/pdk.example.tcl` to `config/pdk.local.tcl` and
   fill it from the kit's reference flow. This manifest records paths; each tool
   must explicitly consume the applicable settings. The synthesis example reads
   only `liberty_slow`; the remaining entries are the handoff checklist for P&R,
   equivalence and timing. Do not assume this file reconfigures every tool.
6. Create fresh run directories for the new process. Re-synthesize and regenerate
   layout and extraction. Never reuse old mapped netlists, LEFs, SPEF, caches or
   implementation databases as if they belonged to the new process.
7. Repeat the validation checklist and record the process/revision/corners in
   the results. Switching an existing design is a port: replace devices/cells,
   resize as needed, rebuild layout and redo verification. Merely attaching a
   different technology does not translate geometry or make the circuit valid.

For MMMC, distinguish transistor PVT from interconnect RC corners. The kit's
recommended setup/hold view combinations determine coverage; labels such as
slow and fast do not prove you selected the worst cases.

Sources: [Cadence technology attachment discussion](https://community.cadence.com/cadence_technology_forums/f/custom-ic-design/35459/cadence-library-information-for-the-attached-tech-file/1346072),
[Cadence design-import example](https://community.cadence.com/cadence_blogs_8/b/di/posts/getting-started-with-edi-11-be-aware-of-these-os-and-design-import-changes-so-your-migration-goes-smoothly?pifragment-2119=905).
