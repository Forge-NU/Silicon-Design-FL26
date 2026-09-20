# Manual handoff

## 1. Use the repaired digital tools now

In a new Rocky Linux terminal in the original COE account:

```bash
mkdir -p ~/forge-designs/digital
cd ~/forge-designs/digital
source ~/forge_repair_20260918/digital-env.sh
innovus
# Or, after exiting Innovus:
tempus
```

Keep this terminal for digital work. Use a separate terminal for Virtuoso.

## 2. Start Virtuoso

```bash
mkdir -p ~/forge-designs/analog
cd ~/forge-designs/analog
source /ECEnet/Apps1/linux/EECE7353/cadence24.sh
export PDKS=/ECEnet/Apps1/linux/cad2024/tools/PDKs
/ECEnet/Apps1/linux/cad2024/tools/IC618/tools/dfII/bin/virtuoso \
  -log "$PWD/virtuoso-$(date +%Y%m%d-%H%M%S).log" &
```

Use the regular VMware display. Do not use `-nograph` for now. The dedicated log avoids old home-directory log locks without deleting them.

## 3. Share the Git repository

Copy `forge-silicon-eda.bundle` to the team or your COE home and run:

```bash
git clone forge-silicon-eda.bundle forge-silicon-eda
```

Or use the supplied source ZIP. To publish on GitHub manually:

1. Create an empty repository in the desired account/organization. Choose visibility deliberately; private is a reasonable starting point. Do not initialize it with another README.
2. From the local `forge-silicon-eda` Git repository:

```bash
git remote add origin https://github.com/YOUR-OWNER/forge-silicon-eda.git
git push -u origin main
```

3. Invite the team through GitHub's repository access settings. Keep PDKs, proprietary libraries, raw logs, and license files out of Git.

Each team member should follow README.md to create their own private Motif libraries. The repair directory in the original account is not a shared installation.

## 4. Send the prepared IT request

Review `docs/coe-it-request.md` and submit it through COE's normal support channel. Highest priorities:

- Repair/update Xcelium: 22.03 crashes at simulation time zero; the 25.09 directory is empty.
- Identify a complete supported Synopsys installation: Design Compiler's required executable is missing.
- Confirm club license use, supported hosts, and the recommended PDK/library combination.

Motif in the standard image and a supported Virtuoso headless setup are useful follow-ups. Your private workaround already enables Innovus/Tempus startup.

## 5. Validate one small design with your faculty sponsor

Choose one teaching PDK. Run one analog inverter through schematic simulation, layout, DRC, LVS, extraction, and extracted simulation. Run one small digital counter through simulation, synthesis, equivalence, place-and-route, extraction, and timing. Only then attempt AMS co-simulation. Use `docs/next-steps.md` as acceptance criteria.

The repository's startup tests are intentionally small; they do not establish tapeout readiness. After IT repairs Xcelium, rerun `bash scripts/smoke.sh` from a checkout in your COE home. Inspect the summary and logs; a failing test makes the script return a nonzero status.

## Already completed

- Private Motif extraction and successful Innovus/Tempus startup/license/Tcl checks.
- Successful Spectre RC transient simulation.
- Successful Virtuoso normal-display startup, license checkout, and SKILL test with a dedicated log.
- Private 32-bit HSPICE dependencies and successful legacy HSPICE transient simulation.
- Reproduction of the Xcelium crash and identification of missing Design Compiler files.
- Local Git repository, reviewed documentation, reusable scripts, mock/syntax checks, and shareable bundle/ZIP.

The full repository workflow has not yet been executed as a fresh VLAB checkout. That is the next inexpensive manual reproducibility check. No GitHub remote has been created.
