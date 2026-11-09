"""Query gm/ID lookup tables made by make_lut.py (Murmann's `look_up`, in Python).

    from lookup import Lut
    n = Lut("nfet_01v8")                       # luts/nfet_01v8_tt_27.npz
    n("GM_ID", vgs=0.6, l=0.5e-6)              # plain or ratio quantity at a bias point
    n("ID_W", gm_id=15, l=0.5e-6, vds=0.9)     # ratio vs another ratio (gm/ID design)

Any argument left out takes its default: vds = VDD/2, vsb = 0, l = shortest L.
Ratios are "A_B" for any two stored keys (ID, VT, GM, GMB, GDS, CGG, CGS, CGD,
CGB, CDD, CSS, CJD, CJS) plus W, e.g. GM_ID, ID_W, GDS_W, CGG_W, GM_CGG.
Absolute quantities refer to the table width W (lut.w); scale by your W/lut.w.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from scipy.interpolate import RegularGridInterpolator

HERE = Path(__file__).resolve().parent


class Lut:
    def __init__(self, dev: str, corner: str = "tt", temp: int = 27, path: Path | None = None):
        z = np.load(path or HERE / "luts" / f"{dev}_{corner}_{temp}.npz")
        self.dev, self.corner, self.temp = dev, corner, temp
        self.w = float(z["W"])
        self.L, self.VGS, self.VDS, self.VSB = (z[k].astype(float) for k in ("L", "VGS", "VDS", "VSB"))
        self.data = {k: z[k].astype(float) for k in z.files
                     if k not in ("L", "VGS", "VDS", "VSB", "W", "DEV", "CORNER", "TEMP")}
        self._interp: dict[str, RegularGridInterpolator] = {}

    def _grid(self, key: str) -> np.ndarray:
        if key == "W":
            return np.full_like(self.data["ID"], self.w)
        if "_" in key:
            a, b = key.split("_", 1)
            with np.errstate(divide="ignore", invalid="ignore"):
                return self._grid(a) / self._grid(b)
        return self.data[key]

    def raw(self, key: str, l=None, vgs=None, vds=0.9, vsb=0.0) -> np.ndarray:
        """`key` at the given bias; vgs=None returns the whole VGS sweep."""
        key = key.upper()
        if key not in self._interp:
            self._interp[key] = RegularGridInterpolator(
                (self.L, self.VGS, self.VDS, self.VSB), self._grid(key), bounds_error=True)
        l = self.L[0] if l is None else l
        v = self.VGS if vgs is None else np.atleast_1d(vgs)
        pts = np.stack(np.broadcast_arrays(l, v, vds, vsb), axis=-1)
        out = self._interp[key](pts)
        return out if vgs is None or np.ndim(vgs) else float(out[0])

    def __call__(self, key: str, l=None, vgs=None, vds=0.9, vsb=0.0, gm_id=None, **ratio):
        """Murmann look_up: bias by vgs, or by a ratio such as gm_id=15 (monotonic part only)."""
        if gm_id is not None:
            ratio["GM_ID"] = gm_id
        if not ratio:
            return self.raw(key, l, vgs, vds, vsb)
        (rkey, rval), = ratio.items()
        x = self.raw(rkey, l, None, vds, vsb)
        y = self.raw(key, l, None, vds, vsb)
        if rkey.upper() == "GM_ID":     # use only the strong-inversion side of the gm/ID peak
            k = int(np.nanargmax(x))
            x, y = x[k:][::-1], y[k:][::-1]
        ok = np.isfinite(x) & np.isfinite(y)
        return np.interp(rval, x[ok], y[ok])
