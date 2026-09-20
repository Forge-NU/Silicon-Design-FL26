# Draft request to COE IT (not sent)

Forge Silicon is validating a teaching mixed-signal IC flow on Rocky Linux 8 VLAB. We have working user-local mitigations for two runtime dependencies, but need help with the shared installations and supported configuration.

- Innovus 21.19 and Tempus from SSV251 originally failed on missing `libXm.so.4`. Extracting the signed Rocky 8 Motif package in the user's home resolved this. Could Motif be included in the standard image?
- The EECE7353 course setup exports an IC618 OpenAccess directory. That conflicts with Innovus 21.19 (`IMPOAX-124` and an undefined OpenAccess symbol). Unsetting `OA_HOME` only for the digital tool process resolves startup. Could course setup documentation distinguish tool-specific environments?
- Xcelium 22.03-s001 compiles/elaborates a trivial Verilog test but crashes in xmsim at 0 FS (`*F,INTERR`, stream `rts_xfer`, exit 255). It reproduces with a fresh work directory and inherited `LD_LIBRARY_PATH` removed. `XCELIUM2509` is present as an empty directory. Please provide a supported patched installation and validate a time-advancing RTL test and AMS integration.
- Design Compiler's `compiler/linux/syn/bin/common_shell_exec` is missing. Please identify a complete supported installation and whether VCS, PrimeTime, and current PrimeSim are available on another approved host.
- Legacy HSPICE 2009.09 SP1 works after private 32-bit libnsl and NSPR dependencies are provided; this is not a current Synopsys flow.
- A newer Cadence lmutil still returns Synopsys status error `(-12,16)`, despite successful HSPICE checkout. Please confirm current feature totals and expirations using your supported licensing tools.
- A fresh IC618 `-nograph -restore` check timed out with stale home-log lock warnings and failure to open the internal Xvnc display. A normal VMware-display invocation with a dedicated log passed, including Framework license checkout and SKILL execution. Please identify the supported headless invocation/runtime dependencies.
- Please confirm appropriate club use and the supported teaching PDK/library combination for a complete analog/digital flow.

Logs remain in the original user's repair directory and can be supplied through the appropriate university support channel after review. No shared files were edited.
