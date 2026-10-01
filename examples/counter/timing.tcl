# Tempus check of the routed counter at the slow library with Innovus's SPEF.
# Run in the build directory after place_route.tcl.
if {![info exists ::env(FORGE_PDK_CONFIG)]} {error "Set FORGE_PDK_CONFIG first"}
source $::env(FORGE_PDK_CONFIG)
read_lib $liberty_slow
read_verilog counter4_routed.v
set_top_module counter4
read_sdc counter4_mapped.sdc
read_spef counter4.spef
set_analysis_mode -analysisType onChipVariation -cppr both
update_timing -full
report_timing -max_paths 5 > tempus_setup.rpt
report_timing -early -max_paths 5 > tempus_hold.rpt
report_analysis_summary > tempus_summary.rpt
exit
