##################################################################
# Tcl script to create the APS2-Comms Vivado project for simulations
#
# Usage: at the Tcl console manually set the argv to set the PROJECT_DIR and PROJECT_NAME and
# then source this file. E.g.
#
# set argv [list "/home/cryan/Programming/FPGA" "APS2-Comms-sim"] or
# or  set argv [list "C:/Users/qlab/Documents/Xilinx Projects/" "APS2-Comms-sim"]
# source create_sim_project.tcl
#
# from Vivado batch mode use the -tclargs to pass argv
# vivado -mode batch -source create_sim_project.tcl -tclargs "/home/cryan/Programming/FPGA" "APS2-Comms-sim"
##################################################################

# parse arguments
set PROJECT_DIR [lindex $argv 0]
set PROJECT_NAME [lindex $argv 1]

# figure out the script path
set SCRIPT_PATH [file normalize [info script]]
set REPO_PATH [file dirname $SCRIPT_PATH]/../

create_project -force $PROJECT_NAME $PROJECT_DIR/$PROJECT_NAME -part xc7a200tfbg676-2
# Set project properties
set_property "part" "xc7a200tfbv676-2" [current_project]
set_property "default_lib" "xil_defaultlib" [current_project]
set_property "sim.ip.auto_export_scripts" "1" [current_project]
set_property "simulator_language" "Mixed" [current_project]
set_property "target_language" "VHDL" [current_project]

# load all HDL files
source $REPO_PATH/scripts/add_verilog_deps.tcl
source $REPO_PATH/scripts/add_comblocks_files.tcl
source $REPO_PATH/scripts/add_files_to_project.tcl

# Block designs
set bds [glob $REPO_PATH/test/bd/*.tcl]

foreach bd_path $bds {
  set bd [file rootname [file tail $bd_path]]
  puts "Working on $bd"
  source $REPO_PATH/test/bd/$bd.tcl -quiet
  regenerate_bd_layout
  validate_bd_design -quiet
  save_bd_design
  close_bd_design [get_bd_designs $bd]
  generate_target all [get_files $bd.bd] -quiet
  export_ip_user_files -of_objects [get_files $bd.bd] -no_script -force -quiet
}

# add testbenches
add_files -norecurse -fileset sim_1 $REPO_PATH/test
