# Co-simulation: analog mux + its digital controller

This bench runs the transistor-level differential 2:1 mux `Matt_Mux/muxDiff2to1`
together with its SystemVerilog controller `ain_mux_ctrl`, in Xcelium AMS
Designer with Spectre as the analog engine. It shows the whole interface working:

- the controller turns one channel on at a time, with a dead clock in between
  (break-before-make);
- a channel request that arrives while the S/H is busy (precharging or tracking)
  waits until the S/H holds;
- the S/H stand-in settles to within 1/2 LSB of each sensor's source voltage.

## Where the files live, and why

| File | Location | Why there |
|---|---|---|
| Controller RTL (SystemVerilog) | `digital/blocks/ain_mux_ctrl/rtl/ain_mux_ctrl.sv` | It is synthesizable logic that the digital flow (Genus, Innovus) builds with the rest of the chip's logic; `digital/blocks/<block>/` is the block layout planned for the digital team. It synthesizes with `sky130_scl_9T`: 7 flip-flops, no latches. |
| Controller filelist | `digital/blocks/ain_mux_ctrl/ain_mux_ctrl.f` | xrun, Genus and any bench read the block through this one file, so a bench never lists RTL paths itself. |
| Controller unit test (SystemVerilog + assertions) | `digital/blocks/ain_mux_ctrl/tb/` | A digital-only test lives with its block and runs without Spectre. |
| Mux netlist (exported) | `integration/netlists/Matt_Mux/muxDiff2to1.scs` | It is the analog side's hand-off to co-simulation. `analog/` holds only the Virtuoso libraries, so it goes in `integration/`, which both teams share. |
| Netlist exporter | `integration/netlists/export.sh` | Sits next to what it writes. |
| This bench | `integration/cosim/mux_diff2to1/` | Benches that need both teams' work live in `integration/cosim/<bench>/`. |

The Verilog-AMS top (`tb_mux_diff2to1.vams`) is not SystemVerilog. It has to be
Verilog-AMS because it declares analog (`electrical`) nets and instantiates
Spectre sources. xrun picks each file's language from its extension, so `.sv`
files are parsed as SystemVerilog and `.vams` files as Verilog-AMS.

Runs never write into the repo: `run.sh` makes a new folder under `~/forge-runs`.

## What the bench contains

```
 tb_mux_diff2to1.vams (Verilog-AMS top)
 ├─ ch0 source: 0.925 V / 0.875 V through 100 Ω each     (buffered T1, 50 mV differential)
 ├─ ch1 source: 0.887 V via 28.4 kΩ, 0.900 V via 50 kΩ,  (NTC bridge, −13 mV differential)
 │              100 nF to ground on each node
 ├─ U_CTRL  ain_mux_ctrl  (SystemVerilog, digital)      clk 12 MHz, ch_sel, sh_track → en0, en1, ch_ready
 ├─ XMUX    muxDiff2to1   (Spectre, transistor level)   en0/en1 cross into analog through connect modules
 └─ XSH     sh_standin    (Spectre, ideal switches)     pre: Cs to opposite rails; trk: Cs on the mux outputs
                                                         3.2 pF per side
```

The sequencer in the top takes 8 samples: ch0, ch0, ch1, ch1, ch0, then a sixth
sample on ch0 during which it requests ch1 halfway through tracking, to show
that the controller waits. The last two samples are on ch1.

The controller's `sh_track` input is driven by `sh_pre | sh_track`, the whole
S/H busy window, so the mux can never switch between precharge and track.
`ch_ready` is low whenever the connected channel differs from `ch_sel`.

Each sample:
1. waits for `ch_ready`;
2. precharges Cs to the opposite rails for 1 clock (the worst case);
3. tracks for 2 clocks (167 ns);
4. holds, reads the held differential voltage, and compares it with the sensor
   node voltage just before the sample (the settling error, as the mux brief
   defines it). The limit is 1/2 LSB = 439.5 µV.

## Demonstration, step by step

Run these on a COE Rocky 8 host (for example over VLAB), in a terminal, from
anywhere in your home.

### 0. One-time setup

- The repo is cloned at `~/Silicon-Design-FL26`.
- The SKY130 PDK is installed and your project exists at `~/forge-projects/sky130-9t`.
  `scripts/setup-sky130.py` makes both.
- Your project `cds.lib` (`~/forge-projects/sky130-9t/cds.lib`) defines `Matt_Mux`:
  ```
  DEFINE Matt_Mux /Users/Grad/<you>/Silicon-Design-FL26/analog/libs/Matt_Mux
  ```
  (`Matt_Mux` is not yet listed in the shared `analog/cds.lib`; until it is,
  each person who runs this adds the line above.)

### 1. Check and Save the mux in Virtuoso

1. Open `Matt_Mux` → `muxDiff2to1` → `schematic`.
2. Descend into `ain_tg` and `ain_tgdrv` for editing: select an instance and press **Shift+E**
   (plain `E` descends read-only). Run **Check and Save** (**Shift+X**) in each, then
   return with **Ctrl+E**.
3. In `muxDiff2to1`, run **Check and Save** (**Shift+X**) again.

The netlister refuses any cell that was saved without Check and Save. The
error is `OSSHNL-109: ... has been modified since the last extraction`.

### 2. Export the netlist

```bash
cd ~/Silicon-Design-FL26
bash integration/netlists/export.sh Matt_Mux muxDiff2to1
```

Expected:
```
Wrote integration/netlists/Matt_Mux/muxDiff2to1.scs: subckt muxDiff2to1 en0 en1 in0n in0p in1n in1p outn outp vdda vssa
```

- Virtuoso does not need to be open; the script uses the batch netlister `si`.
- `git diff integration/netlists` shows what changed since the last export.
- Re-export after every schematic change. The bench simulates this file, not the schematic.

### 3. Test the controller alone (digital only, ~10 s)

```bash
mkdir -p ~/forge-runs/ain_mux_ctrl && cd ~/forge-runs/ain_mux_ctrl
bash ~/Silicon-Design-FL26/bin/forge-eda xrun -64bit -access +r \
    -F ~/Silicon-Design-FL26/digital/blocks/ain_mux_ctrl/tb/tb.f
```

Expected last line:
```
FORGE_TB_PASS ain_mux_ctrl DEAD=1 SETTLE=2 switches=51 samples=62
```

The test makes random channel requests and S/H track pulses. Five
SystemVerilog assertions must hold the whole time:
- `en0` and `en1` are never both high;
- the enables change only while `sh_track` is low;
- a channel turns on only after at least `DEAD` clocks with both off;
- `ch_ready` implies exactly the requested channel is on;
- `ch_ready` rises only `SETTLE` clocks after the channel connected.

To test other timing parameters, add for example
`-defparam tb_ain_mux_ctrl.DEAD=3 -defparam tb_ain_mux_ctrl.dut.DEAD=3`
(and the same for `SETTLE`). DEAD 1–4 and SETTLE 0–5 all pass. The counts can
differ from the ones above if you change the seed.

### 4. Run the co-simulation (about 1 minute)

```bash
bash ~/Silicon-Design-FL26/integration/cosim/mux_diff2to1/run.sh            # tt, 27 °C
bash ~/Silicon-Design-FL26/integration/cosim/mux_diff2to1/run.sh ss 0       # any corner (tt ss ff sf fs) and °C
```

Expected (tt, 27 °C), followed by the paths of the run directory, log, connect-module report and waveforms:
```
880.0 ns: ch0 held  50.0003 mV  node  50.0000 mV  settling err    0.3 uV            (node drift from source    0.0 uV)
1963.3 ns: ch0 held  50.0003 mV  node  50.0000 mV  settling err    0.3 uV            (node drift from source    0.0 uV)
2791.8 ns: channel 1 on after 83.3 ns with both off
3380.0 ns: ch1 held -12.9413 mV  node -13.0000 mV  settling err   58.7 uV            (node drift from source    0.0 uV)
4463.4 ns: ch1 held -12.8833 mV  node -12.9420 mV  settling err   58.7 uV            (node drift from source   58.0 uV)
5291.8 ns: channel 0 on after 83.3 ns with both off
5880.0 ns: ch0 held  50.0005 mV  node  50.0000 mV  settling err    0.5 uV            (node drift from source    0.0 uV)
6791.7 ns: request ch1 while tracking (controller must defer)
6963.4 ns: ch0 held  50.0005 mV  node  50.0000 mV  settling err    0.5 uV            (node drift from source    0.0 uV)
7125.1 ns: channel 1 on after 83.3 ns with both off
8046.7 ns: ch1 held -12.8254 mV  node -12.8841 mV  settling err   58.7 uV            (node drift from source  115.9 uV)
9130.1 ns: ch1 held -12.7674 mV  node -12.8261 mV  settling err   58.7 uV            (node drift from source  173.9 uV)
FORGE_TB_PASS mux_diff2to1 checks=8 max_err=58.7 uV (tol 439.5 uV)
cosim mux_diff2to1 PASS
```

- **Break-before-make.** Each channel switch shows both enables off for one clock (83.3 ns).
- **Deferred request.** The ch1 request at 6791.7 ns, during sample 6's track, waits until the S/H holds: channel 1 turns on at 7125.1 ns.
- **ch0 error** is under 1 µV.
- **ch1 error** is 58.7 µV: Cs's precharge charge kicks the 100 nF bridge nodes during the track, and 3.2 pF × 1.8 V / 100 nF ≈ 58 µV. Well under 439.5 µV.
- **Node drift.** The "node drift" column grows by 58 µV per ch1 sample, because this bench samples every ~1 µs and the bridge nodes need milliseconds to recover. At the system's 100 Hz they recover between samples; the Spectre sign-off measured 64 µV in total.
- **Other corners** give the same picture: 57.3 µV maximum at ss 0 °C (the corner with the highest Ron) and 58.5 µV at fs 85 °C.

### 5. Look at the waveforms in SimVision

```bash
cd <the run directory that run.sh printed>
export PATH=/ECEnet/Apps1/linux/Cadence/XCELIUM2603/tools/bin:$PATH   # simvision needs this on PATH
CDS_AUTO_64BIT=ALL LM_LICENSE_FILE=5280@cadencelm.coe.neu.edu simvision waves.shm &
```

1. In the **Design Browser**, expand `tb_mux_diff2to1`.
2. Select these signals and click **Send To: Waveform**:
   - digital: `clk`, `ch_sel`, `sh_pre`, `sh_track`, `en0`, `en1`, `ch_ready`, `ch_now`;
   - analog: `outp`, `outn`, `in1p`, `in1n`, and `XSH` → `hp`, `hn`;
   - reals: `vheld`, `err`.
3. Electrical nets usually open as analog traces. If one shows as a digital bus
   instead, right-click it and choose **Format → Trace → Analog Linear**.

What to point at:
- **Break-before-make.** Zoom on a channel switch: `en0` falls, one clock passes with both low, then `en1` rises.
- **Deferred request.** At sample 6, `ch_sel` changes while `sh_track` is high, but `en0`/`en1` change only after `sh_track` falls.
- **Precharge then track.** `hp` jumps to 1.8 V and `hn` to 0 V during `sh_pre`. Both then settle onto `outp`/`outn` within a few ns of `sh_track` rising.
- **Kick.** `in1p` and `in1n` move by about 30 µV at each ch1 track and then recover through the bridge resistors. Zoom the y-axis to see it.

### 6. Check the connect modules

`run.sh` prints the path of `ams_ieinfo.log`. It should end with
`Total Number of Connect Modules : 4`, one each on:
- `en0` and `en1` into `XMUX`;
- `sh_pre` and `sh_track` into `XSH`.

Each one is a `uBidir` with `vsup : 1.8`. They are bidirectional because SPICE
subckt pins have no direction. A missing net, or a `vsup` other than 1.8,
means the `ie` line in `amscf.scs` or a pin name is wrong.

## Things to know

- **Changing the S/H load:** `cs` in `sh_standin.scs` is 3.2 pF, the CDAC MSB array per the mux brief. Abood's own S/H testbench uses 12.8 pF. Settling still passes there; the ch1 kick grows to about 230 µV.
- **Using the real S/H:** export `Abood_SampleAndHold/SH` the same way, include it in `amscf.scs` with its own `portmap`/`config` lines, and instantiate two copies in place of `XSH` (it is single-ended and tracks while its `clkb` is low).
- **Not modelled here:** the broken-T1 leakage case (T1 stuck at 1.8 V). It is covered by the Spectre sign-off in `~/forge-projects/muxDiff2to1/tb.py`.
- **Errors:**
  - `*E,CUVRSP` means a `reg` is wired straight to a SPICE pin; drive it through a `wire`, as the bench does for `sh_pre`/`sh_track`.
  - Don't add `-ams` or `-sv` to xrun. They make it parse the `.sv` RTL as Verilog-AMS.
  - `$cds_get_analog_value` must name an analog-owned node, e.g. `tb_mux_diff2to1.XSH.hp`.
