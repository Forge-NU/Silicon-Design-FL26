# Mixed-signal (AMS) co-simulation: a hands-on guide

This guide teaches Cadence mixed-signal co-simulation: digital Verilog and
transistor-level Spectre circuits simulated together in one run. It has three parts.

- **Part A** runs two small, finished labs from the command line, so you can see
  every file AMS needs.
- **Part B** builds Part A's inverter test in Virtuoso, menu by menu.
- **Part C** lists errors you will hit and local Cadence material for going further.

Do Part A first. The GUI does the same thing behind its forms, and once you have
seen the files the forms make sense.

Prerequisites are the README setup steps:
- Motif and Xvfb bootstraps;
- `scripts/setup-sky130.py`, which created `~/forge-projects/sky130-9t`;
- a passing `scripts/smoke.sh`.

Tool versions are the README's (IC25.1, Xcelium 26.03, Spectre 25.1). Menu names
below were checked against the IC25.1 *ADE Explorer User Guide*, Chapter 15
"Working with AMS Simulator". The local path is in Part C.

## 0. Concepts in five minutes

**AMS Designer** is the Cadence co-simulator. It is two engines in one process:
- **Xcelium** runs the digital event-driven HDL: Verilog, SystemVerilog, VHDL.
- **Spectre** solves the analog netlist: transistors, R, C, sources.

You launch it with `xrun`. Inside Virtuoso, ADE Explorer runs that same `xrun`
when the simulator is set to **ams**.

| Term | Meaning |
|---|---|
| Domain / discipline | Each net is *discrete* (logic: 0/1/X/Z, Verilog `wire`) or *continuous* (`electrical`: volts and amps). Discipline resolution works out which nets are which. |
| Connect module / interface element (IE) | A converter AMS inserts automatically wherever a logic net meets an electrical port. **L2E** turns a 0/1 into a voltage ramp with an output resistance. **E2L** turns a voltage into logic using thresholds `vthi`/`vtlo`, giving X between them. **Bidir** (`uBidir`) handles both directions. |
| Connect rules / IE card | How you set the connect modules: supply `vsup`, thresholds, rise/fall time, resistances. The command line uses an `ie` card in the AMS control file. ADE uses **Setup → Connect Rules/IE Setup**. |
| AMS control file (`amscf.scs`) | Command-line only. It is a Spectre netlist: model includes, analog cell files, the `tran` analysis, `save` statements. It also holds an `amsd { }` block that says which cells are SPICE and how to set the connect modules. |
| Config view | Virtuoso only. A Hierarchy Editor cellview that picks *which view* each cell uses, e.g. the Verilog `functional` view of the stimulus and the `schematic` of the inverter. In AMS, the choice of view decides which engine simulates the cell. |
| UNL | The *AMS Unified Netlister*, ADE's AMS netlister. It writes the files from Part A for you and runs `xrun`. |

A co-simulation is correct only when all of these hold:
1. each cell uses the intended view and engine;
2. every domain crossing has a connect module with the right supply and thresholds;
3. both engines advance time.

The IE report (`ams_ieinfo.log`) is how you check point 2. Always read it.

## Part A — command-line labs

The lab sources are in `examples/ams/`. One runner script builds a fresh run
directory under `./build`, writes the SKY130 model include from your project, and
runs `xrun`.

```bash
cd ~/Silicon-Design-FL26
bash scripts/run-ams.sh lab1      # SKY130 inverter, logic in -> analog -> logic out
bash scripts/run-ams.sh lab2      # counter4.v RTL -> 4-bit transistor R-2R DAC
```

Each run prints the log path and finishes with `AMS labN PASS`. It takes about
30 s; most of that is license checkout. If your project is somewhere other than
`~/forge-projects/sky130-9t`, set
`FORGE_PDK_ENV=<project>/.forge-sky130/env.sh` first.

### Lab 1 — one inverter, both directions (`examples/ams/lab1-inverter/`)

| File | Role |
|---|---|
| `inv.scs` | Analog cell. Spectre subckt `inv_sky130 (a y vdd vss)` with a SKY130 `pfet_01v8` (2u/150n), an `nfet_01v8` (1u/150n) and a 20 fF load. |
| `tb_inv.vams` | Verilog-AMS top. It creates the 1.8 V supply by instantiating Spectre's `vsource` directly. It drives `a` and, after each change, checks that `y` is the inverse. It also reads the real node voltage with `$cds_get_analog_value("tb_inv.XINV.y")`. |
| `amscf.scs` | Control file: includes, `tran`, `save`, and the `amsd` block. |
| `../probe.tcl` | Records all signals, analog included, to `waves.shm`. |

The important lines are in the `amsd` block:

```
amsd {
  portmap subckt=inv_sky130        // Verilog may instantiate this subckt; ports matched by name
  config  cell=inv_sky130 use=spice // ...and it is simulated by Spectre
  ie vsup=1.8 tr=100p tf=100p rlo=200 rhi=200 vthi=1.2 vtlo=0.6
}
```

The `xrun` command the runner uses is:

```bash
xrun -64bit -ams tb_inv.vams amscf.scs -top tb_inv -timescale 1ns/1ps \
     -access +r -iereport -input probe.tcl
```

The control file goes on the command line *as a source file*, as in the Cadence
samples. Passed with `-analogcontrol`, this release did not bind the subckt
(`CUVMUR`).

**What to look at after it passes**

1. In `run.log`, eight lines like `check 2: a=0 y=1 Vy=1.800 V`.
2. In `run.log`, the line `Xcelium will initiate mixed signal elaboration`.
3. In `run.log`, a Spectre section ending `spectre completes with 0 errors`.
   Together with points 1 and 2, this shows both engines ran.
4. `ams_ieinfo.log` shows **2 connect modules** (`uBidir` on `tb_inv.a` and
   `tb_inv.y`). Their parameters are the ones from the `ie` card: `vsup 1.8`,
   `vthi 1.2`, `vtlo 0.6`, `tr 1e-10`. Change the `ie` card, rerun and watch the
   values change.
5. Waveforms. `cd` into the run directory the script printed and run
   `bash ~/Silicon-Design-FL26/bin/forge-eda simvision waves.shm`. In the
   Design Browser, plot the digital `tb_inv.a` and `tb_inv.y` next to the
   analog `tb_inv.XINV.y` (drawn as an analog trace). Zoom on an edge: the
   analog edge lags the logic edge, and the E2L output switches when the
   voltage crosses `vtlo`/`vthi`.

**Exercises**

- Set `vthi=1.7 vtlo=1.6` in the `ie` card. The checker still passes, because
  it samples after settling. But the logic `tb_inv.y` now changes later on
  falling edges, and with `vthi=1.7 vtlo=0.1` it sits at X for most of each
  edge. Find those X pulses in SimVision and compare with the IE report.
- Change `CL` in `inv.scs` to 20 pF. The 4 ns wait is no longer enough to
  settle, and the run reports `FORGE_AMS_INV_FAIL`. This is the kind of bug AMS
  simulation exists to catch.

### Lab 2 — RTL counter drives a DAC (`examples/ams/lab2-dac/`)

The unmodified `examples/counter/counter4.v` drives `dac4`, a 4-bit R-2R DAC.
Each bit goes through two SKY130 inverters before the ladder. On every falling
clock edge the testbench reads `vout` and checks it against `VDD*count/16`,
allowing half an LSB (56 mV).

New ideas in this lab:
- **Buses into SPICE.** The subckt port is `d<3:0>`, written `d\<3\> ...` in
  Spectre, which is how Virtuoso netlists a bus. `portmap ... autobus=yes
  busdelim="<>"` maps Verilog's `count[3:0]` onto it. The IE report shows one
  connect module per bit (4 in total).
- **Reals in the testbench.** `vout_v`, `expected_v` and `max_err_v` are
  `real` variables, so you can plot them in SimVision next to the analog net.
- **Settling as a design check.** A passing run reports
  `max_err=12.0 mV`, and the worst case is the 15→0 wrap. The ladder's output
  resistance is R = 20 kΩ and the load is 100 fF, so τ = 2 ns. After 10 ns (5τ),
  about 0.7 % of the 1.69 V step remains. Shorten the clock period (`always #10`)
  and watch the error grow.
- **The checker can fail.** Swap `RB0`/`RB1` in `dac4.scs` and the run reports
  `FORGE_AMS_DAC_FAIL`, with ~110 mV errors on codes 1, 2, 5, 6, 9, 10. A test
  you have never seen fail proves little.

## Part B — the same thing in Virtuoso (ADE Explorer + Hierarchy Editor)

You will build Lab 1 graphically. You need three cells and a config:

```
ams_tut library
├── inv_sky130   schematic + symbol      (analog, SKY130 transistors)  -> Spectre
├── inv_stim     functional + symbol     (Verilog stimulus/checker)    -> Xcelium
└── inv_ams_tb   schematic               (testbench: stim + inverter + supply + load)
                 config                  (picks functional for inv_stim, schematic for the rest)
```

Start Virtuoso:

```bash
bash ~/forge-projects/sky130-9t/launch.sh virtuoso
```

### B1. Create the library

1. In the CIW, choose **Tools → Library Manager**.
2. In Library Manager, choose **File → New → Library**.
3. Name it `ams_tut`. When asked about technology, choose **Attach to an existing
   technology library** and pick the SKY130 tech library you used for
   `ForgeAnalog`. A pure-simulation exercise works even without a tech library,
   but layout later needs one.

### B2. The analog cell `inv_sky130`

1. Choose **File → New → Cellview**: Library `ams_tut`, Cell `inv_sky130`, Type
   **schematic**.
2. Press `i` (Create → Instance) to place:
   - `sky130_fd_pr_main` / `pfet_01v8`: Total Width `2u`, Length `150n`;
   - `sky130_fd_pr_main` / `nfet_01v8`: Total Width `1u`, Length `150n`.
3. Press `p` (Create → Pin) to add pins:
   - `a`, direction input;
   - `y`, direction output;
   - `vdd` and `vss`, direction inputOutput.

   Use pins for the supplies, not global `vdd!`. Explicit supply pins make the
   AMS boundary obvious.
4. Press `w` (Create → Wire) and wire it up:
   - both gates to `a`;
   - both drains to `y`;
   - PMOS source and bulk to `vdd`;
   - NMOS source and bulk to `vss`.
5. Choose **File → Check and Save** and fix every warning.
6. Choose **Create → Cellview → From Cellview** and accept the defaults
   (To View `symbol`) to make the symbol.

### B3. The digital cell `inv_stim` (a Verilog `functional` view)

1. In Library Manager choose **File → New → Cellview**: Library `ams_tut`, Cell
   `inv_stim`, Type **Verilog**. The view name becomes `functional`.
2. A text editor opens with a module skeleton. Replace all of it with
   `examples/ams/virtuoso/inv_stim.v` from this repo, save and close.
3. Virtuoso parses the file. When it offers to create a symbol, accept. The
   symbol gets an output pin `a` and an input pin `y`. If it reports parse
   errors, read the log it shows; a module name that differs from the cell name
   is the usual cause.

> Why `assign a = a_drv;`? Driving the port from a `reg` through a net is the
> safe idiom for any port that may touch analog. Part A's first attempt at
> connecting a `reg` straight to a SPICE port failed with `CUVRSP`.

### B4. The testbench schematic `inv_ams_tb`

1. Create cell `inv_ams_tb`, view **schematic**.
2. Place these instances:
   - `ams_tut/inv_stim` (symbol);
   - `ams_tut/inv_sky130` (symbol);
   - `analogLib/vdc` with DC voltage `1.8`;
   - `analogLib/gnd`;
   - `analogLib/cap` with `20f`.
3. Wire them:
   - `inv_stim.a` → `inv_sky130.a`;
   - `inv_sky130.y` → `inv_stim.y` and to the top of the cap;
   - vdc `+` → `inv_sky130.vdd`;
   - vdc `−`, `inv_sky130.vss` and the cap bottom → `gnd`.
4. Press `l` (Create → Wire Name) and label the nets `a`, `y` and `vdd`, so they
   are easy to find in ADE.
5. Choose **File → Check and Save**.

Nets `a` and `y` join a digital port to analog ports. Those are exactly where
connect modules will be inserted.

### B5. The config view (Hierarchy Editor)

1. In Library Manager choose **File → New → Cellview**: Library `ams_tut`, Cell
   `inv_ams_tb`, Type **config**. The Hierarchy Editor and its New Configuration
   form open. (In the Hierarchy Editor itself this is **File → New Config**.)
2. Set the top cell to Library `ams_tut`, Cell `inv_ams_tb`, View `schematic`.
3. Click **Use Template**, select **AMS** from the Name list and click **OK**.
4. Check the **View List**. The installed template uses `spectre spice pspice
   verilog verilogams behavioral functional systemVerilog schematic veriloga
   vhdl vhdlams wreal` with **Stop List** `spectre`. The user guide prints a
   shorter list; trust what the form shows.
   - Both lists are tried left to right. `inv_stim` has no `spectre` or
     `verilog` view, so it resolves to `functional`.
   - `inv_sky130` resolves to `schematic` and is expanded down to the PDK
     transistors, which stop at their `spectre` views.
5. Click **OK**. In the main window choose **View → Update** and then
   **File → Save**.
6. Read the **Cell Bindings** table. The *View Found* column should show:
   - `inv_stim` → `functional`;
   - `inv_sky130` → `schematic`;
   - `analogLib` cells → `spectre`.

   If a row shows the wrong view, right-click it and set **View to use**, or
   reorder the View List. This table is the most common source of "my Verilog
   was ignored" problems.

A quicker alternative from the testbench schematic is **Launch → Plugins → Mixed
Signal Options → Configuration → Auto Create Configuration**, which makes
`auto_config`. Build one by hand first so you understand what it does.

### B6. Open the design through the config and start ADE Explorer

1. Open `ams_tut / inv_ams_tb / config`. When asked, open **both** the
   configuration and the top cellview, so the schematic opens *through* the
   config. The title bar shows the config.
2. In the schematic window choose **Launch → ADE Explorer** and create a new view.
   The design shown in ADE must be `inv_ams_tb` **config**, not schematic.

### B7. Set up the AMS simulation in ADE Explorer

Work through these forms in order:

1. **Setup → Simulator**: choose `ams`.
2. **Setup → Model Libraries**: add
   `~/.local/share/forge-silicon/pdks/sky130_release_0.1.0/models/sky130.lib.spice`
   with Section `tt`. The exact path is `FORGE_SKY130_MODEL` in
   `~/forge-projects/sky130-9t/.forge-sky130/paths.json`.
3. **Simulation → Netlist and Run Options**: Netlist and Run Mode is
   **AMS Unified Netlister with xrun**, the default. Keep Run Options at
   Compile / Elaborate / Simulate.
4. **Setup → Connect Rules/IE Setup** opens the *Interface Element (IE) Setup*
   form. Make one global IE card:
   - Enable on;
   - Scope `global`;
   - Supply Type `Value`;
   - Supply Value `1.8`.

   The default rule is `CR_full_fast`, which already has `vsup` 1.8 V, so this
   card mostly makes the choice explicit. Under **Advanced Setup**, the Basic
   and Extended tabs hold `tr`, `vthi`, `vtlo`, etc., matching Lab 1's `ie` card
   (vthi 1.2, vtlo 0.6). Turn on **Enable IE Report**.

   The other choice on this form, *Connect Rule/Connect Module Based Setup*,
   picks whole prebuilt rules such as `ConnRules_18V_full_fast`. It is the older
   style; use IE cards unless your PDK or kit says otherwise.
5. **Analyses → Choose**: `tran`, stop time `40n`.
6. **Outputs → To Be Plotted → Select On Design**: click nets `a` and `y` in the
   schematic.
7. Optional: **Simulation → Options → AMS Simulator** for digital and AMS options
   such as timescale and xrun arguments. **Simulation → Options → Analog** sets
   the Spectre accuracy options.
8. Choose **Session → Save State**, so the setup can be reloaded.

### B8. Run and check

1. Click **Run** (the green arrow). The first run compiles, elaborates and
   simulates; read the run log if anything fails.
2. Plots open with `a` and `y`. The digital `a` is drawn as logic, while `y` is
   analog. The analog `y` should fall about 100 ps after each rising `a`.
3. **Simulation → Output Log** shows the simulator log. Find:
   - `inv_stim: PASS checks=8`;
   - the mixed-signal elaboration notice;
   - Spectre's `completes with 0 errors`.
4. **Simulation → Output Log → IE Report** lists the inserted connect modules.
   You should see one on net `a` and one on net `y`, with `vsup` 1.8.
5. Compare with Part A: the voltages and checker result should match Lab 1.

Then try these:
- Change the IE card's `vsup` to 3.3 and rerun. The checker now reads 1.8 V as
  below `vthi` (2.2 V) and fails.
- Look in the netlist directory (shown in the run log) at the files UNL
  generated. You will recognise the Part A pieces: a Verilog-AMS or Spectre
  netlist, an `amscf`-like control file with the `ie` card, and the
  `xrun` argument file.

### B9. Next step: Lab 2 in the GUI (on your own)

1. Create cell `counter4`, Type Verilog, and paste `examples/counter/counter4.v`.
2. Draw `dac4` as a schematic from `examples/ams/lab2-dac/dac4.scs`:
   - eight inverters (reuse `inv_sky130` with 4u/2u devices, or a second cell);
   - `analogLib/res` resistors, R = 20k and 2R = 40k.

   Name the input pin bus `d<3:0>`.
3. In the testbench, connect `counter4`'s `count<3:0>` to `dac4`'s `d<3:0>`. Add
   a `analogLib/vpulse` clock (0/1.8 V, 20 ns period) on `clk`, plus constant
   sources for `rst_n` and `en`. Alternatively, write a small Verilog testbench
   cell that drives them.

You will find that the clock source is analog driving a digital port, so an E2L
connect module appears in the IE report. The bus gets one connect module per
bit, just as on the command line.

## Part C — troubleshooting and further learning

### Errors seen while building these labs (Xcelium 26.03)

| Message | Cause | Fix |
|---|---|---|
| `*E,CUVMUR ... design unit 'inv_sky130' is unresolved` | The SPICE subckt is not visible to the elaborator. | Pass `amscf.scs` as a source file, not with `-analogcontrol`. Check `include` and `portmap`/`config ... use=spice`. In ADE, check the config's View Found column. |
| `*E,CUVRSP Illegal connection of variable to inout port of SPICE instance` | A `reg` connects directly to a SPICE port; SPICE ports are inout. | Drive a `wire` from the reg (`wire a = a_drv;`). |
| `*E,NOTSYT Unrecognized system task` on `$fatal` | `.vams` files compile as Verilog-2001-AMS, not SystemVerilog. | Use `$display` with an error counter, or move the checker to an `.sv` file. |
| `*SE,HIERNAMENFND (VALUEFETCH-004) $cds_get_analog_value() failed` | The path names the *digital* side of a connect module. | Use the analog-owned node, e.g. `tb_inv.XINV.y` rather than `tb_inv.y`. |
| `SPECTRE-8281 ... will not be saved because it is only partially correct` | Same cause, in a `save` statement. | Save the analog-side name. |
| `*W,IELACK: The design does not contain any interface elements` | No domain crossing was found. It appears after any elaboration error, or when everything resolved to one domain. | Fix earlier errors first. If it remains, check that the views and engines are the ones you intended. |
| Spectre `Found trapezoidal ringing` notices | The integrator saw ringing on internal transistor nodes and switched method. | Harmless here; worth investigating if results look wrong. |
| Checker sees `x` on a logic net driven by analog | The voltage sits between `vtlo` and `vthi` when sampled. | Wait longer, fix the slow edge, or correct the thresholds/`vsup` for that domain. |
| ADE silently simulates the schematic of a cell you meant to be Verilog | The config View List picked another view first. | Change it in Hierarchy Editor; check **View Found**. |
| ADE run fails immediately (EXPLORER-9512) | Xvfb missing. | `bash scripts/bootstrap-xvfb.sh`, then relaunch. |

### Local material to learn from (already installed on VLAB)

Open the HTML files with `firefox <path> &`.

**Read first**
- ADE Explorer User Guide, Ch. 15 "Working with AMS Simulator": config creation,
  IE setup, netlist/run options and IE reports.
  `/ECEnet/Apps1/linux/Cadence/IC251/doc/Explorer/chap15.html`
  (PDF: `/ECEnet/Apps1/linux/Cadence/IC251/doc/Explorer/Explorer.pdf`)
- AMS in ADE FAQ:
  `/ECEnet/Apps1/linux/Cadence/IC251/doc/AMSinADEFAQ/AMSinADEFAQTOC.html`
- Welcome to AMS in ADE:
  `/ECEnet/Apps1/linux/Cadence/IC251/doc/WelcometoAMSinADE/WelcometoAMSinADETOC.html`

**Reference**
- Spectre AMS Designer and Xcelium Mixed-Signal User Guide:
  `/ECEnet/Apps1/linux/Cadence/XCELIUM2603/doc/ams_dms_simug/ams_dms_simugTOC.html`.
  Useful pages: `amsd_Block.html`, `Automatically-Inserted_Connect_Modules.html`,
  `ie_with_Universal_Connect_Module.html`, `Examples_Using_xrun_for_AMS_Simulation.html`.
- Hierarchy Editor User Guide:
  `/ECEnet/Apps1/linux/Cadence/IC251/doc/cdshiereditor/cdshiereditorTOC.html`
- Verilog-AMS Language Reference:
  `/ECEnet/Apps1/linux/Cadence/XCELIUM2603/doc/verilogamsref/verilogamsrefTOC.html`
- Built-in connect rules and their sources, including `ConnRules18.vams` and the
  `CR_*` files with `vsup`/`vthi`/`vtlo` defaults, plus a `README`:
  `/ECEnet/Apps1/linux/Cadence/XCELIUM2603/tools/affirma_ams/etc/connect_lib/`

**Workshops with databases** — copy them into your home before unpacking:
- `/ECEnet/Apps1/linux/Cadence/IC251/tools/dfII/samples/tutorials/AMS/AMSDInADE.tar.gz`.
  A complete AMS-in-ADE workshop: a 160 MHz PLL with Verilog dividers, configs,
  saved ADE states and answer cells. It uses gpdk090, not SKY130. The
  instructions are in `AVUM_workshop.pdf` in the same directory (2009, so its
  screenshots show ADE L, but the concepts still apply). The other tarballs
  there cover multiple supplies, migration and `runams`.
- `/ECEnet/Apps1/linux/Cadence/XCELIUM2603/tools/amsd/samples/aium/`. Command-line
  AMS Designer labs, with instructions in `aium_workshop.pdf`. `build_up` and
  `multipower` (IE cards for 1.8 V and 3.3 V domains) follow on directly from
  Part A.

Example of unpacking one:

```bash
mkdir -p ~/ams-workshops && cd ~/ams-workshops
tar xzf /ECEnet/Apps1/linux/Cadence/IC251/tools/dfII/samples/tutorials/AMS/AMSDInADE.tar.gz
cp -r /ECEnet/Apps1/linux/Cadence/XCELIUM2603/tools/amsd/samples/aium ./aium
```

Run the workshop scripts with this repo's launcher (`bin/forge-eda xrun` or
`virtuoso`) rather than the scripts' bare `irun`, which this site does not
provide.
