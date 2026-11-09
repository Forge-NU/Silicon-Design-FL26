# gm/ID lookup tables (sky130)

Murmann-style LUTs: one W = 5 µm device swept over L × VSB × VDS × VGS in Spectre,
with ID, VT, GM, GMB, GDS, CGG, CGS, CGD, CGB, CDD, CSS, CJD, CJS saved at every point.
PMOS values are stored as magnitudes, so they read the same way as NMOS values.

```bash
python3.11 -m pip install --user numpy scipy      # once
python3.11 make_lut.py nfet_01v8 pfet_01v8 nfet_01v8_lvt [--corner ss --temp 85]
```

```python
from lookup import Lut
n = Lut("nfet_01v8")
n("GM_ID", vgs=0.6, l=0.5e-6)            # value at a bias point
n("ID_W", gm_id=15, l=0.5e-6, vds=0.9)   # current density for a target gm/ID
n("GDS_W", l=0.15e-6, vgs=1.2, vds=0)    # switch conductance per metre of width
```

Grid: L = 0.15 to 4 µm (11 values), VGS = 0 to 1.8 V in 25 mV steps,
VDS = 0 to 1.8 V in 50 mV steps, and VSB = 0 to 1.8 V in 0.1 V steps.
CDD and CSS do not include the junction capacitance. For the total capacitance on a node, add CJD or CJS.
The tables do not model narrow-width or binning effects. Check any final size with a real simulation.

`size_mux.py` sizes the transmission gates of a 2:1 mux from these tables. Its docstring explains the method.
Edit `SPEC` or pass `--r_src`, `--c_load`, `--t_settle`, ... on the command line. `--verify` compares the
result with a Spectre Ron(Vin) sweep.
