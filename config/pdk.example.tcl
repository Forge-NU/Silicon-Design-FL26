# Copy to config/pdk.local.tcl. This ignored file contains site-specific paths.
# Supply a faculty-approved MATCHED library set. Do not copy proprietary files.
set pdk_id REPLACE_PROCESS_AND_REVISION
set liberty_slow [list /REPLACE/slow.lib]
set liberty_fast [list /REPLACE/fast.lib]
set tech_lef /REPLACE/technology.lef
set cell_lefs [list /REPLACE/cells.lef]
set cell_verilog [list /REPLACE/functional_cells.v]
set qrc_slow /REPLACE/approved_setup_rc_technology
set qrc_fast /REPLACE/approved_hold_rc_technology
set placement_site REPLACE_SITE
set power_net REPLACE_POWER_NET
set ground_net REPLACE_GROUND_NET
# Record PVT, metal stack, RC corners, model sections and tool compatibility
# in your private project record. Slow/fast labels alone do not define corners.
