# Repository validation

## Local checks (Git for Windows Bash, September 19, 2026)

- Bash syntax checks for every launcher, library, bootstrap, smoke-test, and mock-test script passed.
- Mock launcher integration passed: arguments containing spaces survived; the digital child had no course `OA_HOME`; private Motif preceded the course library path; the parent retained its own `OA_HOME`.
- The launcher rejected work outside the supplied home, a private-library path outside that home, and an unknown tool.

## Repository-checkout run on COE VLAB (September 21, 2026)

Run from a clone of <https://github.com/Forge-NU/Silicon-Design-FL26> in a COE
home directory, on host `rocky8-03`, Rocky Linux 8.10 x86_64. This is the fresh
VLAB checkout reproducibility check that was previously outstanding.

| Check | Result |
|---|---|
| `bash -n` on all shell scripts; `py_compile` on `setup-sky130.py` | Pass |
| `tests/launcher.sh` mock integration | Pass |
| SHA-256 of all three `vendor/sky130` archives against the pinned values | Match |
| `scripts/setup-sky130.py` full install (PDK + base 9T) and project generation | Pass, ~70 s |
| Re-run against the same project and PDK root (idempotence) | Pass, no files rewritten |
| `--with-mpw` into a separate project | Pass |
| Rejects a destination outside `$HOME`; rejects project equal to PDK root | Pass |
| `scripts/smoke.sh`: spectre, innovus, tempus, genus | Pass, licenses checked out |
| `scripts/smoke.sh`: xrun | Fail, exit 255 (see below); script returns 1 as designed |
| `examples/inverter/toy-inverter.scs` through `bin/forge-eda spectre` | Pass, 0 errors and 0 warnings, `V(out)` reaches 1.802 V |
| `examples/counter/synthesize.tcl` in Genus 21.10 against the generated manifest | Pass, exit 0 |

The Xcelium 22.03-s001 failure reproduces the recorded defect exactly: `xmsim`
raises `*F,INTERR` on stream `rts_xfer` at `0 FS` observed simulation time.
`XCELIUM2509` was re-checked and is still an empty directory. This remains a
vendor/IT problem, not a repository defect; `scripts/run-counter.sh` stays
blocked behind it.

Counter synthesis used the generated `.forge-sky130/env.sh` profile, so it
exercised the installer output and `synthesize.tcl` together. Genus mapped
`counter4` to 19 `sky130_scl_9T` cells (289.455 area units) against
`sky130_ss_1.62_125`, with four `DFFX1` sequential cells, no inferred latches,
no unresolved references and zero errors. The SDC reached the design: the
timing report shows the 10 ns clock edge and 0.1 ns uncertainty from
`examples/counter/constraints.sdc`, with setup met at 8084 ps.

`scripts/bootstrap-motif.sh` was not re-run because the private Motif library
was already installed and the script refuses to overwrite it;
`scripts/bootstrap-hspice.sh` was likewise not re-exercised.

See `readiness.md` for the earlier live vendor-tool evidence. Startup checks and
a single synthesis run do not constitute a vendor acceptance test or a complete
design flow; use `next-steps.md` as the acceptance gate.

Runtime files and license/account information are excluded from the distributable source tree. The source package contains only original setup/test code and reviewed documentation, not vendor software or PDK materials.
