# Shared Virtuoso libraries

Libraries under `analog/libs/` are tracked in Git and appear in every
member's Library Manager. Libraries in your project directory
(`~/forge-projects/...`) stay private scratch space, as before.

Each project's `cds.lib` includes `analog/cds.lib`, which lists the shared
libraries with paths relative to itself, so the same file works in every
checkout.

## Connect an existing project

Projects created before `analog/` existed do not load the shared libraries,
so pulled libraries are on disk but missing from Virtuoso. Run this once
after pulling; it updates every project in `~/forge-projects`:

```bash
cd ~/Silicon-Design-FL26
git pull --ff-only
bash scripts/connect-analog-libs.sh
```

Pass a project folder to connect only that one, or `--dry-run` to preview.
Each changed `cds.lib` is kept as `cds.lib.bak-<timestamp>`. Then restart
Virtuoso, or run `ddUpdateLibList()` in the CIW. The launcher prints a
reminder when a project is not connected yet.

## Move a library into the repository

Close the library's cellviews in Virtuoso, then give the script the
library's folder:

```bash
cd ~/Silicon-Design-FL26
git switch main && git pull --ff-only
bash scripts/share-analog-lib.sh ~/forge-projects/sky130-9t/adc_comparator
```

It moves the folder to `analog/libs/`, adds
`DEFINE adc_comparator libs/adc_comparator` to `analog/cds.lib`, and in the
project's `cds.lib` removes the old `DEFINE` line for it and adds the
`SOFTINCLUDE` if missing (keeping a `cds.lib.bak-*` copy). It stops if the
library is open, if the name is already shared, or if the folder is not a
Virtuoso library. Add `--dry-run` to see the changes without making them.
It does not commit; it prints the Git commands to run next.

## Create a new shared library

In Library Manager, choose File > New > Library, set the directory to
`~/Silicon-Design-FL26/analog/libs` and attach the technology library
`sky130_fd_pr_main`. Virtuoso adds an absolute `DEFINE` line to the project
`cds.lib`. Move that line to `analog/cds.lib` in the relative form
(`DEFINE NewLib libs/NewLib`) and run `scripts/check-analog-libs.sh`.
Simpler: create the library in your project as usual and share it with
`scripts/share-analog-lib.sh`.

## Working together

- OpenAccess files are binary and Git cannot merge them. If two people edit
  the same cellview, one person's work is lost. Give each block its own
  library with one owner, and agree before editing another owner's cell.
- Library names must be unique across the team. Prefix them by block, such
  as `adc_comparator`, not `test` or `MyLib`.
- Pull before opening Virtuoso. After a pull that changes an open cellview,
  close and reopen it.
- Commit schematics, symbols, layouts and `maestro` setups. Edit locks,
  `maestro/results` and `maestro/history` are ignored. Spectre runs go to
  `~/simulation` and stay out of the repository.
- PDK and standard-cell libraries are never copied here; every member
  installs them with `scripts/setup-sky130.py`.
