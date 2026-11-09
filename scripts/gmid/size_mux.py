"""Size the 2:1 temperature-sensor mux transmission gates from the gm/ID LUTs.

Method (switch version of Murmann's LUT flow): at VDS ~ 0 a switch is a
conductance, and everything that matters scales with W:
    g_on/W(Vin)   from GDS_W   (NMOS: VGS = VDD-Vin, VSB = Vin;  PMOS: VSG = Vin)
    C_node/W      from (CDD + CJD)_W   (on and off switch both load the output)
    C_gate/W      from CGG_W           (select-driver load, charge injection)
    I_off/W       from ID_W at VGS = 0, VDS = worst case
1. For each L, pick Wp/Wn that minimises the worst-case Ron over the input range
   (per unit total width).  g_on/C_node is width-independent, so it ranks the Ls.
2. With that ratio, find the smallest Wn so the RC settles to the accuracy spec:
   tau = (R_src + Ron_max) * (C_load + C_par(W)),  t_settle >= ln(2^(N+1)) * tau.
3. Check off-leakage and charge-injection error against the LSB, then verify the
   chosen sizes with a real Spectre Ron(Vin) sweep (--verify).

Edit SPEC to match the system; the defaults are placeholders.
"""

from __future__ import annotations

import argparse
import math

import numpy as np

from lookup import Lut

SPEC = dict(
    vdd=1.8,
    vin_min=0.1, vin_max=1.7,     # V, span both sensors' outputs must pass
    r_src=5e3,                    # ohm, worst source impedance (thermistor divider / PNP node)
    c_load=2e-12,                 # F, what the mux drives (S/H or ADC sampling cap)
    t_settle=1e-6,                # s, time allowed after a select change
    n_bits=12,                    # settle to 1/2 LSB of this resolution
    nmos="nfet_01v8", pmos="pfet_01v8",
    n_switches=2,                 # TGs hanging on the output node (2:1 mux)
    pmos_switched_well=False,     # True: PMOS n-well tied to its source when on (VSB = 0)
)
LS = [0.15e-6, 0.18e-6, 0.25e-6, 0.35e-6, 0.5e-6]
VDS_ON = 0.0


def per_width(n: Lut, p: Lut, l: float, vin: np.ndarray, s: dict):
    """On-conductance [S/m] of NMOS and PMOS vs Vin, plus node/gate cap and leakage per metre."""
    vdd = s["vdd"]
    gn = np.array([n.raw("GDS_W", l, vdd - v, VDS_ON, v) if vdd - v > 0 else 0.0 for v in vin])
    psb = 0.0 if s["pmos_switched_well"] else None
    gp = np.array([p.raw("GDS_W", l, v, VDS_ON, psb if psb is not None else vdd - v) for v in vin])
    cnode_n = n.raw("CDD_W", l, 0.0, VDS_ON, 0.0) + n.raw("CJD_W", l, 0.0, VDS_ON, 0.0)
    cnode_p = p.raw("CDD_W", l, 0.0, VDS_ON, 0.0) + p.raw("CJD_W", l, 0.0, VDS_ON, 0.0)
    cgg_n, cgg_p = n.raw("CGG_W", l, vdd, VDS_ON, 0.0), p.raw("CGG_W", l, vdd, VDS_ON, 0.0)
    ioff_n = n.raw("ID_W", l, 0.0, vdd, 0.0)
    ioff_p = p.raw("ID_W", l, 0.0, vdd, 0.0)
    return gn, gp, cnode_n, cnode_p, cgg_n, cgg_p, ioff_n, ioff_p


def best_ratio(gn, gp):
    """Wp/Wn minimising max Ron * (Wn + Wp) over the input range."""
    rs = np.linspace(0.5, 6, 221)
    cost = [(1 + r) / np.min(gn + r * gp) for r in rs]
    return float(rs[int(np.argmin(cost))])


def size(s: dict, verbose=True):
    n, p = Lut(s["nmos"]), Lut(s["pmos"])
    vin = np.linspace(s["vin_min"], s["vin_max"], 33)
    k_settle = math.log(2 ** (s["n_bits"] + 1))
    tau_max = s["t_settle"] / k_settle
    lsb = s["vdd"] / 2 ** s["n_bits"]
    if verbose:
        print(f"tau budget {tau_max * 1e9:.1f} ns (= t_settle / ln 2^{s['n_bits'] + 1}),"
              f" R_src*C_load alone = {s['r_src'] * s['c_load'] * 1e9:.1f} ns, LSB = {lsb * 1e6:.0f} uV")
        print(f"{'L':>6} {'Wp/Wn':>6} {'Wn':>7} {'Wp':>7} {'Ron_max':>8} {'Ron_min':>8} "
              f"{'C_par':>7} {'tau':>7} {'g/C FOM':>9} {'I_off':>8} {'Q_inj err':>9}")
    rows = []
    for l in LS:
        gn, gp, cdn, cdp, cgn, cgp, ion, iop = per_width(n, p, l, vin, s)
        r = best_ratio(gn, gp)
        g_min_per_wn = np.min(gn + r * gp)                       # S per metre of Wn
        c_per_wn = s["n_switches"] * (cdn + r * cdp)             # F per metre of Wn
        fom = g_min_per_wn / c_per_wn                            # rad/s, independent of W
        # tau(Wn) = (R_src + 1/(g Wn)) (C_load + c Wn); smallest Wn with tau <= tau_max
        a = s["r_src"] * c_per_wn
        b = s["r_src"] * s["c_load"] + c_per_wn / g_min_per_wn - tau_max
        c = s["c_load"] / g_min_per_wn
        disc = b * b - 4 * a * c
        if disc < 0 or b > 0:
            rows.append(dict(l=l, ok=False, fom=fom))
            if verbose:
                print(f"{l * 1e6:6.2f}  cannot meet tau with R_src={s['r_src']:.3g} ohm"
                      f" (FOM {fom / 2 / math.pi / 1e9:.2f} GHz)")
            continue
        wn = (-b - math.sqrt(disc)) / (2 * a)
        wn = max(wn, 0.42e-6)
        wn = math.ceil(wn / 0.05e-6) * 0.05e-6 * 1.2             # grid + 20% corner margin
        wp = math.ceil(r * wn / 0.05e-6) * 0.05e-6
        ron = 1 / (gn * wn + gp * wp)
        cpar = s["n_switches"] * (cdn * wn + cdp * wp)
        tau = (s["r_src"] + ron.max()) * (s["c_load"] + cpar)
        i_off = (s["n_switches"] - 1) * (ion * wn + iop * wp)
        # gate charge dumped on the line at turn-off (half of channel charge, NMOS/PMOS
        # partly cancel); a pessimistic bound with no cancellation:
        q_inj = 0.5 * (cgn * wn + cgp * wp) * s["vdd"] * 0.5
        err_inj = q_inj / (s["c_load"] + cpar)
        rows.append(dict(l=l, ok=True, r=r, wn=wn, wp=wp, ron=ron, cpar=cpar, tau=tau,
                         fom=fom, i_off=i_off, err_inj=err_inj, vin=vin))
        if verbose:
            print(f"{l * 1e6:6.2f} {r:6.2f} {wn * 1e6:6.2f}u {wp * 1e6:6.2f}u {ron.max():7.0f}R"
                  f" {ron.min():7.0f}R {cpar * 1e15:6.1f}f {tau * 1e9:6.1f}n"
                  f" {fom / 2 / math.pi / 1e9:7.2f}GHz {i_off * 1e12:7.2f}p {err_inj / lsb:8.1f}LSB")
    return rows, n, p


def verify(s: dict, l: float, wn: float, wp: float, corner: str = "tt"):
    """Spectre Ron(Vin) of the sized TG, compared against the LUT prediction."""
    import re
    import subprocess
    import tempfile
    from pathlib import Path
    from make_lut import ENV, MODELS
    ad = lambda w: f"as={w * 0.29e-6:.4g} ad={w * 0.29e-6:.4g} ps={2 * (w + 0.29e-6):.4g} pd={2 * (w + 0.29e-6):.4g}"
    tb = f"""simulator lang=spectre
global 0
include "{MODELS}" section={corner}
parameters vin=0.9
MN (a g b 0) {s['nmos']} w={wn:.4g} l={l:.4g} {ad(wn)} m=1
MP (a gb b nw) {s['pmos']} w={wp:.4g} l={l:.4g} {ad(wp)} m=1
VNW (nw 0) vsource dc={'vin' if s['pmos_switched_well'] else s['vdd']}
VG (g 0) vsource dc={s['vdd']}
VGB (gb 0) vsource dc=0
VA (a 0) vsource dc=vin
VB (b 0) vsource dc=vin-1m
sw dc param=vin start={s['vin_min']} stop={s['vin_max']} step=0.05
save VB:p
"""
    with tempfile.TemporaryDirectory(dir="/tmp") as d:
        (Path(d) / "tb.scs").write_text(tb)
        subprocess.run(["bash", "-c", f"{ENV} >/dev/null 2>&1; cd {d} && spectre -64 tb.scs "
                        "-format psfascii -raw out =log tb.log"], capture_output=True)
        txt = (Path(d) / "out" / "sw.dc").read_text().split("VALUE", 1)[1]
    v = np.array([float(x) for x in re.findall(r'"vin"\s+([-+0-9.eE]+)', txt)])
    i = np.array([float(x) for x in re.findall(r'"VB:p"\s+([-+0-9.eE]+)', txt)])
    return v, 1e-3 / np.abs(i)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true", help="Spectre check of the chosen L")
    ap.add_argument("--l", type=float, default=None, help="L in um to report/verify")
    ap.add_argument("--corner", default="tt", help="model corner for --verify (LUTs are tt)")
    for k, v in SPEC.items():
        if isinstance(v, bool):
            ap.add_argument(f"--{k}", type=lambda x: x.lower() in ("1", "true", "yes"), default=v)
        else:
            ap.add_argument(f"--{k}", type=type(v), default=v)
    a = vars(ap.parse_args())
    s = {k: a[k] for k in SPEC}
    rows, n, p = size(s)
    ok = [r for r in rows if r["ok"]]
    if not ok:
        raise SystemExit("no L meets the settling spec: lower R_src/C_load or allow more time")
    pick = min(ok, key=lambda r: abs(r["l"] - a["l"] * 1e-6)) if a["l"] else \
        min(ok, key=lambda r: (r["wn"] + r["wp"]) * r["l"])  # smallest gate area that works
    print(f"\npick L={pick['l'] * 1e6:.2f}u  Wn={pick['wn'] * 1e6:.2f}u  Wp={pick['wp'] * 1e6:.2f}u")
    if a["verify"]:
        v, ron_sim = verify(s, pick["l"], pick["wn"], pick["wp"], a["corner"])
        ron_lut = np.interp(v, pick["vin"], pick["ron"])
        print(f"{'Vin':>5} {'Ron LUT':>9} {'Ron Spectre':>12} {'err':>6}")
        for vi, rl, rs in list(zip(v, ron_lut, ron_sim))[::4]:
            print(f"{vi:5.2f} {rl:8.0f}R {rs:11.0f}R {100 * (rl / rs - 1):5.1f}%")
        print(f"max Ron: LUT {ron_lut.max():.0f}R, Spectre {ron_sim.max():.0f}R")
