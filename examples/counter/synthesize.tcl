# Genus Common UI template. Run from a fresh build directory, not source tree.
if {![info exists ::env(FORGE_REPO)] || ![info exists ::env(FORGE_PDK_CONFIG)]} {
  error "Set FORGE_REPO and FORGE_PDK_CONFIG to absolute paths first"
}
source $::env(FORGE_PDK_CONFIG)
if {![info exists liberty_slow] || [llength $liberty_slow] == 0} {
  error "Configure liberty_slow"
}
foreach lib $liberty_slow {
  if {![file readable $lib]} {error "Missing Liberty file: $lib"}
  read_libs $lib
}
read_hdl [file join $::env(FORGE_REPO) examples counter counter4.v]
elaborate counter4
read_sdc [file join $::env(FORGE_REPO) examples counter constraints.sdc]
syn_generic
syn_map
syn_opt
report_area > area.rpt
report_timing > timing.rpt
write_hdl > counter4_mapped.v
write_sdc > counter4_mapped.sdc
# Reports and mapping MUST be reviewed; reaching exit is not acceptance.
exit
