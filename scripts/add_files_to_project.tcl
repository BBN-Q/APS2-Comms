# helper script to add necessary files to current project

set APS2_COMMS_SCRIPT_PATH [file normalize [info script]]
set APS2_COMMS_REPO_PATH [file dirname $APS2_COMMS_SCRIPT_PATH]/../

# add our IP to IP search path
set repo_paths [get_property ip_repo_paths [current_fileset]]
if { [lsearch -exact -nocase $repo_paths $APS2_COMMS_REPO_PATH/src/ip ] == -1 } {
	set_property ip_repo_paths "$APS2_COMMS_REPO_PATH/src/ip [get_property ip_repo_paths [current_fileset]]" [current_fileset]
	update_ip_catalog -rebuild
}

# BBN source files
add_files -norecurse $APS2_COMMS_REPO_PATH/src

# dependecies
set synchronizer_file [get_files -quiet *Synchronizer.vhd]
if {$synchronizer_file == ""} {
	add_files -norecurse $APS2_COMMS_REPO_PATH/deps/VHDL-Components/src/Synchronizer.vhd
}

# constraints (have to add tcl files separately)
add_files -fileset constrs_1 -norecurse $APS2_COMMS_REPO_PATH/constraints
add_files -fileset constrs_1 -norecurse $APS2_COMMS_REPO_PATH/constraints/async_fifos.tcl
