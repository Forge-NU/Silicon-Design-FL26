"""Build Murmann-style gm/ID lookup tables for sky130 MOSFETs with Spectre.

One device of width W_REF is swept over L x VSB x VDS x VGS (nested Spectre
sweeps) and its operating-point quantities are saved to <dev>_<corner>_<temp>.npz.
All voltages and currents are stored as magnitudes, so PMOS tables read the same
way as NMOS (VGS = |Vgs|, ID = |Id|, ...).  Use lookup.py to query them.

    python3 make_lut.py nfet_01v8 [pfet_01v8 ...] [--corner tt] [--temp 27]
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
MODELS = Path.home() / ".local/share/forge-silicon/pdks/sky130_release_0.1.0/models/sky130.lib.spice"
ENV = f"source {Path.home()}/cadence2026.sh"

W_REF = 5e-6
L = [0.15, 0.18, 0.25, 0.35, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0]  # um
VSB = [round(0.1 * i, 2) for i in range(19)]                      # 0 .. 1.8 V
VDS = [round(0.05 * i, 2) for i in range(37)]                     # 0 .. 1.8 V
VGS_STEP, VGS_MAX = 0.025, 1.8

# Spectre oppoint name -> LUT key.  cdd/css exclude the junctions (cjd/cjs).
PARAMS = {"ids": "ID", "vth": "VT", "gm": "GM", "gmbs": "GMB", "gds": "GDS",
          "cgg": "CGG", "cgs": "CGS", "cgd": "CGD", "cgb": "CGB",
          "cdd": "CDD", "css": "CSS", "cjd": "CJD", "cjs": "CJS"}


def netlist(dev: str, corner: str, temp: float) -> str:
    pol = -1 if dev.startswith("p") else 1
    ad = f"{W_REF * 0.29e-6:.4g}"          # diffusion 0.29 um long, as drawn by the PDK pcell
    pd = f"{2 * (W_REF + 0.29e-6):.4g}"
    inner = f"MX.msky130_fd_pr__{dev}"
    vals = lambda xs, u="": "[" + " ".join(f"{x}{u}" for x in xs) + "]"
    return f"""simulator lang=spectre
global 0
include "{MODELS}" section={corner}
parameters vgs=0 vds=0 vsb=0 len=0.15u
MX (d g 0 b) {dev} w={W_REF} l=len as={ad} ad={ad} ps={pd} pd={pd} m=1
VD (d 0) vsource dc={pol}*vds
VG (g 0) vsource dc={pol}*vgs
VB (b 0) vsource dc={-pol}*vsb
opts options temp={temp} gmin=1e-15
save {" ".join(f"{inner}:{p}" for p in PARAMS)}
swL sweep param=len values={vals(L, "u")} {{
  swB sweep param=vsb values={vals(VSB)} {{
    swD sweep param=vds values={vals(VDS)} {{
      dcG dc param=vgs start=0 stop={VGS_MAX} step={VGS_STEP}
    }}
  }}
}}
"""


def read_trace(path: Path, inner: str) -> dict[str, np.ndarray]:
    body = path.read_text(errors="replace").split("VALUE", 1)[1]
    out: dict[str, list[float]] = {}
    for m in re.finditer(r'"([^"]+)"\s+([-+0-9.eE]+)', body):
        k = m.group(1).replace(inner + ":", "")
        out.setdefault(k, []).append(float(m.group(2)))
    return {k: np.array(v) for k, v in out.items()}


def build(dev: str, corner: str, temp: float, outdir: Path) -> Path:
    inner = f"MX.msky130_fd_pr__{dev}"
    vgs = np.round(np.arange(0, VGS_MAX + 1e-9, VGS_STEP), 4)
    shape = (len(L), len(vgs), len(VDS), len(VSB))
    lut = {v: np.full(shape, np.nan, dtype=np.float32) for v in PARAMS.values()}
    with tempfile.TemporaryDirectory(prefix=f"lut_{dev}_", dir="/tmp") as tmp:
        d = Path(tmp)
        (d / "tb.scs").write_text(netlist(dev, corner, temp))
        cmd = (f"{ENV} >/dev/null 2>&1; cd {d} && "
               "spectre -64 tb.scs -format psfascii -raw out =log tb.log")
        subprocess.run(["bash", "-c", cmd], capture_output=True, timeout=7200)
        log = (d / "tb.log").read_text(errors="replace")
        if "completes with 0 errors" not in log:
            raise RuntimeError(f"spectre failed for {dev}:\n{log[-3000:]}")
        n = 0
        for f in (d / "out").glob("swL-*_swB-*_swD-*_dcG.dc"):
            il, ib, idd = (int(x) for x in re.findall(r"-(\d+)", f.name)[:3])
            tr = read_trace(f, inner)
            for sp, key in PARAMS.items():
                lut[key][il, :, idd, ib] = np.abs(tr[sp])
            n += 1
        if n != len(L) * len(VSB) * len(VDS):
            raise RuntimeError(f"expected {len(L) * len(VSB) * len(VDS)} sweeps, parsed {n}")
    outdir.mkdir(parents=True, exist_ok=True)
    path = outdir / f"{dev}_{corner}_{int(temp)}.npz"
    np.savez_compressed(path, L=np.array(L) * 1e-6, VGS=vgs, VDS=np.array(VDS),
                        VSB=np.array(VSB), W=W_REF, DEV=dev, CORNER=corner, TEMP=temp, **lut)
    return path


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("devices", nargs="+")
    ap.add_argument("--corner", default="tt")
    ap.add_argument("--temp", type=float, default=27)
    ap.add_argument("--out", type=Path, default=HERE / "luts")
    a = ap.parse_args()
    for dev in a.devices:
        print("wrote", build(dev, a.corner, a.temp, a.out), flush=True)
