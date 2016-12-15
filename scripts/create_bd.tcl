# helper script to create the APS2-Comms block diagram

set APS2_COMMS_SCRIPT_PATH [file normalize [info script]]
set APS2_COMMS_REPO_PATH [file dirname $APS2_COMMS_SCRIPT_PATH]/../

puts "Working on APS2 comms block diagram"
source $APS2_COMMS_REPO_PATH/src/bd/aps2_comms_bd.tcl -quiet
regenerate_bd_layout
#optionally fix IP address
if { [info exists FIXED_IP] && !($FIXED_IP eq "") } {
	set_property -dict [list CONFIG.FIXED_IP {true}] [get_bd_cells com5402_wrapper_0]
}
validate_bd_design -quiet
save_bd_design
close_bd_design [get_bd_designs aps2_comms_bd]
generate_target all [get_files aps2_comms_bd.bd] -quiet
export_ip_user_files -of_objects [get_files aps2_comms_bd.bd] -no_script -force -quiet
