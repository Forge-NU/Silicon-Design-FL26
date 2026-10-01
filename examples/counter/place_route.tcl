# Innovus (legacy UI) teaching flow. Run in the synthesis build directory, which
# holds counter4_mapped.v and counter4_mapped.sdc. Not a qualified signoff flow.
if {![info exists ::env(FORGE_REPO)] || ![info exists ::env(FORGE_PDK_CONFIG)]} {
  error "Set FORGE_REPO and FORGE_PDK_CONFIG to absolute paths first"
}
source $::env(FORGE_PDK_CONFIG)
foreach var {cts_buffer_cells cts_inverter_cells filler_cells} {
  if {![info exists $var]} {error "$var missing from $::env(FORGE_PDK_CONFIG); rerun setup-sky130.py in a new project or add it"}
}
set init_lef_file [concat [list $tech_lef] $cell_lefs]
set init_verilog counter4_mapped.v
set init_top_cell counter4
set init_mmmc_file [file join $::env(FORGE_REPO) examples counter mmmc.tcl]
set init_pwr_net $power_net
set init_gnd_net $ground_net
init_design

# A tiny core still needs room for its power ring.
floorPlan -site $placement_site -r 1.0 0.5 8 8 8 8
globalNetConnect $power_net -type pgpin -pin $power_net -all
globalNetConnect $ground_net -type pgpin -pin $ground_net -all
addRing -nets [list $power_net $ground_net] -type core_rings \
  -layer {top met1 bottom met1 left met2 right met2} -width 1.0 -spacing 0.5 -offset 1.0
sroute -nets [list $power_net $ground_net] -connect corePin
setPinAssignMode -pinEditInBatch true
editPin -pin {clk rst_n en} -side Left -layer met3 -spreadType center -spacing 4
editPin -pin {count[0] count[1] count[2] count[3]} -side Right -layer met3 -spreadType center -spacing 4
place_opt_design
saveDesign counter4_place.enc

# CCOpt does not infer the kit's clock cells.
set_ccopt_property buffer_cells $cts_buffer_cells
set_ccopt_property inverter_cells $cts_inverter_cells
create_ccopt_clock_tree_spec
ccopt_design
saveDesign counter4_cts.enc

routeDesign
addFiller -cell $filler_cells -prefix FILL
saveDesign counter4_route.enc

verify_connectivity -report connectivity.rpt
verifyGeometry -report geometry.rpt
# Post-route timing refuses to run in the default single analysis (IMPOPT-7027).
setAnalysisMode -analysisType onChipVariation -cppr both
timeDesign -postRoute -outDir timing_postroute
timeDesign -postRoute -hold -outDir timing_postroute
saveNetlist counter4_routed.v
rcOut -spef counter4.spef -rc_corner rc
write_sdf counter4.sdf
defOut -routing counter4.def
# Review connectivity.rpt, geometry.rpt and timing_postroute; exit is not acceptance.
exit
