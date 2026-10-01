# Innovus MMMC views for the counter: setup at the slow library, hold at the fast.
source $::env(FORGE_PDK_CONFIG)
if {[info exists qrc_typical]} {set qrc_tech $qrc_typical} else {set qrc_tech $qrc_slow}
create_library_set -name slow -timing $liberty_slow
create_library_set -name fast -timing $liberty_fast
create_rc_corner -name rc -qx_tech_file $qrc_tech
create_delay_corner -name dc_slow -library_set slow -rc_corner rc
create_delay_corner -name dc_fast -library_set fast -rc_corner rc
create_constraint_mode -name func -sdc_files [list counter4_mapped.sdc]
create_analysis_view -name setup_slow -constraint_mode func -delay_corner dc_slow
create_analysis_view -name hold_fast -constraint_mode func -delay_corner dc_fast
set_analysis_view -setup setup_slow -hold hold_fast
