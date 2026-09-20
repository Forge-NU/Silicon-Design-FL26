# EDA readiness — September 18–19, 2026

## Conclusion

COE VLAB is usable for initial analog design exploration, with functioning Spectre and a recovered legacy HSPICE installation. The user-local repairs also let Innovus and Tempus check out licenses and execute Tcl. Do not yet describe the environment as a validated full digital or mixed-signal flow: Xcelium crashes, Design Compiler is incomplete, and no integrated PDK-based reference design has traversed the complete flow.

## Direct observations in this session

| Component | Evidence | Interpretation |
|---|---|---|
| Innovus 21.19 s058_1 | Missing `libXm.so.4` resolved; license checkout succeeded. Then an OpenAccess version/symbol error was resolved by unsetting `OA_HOME`. Tcl marker printed; zero reported errors; normal ending. | Startup and license path work after private repair. No place-and-route design was run. |
| Tempus, SSV251 installation | Same Motif repair and no course `OA_HOME` override. Exit code 0, Tcl marker, zero warnings and errors. | Startup and license path work. No real timing graph or signoff run tested. |
| Spectre, SPECTRE231 installation | RC transient completed with zero errors and zero warnings; license usage reported. | Real analog simulation works. Does not validate a PDK or ADE integration. |
| Virtuoso IC618 normal VMware display | Dedicated log in the work directory, SKILL restore script, Virtuoso Framework (111) checkout succeeded, `FORGE_VIRTUOSO_PASS`, exit 0. | GUI-mode startup, licensing, and SKILL execution verified September 19. Does not validate schematic/layout editing or a PDK. |
| Virtuoso IC618 headless test | `-nograph -restore` timed out (124), with stale home-log lock warnings and failure to open its internal Xvnc display. | Headless invocation remains broken/unverified. Normal VMware-display startup passed separately. |
| HSPICE C-2009.09 SP1, 32-bit | Missing `libnsl.so.1` and `libnspr4.so` resolved privately. Exit 0; listing shows HSPICE license checkout, 2,001 transient points, and token release. | Legacy Synopsys circuit simulation works. Current PrimeSim capability not established. |
| Xcelium 22.03-s001, 64-bit | Fresh work directory and no inherited `LD_LIBRARY_PATH`; compile/elaboration completes, then `xmsim *F,INTERR: INTERNAL EXCEPTION`, simulation time 0 FS, stream `rts_xfer`; exit 255. | RTL runtime remains broken on the tested desktop. AMS remains unverified. |
| XCELIUM2509 directory | Directory exists but is empty. | Not an installed alternative simulator. |
| Synopsys Design Compiler | Required `compiler/linux/syn/bin/common_shell_exec` does not exist. | Cannot repair the missing vendor installation with an environment variable. |
| Synopsys license status | SSV251 `lmutil` query returned “Invalid returned data from license server system. (-12,16)”. | Total seats unknown. This does not negate successful HSPICE checkout. |

The first phase ran on one Rocky 8.10 desktop; HSPICE was resumed successfully on another VLAB desktop using the same home directory. Do not assume all VLAB hosts have identical runtime libraries.

## Earlier audit evidence (not all independently repeated)

The saved September 16 report records successful small jobs for Spectre/APS/Spectre X, Genus, Conformal, PVS, and Calibre. The supplied earlier conversation also reports Virtuoso startup with the course setup and Quantus availability. Reported license totals include roughly 80 seats for many Cadence tools, 480 for selected Spectre features, 85 Calibre, and 170 Questa. These are historical reports, not newly measured availability or reservations.

The prior inventory names generic Cadence PDKs and teaching standard-cell libraries. Their mere presence does not validate a matched set of Liberty, LEF, technology LEF, GDS/OASIS, SPICE/CDL, extraction corners, DRC, and LVS decks. No process files are redistributed here.

## Changes made in the original COE account

All deliberate repair writes were under `~/forge_repair_20260918`, including:

- `motif/`: extracted official `motif-2.3.4-24.el8_10.x86_64.rpm`.
- `hspice32/`: extracted `libnsl-2.28-251.el8_10.27.i686.rpm` and `nspr-4.36.0-2.el8_10.i686.rpm`.
- `digital-env.sh`: optional setup file loading the course script, removing `OA_HOME`, and adding private Motif and the Innovus/Tempus launch paths.
- Test directories, simulation outputs, and logs. Existing September 16 audit files were read, not rewritten.

No system packages were installed and no shared course scripts or vendor files were edited. No automatic login configuration was changed. Early in the session, VMware pasted stale conversation text into the shell; it was interrupted, but the quoted Virtuoso launch executed and produced user-home log/lock warnings. No shared-file modification was observed. Subsequent commands used direct keystrokes with visual verification.

## Evidence retained on COE

Paths relative to `~/forge_repair_20260918`:

- `innovus.log`: initial OpenAccess failure after Motif repair.
- `innovus-clean.log`: successful startup after removing `OA_HOME`.
- `tempus.log`: successful startup and exit code observed as 0.
- `spectre.log`, `rc.raw/`: actual analog simulation.
- `xcelium2203/test.log` and associated crash report: clean-directory reproduction.
- `hspice.log`, `hspice-test.lis`, `hspice-test.st0`: successful legacy HSPICE run.
- `synopsys-seats.txt`: license-status error only; no seat inventory obtained.
- `virtuoso-check/test.log`: headless startup timeout and Xvnc display warnings.
- `virtuoso-check/gui-test.log` and `virtuoso-check/virtuoso.log`: successful live-display test, license checkout, and SKILL marker.

Raw logs are intentionally excluded from the Git repository. A previous Innovus retry printed an exit status after `stty sane`, so that displayed status is not reliable evidence of the tool's exit code; the Tcl marker, normal ending, and zero-error summary provide the evidence instead. Tempus and HSPICE exit codes were captured directly.

## Package sources

Packages came over HTTPS from Rocky Linux's official repositories and passed `rpm -K` with “digests signatures OK” before use:

- [Motif package listing](https://dl.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/Packages/m/)
- [libnsl package listing](https://dl.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os/Packages/l/)
- [NSPR package listing](https://dl.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/Packages/n/)

The original two course PDFs were named in the pasted conversation but were not attached as readable files in this session. The live course setup script and saved audit logs were inspected instead.
