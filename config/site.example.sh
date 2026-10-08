# Optional: copy to config/local.sh (ignored by Git). Bash syntax.
# Defaults target Northeastern COE. Do not add passwords or license files.
# FORGE_CADENCE_ROOT=/ECEnet/Apps1/linux/Cadence
# Older tree for the PDKs and Tempus (SSV251):
# FORGE_CADENCE_LEGACY_ROOT=/ECEnet/Apps1/linux/cad2024/tools
# FORGE_PDK_ROOT=/ECEnet/Apps1/linux/cad2024/tools/PDKs
# Virtuoso release; IC261 needs 26.x license features the campus server lacks:
# FORGE_VIRTUOSO_RELEASE=IC251
# FORGE_CADENCE_LICENSE=5280@cadencelm.coe.neu.edu
# Optional extra setup script, sourced before the tool environment:
# FORGE_COURSE_SETUP=/path/to/setup.sh
# FORGE_EDA_STATE="$HOME/.local/share/forge-silicon"
# Set this to reuse the repair made on September 18:
# FORGE_MOTIF_ROOT="$HOME/forge_repair_20260918/motif"
# FORGE_HSPICE_ROOT="$HOME/forge_repair_20260918/hspice32"
# FORGE_SYNOPSYS_LICENSE=port@authorized-server
# Virtuoso GUI scale (default 1.5; empty keeps normal size):
# FORGE_VIRTUOSO_SCALE=1.25
# Keep edit locks from other hosts when running Virtuoso on two VLAB hosts at once:
# FORGE_KEEP_REMOTE_LOCKS=1
