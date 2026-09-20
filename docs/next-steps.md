# Next acceptance tests for the club

Detailed procedure: [design-validation.md](design-validation.md). Select the
process using [pdk-selection.md](pdk-selection.md); onboard through
[git-setup.md](git-setup.md).

| Gate | Required evidence |
|---|---|
| Startup | Smoke script exits zero; review each log |
| RTL | Counter PASS with 26 checks, time advances, no runtime crash |
| Analog schematic | Approved DC/transient/PVT results and saved test state |
| Analog physical | DRC clean, LVS matched, extraction complete, extracted metrics accepted |
| Digital synthesis | Resolved mapped cells, correct constraints, no unintended latches |
| Equivalence | All intended points equivalent; no unexplained black boxes/exclusions |
| Digital physical | Power/connectivity verified, routing complete, approved DRC/LVS results |
| Timing | Matching extracted parasitics, complete coverage, setup/hold and electrical limits met |
| AMS | Correct bindings/interfaces, both engines advance time, analog and digital checks pass |
| Sponsor | Reviews evidence, allowed use and remaining limitations |

The startup tests and newly supplied examples do not establish tapeout readiness.

1. Have COE IT restore a supported Xcelium installation and reproduce the small RTL failure. Then run `examples/rtl.sv` and require its PASS marker after time has advanced.
2. Select one teaching PDK with a consistent digital library set. Record exact revisions and corner choices without committing proprietary files.
3. Synthesize a small counter, compare RTL against the mapped netlist, place and route it, extract parasitics, and run timing with explicit constraints. Retain reports of unresolved cells, DRCs, timing violations, and tool versions.
4. Build an analog inverter or comparator with the chosen PDK, run schematic simulation, layout, DRC, LVS, and extracted simulation. A tool startup check alone is insufficient.
5. Run a mixed analog/digital testbench using Spectre AMS/Xcelium, including connect rules and both analog and digital outputs. Verify the required AMS features actually check out.
6. Ask the faculty sponsor/COE IT to confirm student-club use and any PDK/foundry restrictions, plus current license expirations and supported compute hosts.
7. Keep a minimal known-good reference project and rerun these tests after image or tool upgrades. Record host and date in private logs.

Use separate analog and digital launch processes. Do not globally set an old OpenAccess library for every Cadence release. Do not delete another host's log locks without first checking whether the owning session is active.
